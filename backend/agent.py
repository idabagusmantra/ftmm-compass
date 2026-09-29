import os
import json
import re
import httpx
from typing import Tuple, List, Optional
from schemas import (
    StudentProfile,
    ChatRequest,
    ChatResponse,
    DegreePlanPayload,
)
from data_loader import normalize_prodi
from tools.planner import generate_study_plan


OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
DEFAULT_MODEL = os.getenv("LLM_MODEL", "qwen2.5:3b-instruct")


SYSTEM_PROMPT = """Anda adalah Compass AI, asisten akademik pintar untuk Fakultas Teknologi Maju dan Multidisiplin (FTMM), Universitas Airlangga.
Tugas utama Anda adalah membantu mahasiswa menyusun rencana studi (study planner) secara personal, akurat, dan ramah.

ATURAN UTAMA (ANTI-ASUMSI & STRICT CLARIFICATION):
1. DILARANG membuat asumsi tentang Program Studi, Semester saat ini, atau mata kuliah yang sudah lulus jika mahasiswa belum menyatakannya.
2. Jika informasi mahasiswa belum lengkap, Anda WAJIB menanyakan informasi yang kurang secara sopan dan bertahap.
3. Kebutuhan data wajib sebelum membuat rencana studi:
   - Program Studi resmi di FTMM (Rekayasa Perangkat Lunak, Teknologi Sains Data, Teknik Robotika dan Kecerdasan Buatan, Teknik Elektro, Teknik Industri).
   - Semester saat ini (1-8).
   - Minat/fokus karir yang diinginkan.
4. Jangan pernah merekomendasikan mata kuliah acak di luar kurikulum FTMM.
5. Selalu gunakan Bahasa Indonesia yang ramah, jelas, dan profesional.
"""


def extract_slots_from_text(text: str, current_profile: StudentProfile) -> Tuple[StudentProfile, List[str]]:
    """
    Extracts student information slots from user conversation text using regex and heuristics.
    """
    p = current_profile.model_copy()
    lower_text = text.lower()

    # 1. Extract Program Studi
    if not p.program_studi:
        if any(w in lower_text for w in ["sains data", "data science", "tsd"]):
            p.program_studi = "Teknologi Sains Data"
        elif any(w in lower_text for w in ["rpl", "rekayasa perangkat lunak", "software engineering"]):
            p.program_studi = "Rekayasa Perangkat Lunak"
        elif any(w in lower_text for w in ["trkb", "robotika", "kecerdasan buatan"]):
            p.program_studi = "Teknik Robotika dan Kecerdasan Buatan"
        elif any(w in lower_text for w in ["elektro", "teknik elektro"]):
            p.program_studi = "Teknik Elektro"
        elif any(w in lower_text for w in ["industri", "teknik industri"]):
            p.program_studi = "Teknik Industri"

    # 2. Extract Semester
    sem_match = re.search(r"semester\s*([1-8])\b|sem\s*([1-8])\b|\b([1-8])(?:st|nd|rd|th)?\s*sem\b", lower_text)
    if sem_match:
        for group in sem_match.groups():
            if group and group.isdigit():
                p.semester_saat_ini = int(group)
                break

    # 3. Extract Target Kelulusan (7 or 8 semesters)
    target_match = re.search(r"(?:target|lulus|kelulusan)\s*(?:dalam)?\s*([78])\s*semester", lower_text)
    if target_match:
        p.target_kelulusan_semester = int(target_match.group(1))

    # 4. Extract Minat / Focus Topics
    interests = []
    if "machine learning" in lower_text or "ml" in lower_text.split():
        interests.append("Machine Learning")
    if "deep learning" in lower_text:
        interests.append("Deep Learning")
    if "computer vision" in lower_text or "vision" in lower_text:
        interests.append("Computer Vision")
    if "nlp" in lower_text or "natural language" in lower_text:
        interests.append("Natural Language Processing")
    if "data visual" in lower_text or "visualisasi" in lower_text:
        interests.append("Data Visualization")
    if "big data" in lower_text or "data engineer" in lower_text:
        interests.append("Big Data Architecture")
    if "backend" in lower_text or "cloud" in lower_text or "devops" in lower_text:
        interests.append("Cloud Computing & DevOps")
    if "qa" in lower_text or "testing" in lower_text or "quality assurance" in lower_text:
        interests.append("Software Quality Assurance & Testing")
    if "mobile" in lower_text or "web" in lower_text or "fullstack" in lower_text:
        interests.append("Pemrograman Web & Mobile")

    for item in interests:
        if item not in p.minat_fokus:
            p.minat_fokus.append(item)

    # 5. Extract completed past courses indicator
    if any(phrase in lower_text for phrase in ["sudah lulus", "lulus semua", "sudah aman", "lunas", "sudah diambil"]):
        if p.semester_saat_ini and p.semester_saat_ini > 1:
            if not p.riwayat_matkul_lulus:
                p.riwayat_matkul_lulus = [
                    "Matematika I", "Fisika Dasar I", "Matematika II", "Dasar Pemrograman", "Aljabar Linear"
                ]

    # Check missing required slots
    missing = []
    if not p.program_studi:
        missing.append("Program Studi di FTMM")
    if not p.semester_saat_ini:
        missing.append("Semester saat ini")
    if not p.minat_fokus:
        missing.append("Minat atau bidang fokus studi yang ingin didalami")

    return p, missing


async def call_ollama_if_available(prompt: str, model: str = DEFAULT_MODEL) -> Optional[str]:
    """
    Attempts to query local Ollama instance if active.
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                f"{OLLAMA_BASE_URL}/api/generate",
                json={
                    "model": model,
                    "prompt": prompt,
                    "system": SYSTEM_PROMPT,
                    "stream": False,
                }
            )
            if resp.status_code == 200:
                data = resp.json()
                return data.get("response", "").strip()
    except Exception:
        # Ollama server offline or not yet started; fallback to deterministic agent
        return None
    return None


async def process_chat_message(request: ChatRequest) -> ChatResponse:
    """
    Orchestrates slot-filling dialog, strict clarifications, and tool-triggering.
    """
    profile = request.student_profile or StudentProfile()
    user_msg = request.message.strip()
    lower_msg = user_msg.lower()

    # Step 1: Slot extraction
    updated_profile, missing_slots = extract_slots_from_text(user_msg, profile)

    # Check if user is explicitly confirming a previously presented summary (using word boundaries)
    is_confirming = bool(re.search(r"\b(ya|benar|sesuai|oke|ok|buatkan|gas|setuju|betul|lanjutkan)\b", lower_msg))
    is_planning_intent = bool(re.search(r"\b(plan|planner|rencana|rekomendasi|krs|studi|jadwal|matkul|ambil)\b", lower_msg))
    # CASE A: If user is asking a general greeting or question without planning intent and without any profile slots
    has_any_slot = bool(updated_profile.program_studi or updated_profile.semester_saat_ini or updated_profile.minat_fokus)
    if not is_planning_intent and not has_any_slot and len(request.history) == 0:
        reply = (
            "Halo! Saya **Compass AI**, asisten akademik pintar FTMM Universitas Airlangga. 🧭\n\n"
            "Saya dapat membantu Anda menyusun **Rencana Studi (Study Planner)** yang dipersonalisasi sesuai minat karir dan aturan prasyarat kurikulum FTMM.\n\n"
            "Ada yang bisa saya bantu hari ini?"
        )
        return ChatResponse(
            reply=reply,
            updated_profile=updated_profile,
            action_type="GENERAL_CHAT",
            missing_slots=["Program Studi", "Semester saat ini", "Minat fokus"]
        )

    # CASE B: Missing essential slots -> Ask strict clarifying questions
    if missing_slots:
        questions = []
        if "Program Studi di FTMM" in missing_slots:
            questions.append("1. Apa **Program Studi** Anda di FTMM? *(contoh: Teknologi Sains Data, Rekayasa Perangkat Lunak, TRKB, dll.)*")
        if "Semester saat ini" in missing_slots:
            questions.append(f"{len(questions) + 1}. Sedang menempuh **Semester berapa** saat ini?")
        if "Minat atau bidang fokus studi yang ingin didalami" in missing_slots:
            questions.append(f"{len(questions) + 1}. Apa **topik atau minat karir** yang ingin difokuskan? *(contoh: Machine Learning, Cloud/DevOps, Data Viz, Computer Vision)*")

        reply = (
            "Agar saya dapat menyusun rencana studi yang akurat tanpa salah asumsi, mohon lengkapi informasi berikut:\n\n"
            + "\n".join(questions)
        )
        return ChatResponse(
            reply=reply,
            updated_profile=updated_profile,
            action_type="NEED_INFO",
            missing_slots=missing_slots
        )

    # CASE C: All slots are present, but not yet confirmed by the user
    if not updated_profile.is_confirmed_by_user and not is_confirming:
        reply = (
            f"Terima kasih! Berikut adalah rangkuman data rencana studimu:\n\n"
            f"• **Program Studi**: {updated_profile.program_studi}\n"
            f"• **Semester Saat Ini**: Semester {updated_profile.semester_saat_ini}\n"
            f"• **Minat Fokus**: {', '.join(updated_profile.minat_fokus)}\n"
            f"• **Target Kelulusan**: {updated_profile.target_kelulusan_semester} Semester\n"
            f"• **Batas Beban SKS**: Maks. {updated_profile.maks_sks_per_semester} SKS / semester\n\n"
            f"Apakah data di atas sudah sesuai? Jika sudah benar, konfirmasi dengan membalas **'Ya, buatkan'** untuk menyusun rencana studi."
        )
        return ChatResponse(
            reply=reply,
            updated_profile=updated_profile,
            action_type="CONFIRM_PROFILE",
            missing_slots=[]
        )

    # CASE D: All slots present and confirmed -> Trigger Planner Tool
    updated_profile.is_confirmed_by_user = True
    plan_payload = generate_study_plan(updated_profile)

    reply = (
        f"🎉 **Rencana studi telah berhasil disusun dan divalidasi!**\n\n"
        f"• **Prodi**: {plan_payload.summary.program_studi}\n"
        f"• **Total SKS**: {plan_payload.summary.total_credits} SKS\n"
        f"• **Target Selesai**: Semester {plan_payload.summary.target_semester}\n"
        f"• **Fokus**: {', '.join(plan_payload.summary.focus_tracks)}\n\n"
        f"Semua rantai prasyarat (DAG) dan paritas semester Ganjil/Genap telah dipastikan valid. "
        f"Silakan klik tombol di bawah ini untuk menerapkan rencana ini langsung ke halaman **Degree Planner**."
    )

    return ChatResponse(
        reply=reply,
        updated_profile=updated_profile,
        plan_payload=plan_payload,
        action_type="PLAN_GENERATED",
        missing_slots=[]
    )
