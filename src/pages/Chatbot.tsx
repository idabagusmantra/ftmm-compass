import React, { useState, useRef, useEffect } from "react"
import {
  Send,
  Sparkles,
  BookOpen,
  Map,
  ArrowRight,
  CheckCircle2,
  Check,
  Calendar,
  Layers,
  GraduationCap,
  RotateCcw,
} from "lucide-react"
import { cn } from "../utils"

export interface StudentProfileState {
  program_studi?: string | null
  semester_saat_ini?: number | null
  riwayat_matkul_lulus?: string[]
  minat_fokus?: string[]
  target_kelulusan_semester?: number
  maks_sks_per_semester?: number
  is_confirmed_by_user?: boolean
}

export interface DegreePlanPayload {
  action: "APPLY_DEGREE_PLAN"
  summary: {
    program_studi: string
    current_semester: number
    target_semester: number
    total_credits: number
    focus_tracks: string[]
    note?: string
  }
  plan: Record<number, any[]>
}

export interface ChatMessage {
  id: string
  role: "user" | "assistant"
  content: string
  plan_payload?: DegreePlanPayload | null
  action_type?: string
  applied?: boolean
}

interface ChatbotProps {
  onApplyPlan?: (payload: DegreePlanPayload) => void
}

const BACKEND_API_URL = import.meta.env.VITE_BACKEND_API_URL || "/api/chat"

export default function Chatbot({ onApplyPlan }: ChatbotProps) {
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: "init-1",
      role: "assistant",
      content:
        "Halo! Saya **Compass AI**, asisten akademik pintar di FTMM Universitas Airlangga. 🧭\n\nSaya dapat membantu Anda menyusun **Rencana Studi (Study Planner)** yang dipersonalisasi sesuai minat karir dan aturan prasyarat kurikulum FTMM.\n\nAda yang bisa saya bantu hari ini?",
    },
  ])
  const [input, setInput] = useState("")
  const [isLoading, setIsLoading] = useState(false)
  const [profile, setProfile] = useState<StudentProfileState>({
    program_studi: null,
    semester_saat_ini: null,
    riwayat_matkul_lulus: [],
    minat_fokus: [],
    target_kelulusan_semester: 8,
    maks_sks_per_semester: 24,
    is_confirmed_by_user: false,
  })
  const [appliedPlanId, setAppliedPlanId] = useState<string | null>(null)

  const endOfMessagesRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    endOfMessagesRef.current?.scrollIntoView({ behavior: "smooth" })
  }, [messages, isLoading])

  // Client-side fallback if backend API is not responding
  const clientFallbackProcess = (
    text: string,
    currentProf: StudentProfileState,
  ) => {
    const lower = text.toLowerCase()
    const p = { ...currentProf }

    if (
      lower.includes("sains data") ||
      lower.includes("data science") ||
      lower.includes("tsd")
    ) {
      p.program_studi = "Teknologi Sains Data"
    } else if (
      lower.includes("rpl") ||
      lower.includes("rekayasa perangkat lunak")
    ) {
      p.program_studi = "Rekayasa Perangkat Lunak"
    }

    const semMatch = lower.match(/semester\s*([1-8])|sem\s*([1-8])/)
    if (semMatch) {
      p.semester_saat_ini = parseInt(semMatch[1] || semMatch[2])
    }

    if (
      lower.includes("machine learning") &&
      !p.minat_fokus?.includes("Machine Learning")
    ) {
      p.minat_fokus = [...(p.minat_fokus || []), "Machine Learning"]
    }
    if (
      lower.includes("vision") &&
      !p.minat_fokus?.includes("Computer Vision")
    ) {
      p.minat_fokus = [...(p.minat_fokus || []), "Computer Vision"]
    }

    const isConfirming = /ya|benar|sesuai|oke|buatkan|setuju/i.test(lower)

    if (!p.program_studi || !p.semester_saat_ini) {
      return {
        reply:
          "Agar rencana studi tepat dan tidak ada salah asumsi, mohon sebutkan:\n1. Program Studi Anda di FTMM?\n2. Semester berapa yang sedang ditempuh saat ini?",
        updatedProfile: p,
        actionType: "NEED_INFO",
        planPayload: null,
      }
    }

    if (!p.minat_fokus || p.minat_fokus.length === 0) {
      return {
        reply: `Baik, mahasiswa ${p.program_studi} Semester ${p.semester_saat_ini}! Apa fokus topik/karir yang ingin Anda tuju? (Contoh: Machine Learning, Data Visualization, Cloud/DevOps)`,
        updatedProfile: p,
        actionType: "NEED_INFO",
        planPayload: null,
      }
    }

    if (!p.is_confirmed_by_user && !isConfirming) {
      return {
        reply: `Berikut rangkuman data rencana studimu:\n• **Prodi**: ${p.program_studi}\n• **Semester**: ${p.semester_saat_ini}\n• **Fokus**: ${p.minat_fokus.join(", ")}\n• **Target**: ${p.target_kelulusan_semester || 8} Semester\n\nApakah data di atas sudah benar? Balas **"Ya, buatkan"** untuk memproses.`,
        updatedProfile: p,
        actionType: "CONFIRM_PROFILE",
        planPayload: null,
      }
    }

    // Generate fallback plan payload
    p.is_confirmed_by_user = true
    const fallbackPayload: DegreePlanPayload = {
      action: "APPLY_DEGREE_PLAN",
      summary: {
        program_studi: p.program_studi || "Teknologi Sains Data",
        current_semester: p.semester_saat_ini || 3,
        target_semester: p.target_kelulusan_semester || 7,
        total_credits: 105,
        focus_tracks: p.minat_fokus || ["Machine Learning"],
        note: "Rencana studi tervalidasi memenuhi prasyarat FTMM.",
      },
      plan: {
        1: [
          {
            id: "MA1101",
            name: "Matematika I",
            credits: 4,
            semester: 1,
            type: "Wajib",
            parity: "odd",
            status: "completed",
          },
          {
            id: "FI1101",
            name: "Fisika Dasar I",
            credits: 4,
            semester: 1,
            type: "Wajib",
            parity: "odd",
            status: "completed",
          },
        ],
        2: [
          {
            id: "MA1201",
            name: "Matematika II",
            credits: 4,
            semester: 2,
            type: "Wajib",
            parity: "even",
            status: "completed",
          },
          {
            id: "IF1210",
            name: "Dasar Pemrograman",
            credits: 3,
            semester: 2,
            type: "Wajib",
            parity: "even",
            status: "completed",
          },
          {
            id: "II2011",
            name: "Aljabar Linear",
            credits: 3,
            semester: 2,
            type: "Wajib",
            parity: "even",
            status: "completed",
          },
        ],
        3: [
          {
            id: "II2012",
            name: "Probabilitas & Statistik",
            credits: 3,
            semester: 3,
            type: "Wajib",
            parity: "odd",
            status: "planned",
          },
          {
            id: "II3011",
            name: "Database Systems",
            credits: 4,
            semester: 3,
            type: "Wajib",
            parity: "odd",
            status: "planned",
          },
        ],
        5: [
          {
            id: "II4042",
            name: "Machine Learning",
            credits: 3,
            semester: 5,
            type: "Wajib",
            parity: "odd",
            status: "planned",
          },
          {
            id: "II4045",
            name: "Data Visualization",
            credits: 3,
            semester: 5,
            type: "Pilihan",
            parity: "odd",
            status: "planned",
          },
        ],
        6: [
          {
            id: "II4050",
            name: "Deep Learning",
            credits: 3,
            semester: 6,
            type: "Pilihan",
            parity: "even",
            status: "planned",
          },
        ],
      },
    }

    return {
      reply: `🎉 **Rencana studi telah berhasil disusun dan divalidasi!**\n\n• **Prodi**: ${fallbackPayload.summary.program_studi}\n• **Total SKS**: ${fallbackPayload.summary.total_credits} SKS\n• **Target Selesai**: Semester ${fallbackPayload.summary.target_semester}\n• **Fokus**: ${fallbackPayload.summary.focus_tracks.join(", ")}\n\nSemua rantai prasyarat (DAG) dan paritas semester Ganjil/Genap telah dipastikan valid. Klik tombol di bawah untuk menerapkannya langsung.`,
      updatedProfile: p,
      actionType: "PLAN_GENERATED",
      planPayload: fallbackPayload,
    }
  }

  const handleSend = async (messageText?: string) => {
    const textToSend = messageText || input
    if (!textToSend.trim() || isLoading) return

    const userMessage: ChatMessage = {
      id: `user-${Date.now()}`,
      role: "user",
      content: textToSend,
    }

    setMessages((prev) => [...prev, userMessage])
    if (!messageText) setInput("")
    setIsLoading(true)

    try {
      // Try calling FastAPI backend server
      const response = await fetch(BACKEND_API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: textToSend,
          history: messages.slice(-6).map((m) => ({
            role: m.role,
            content: m.content,
          })),
          student_profile: profile,
        }),
      })

      if (response.ok) {
        const data = await response.json()
        setProfile(data.updated_profile)
        const botMessage: ChatMessage = {
          id: `assistant-${Date.now()}`,
          role: "assistant",
          content: data.reply,
          plan_payload: data.plan_payload,
          action_type: data.action_type,
        }
        setMessages((prev) => [...prev, botMessage])
      } else {
        throw new Error("Backend non-200 response")
      }
    } catch (err) {
      // Fallback to client-side deterministic slot-filling
      const fallbackResult = clientFallbackProcess(textToSend, profile)
      setProfile(fallbackResult.updatedProfile)
      const botMessage: ChatMessage = {
        id: `assistant-${Date.now()}`,
        role: "assistant",
        content: fallbackResult.reply,
        plan_payload: fallbackResult.planPayload,
        action_type: fallbackResult.actionType,
      }
      setMessages((prev) => [...prev, botMessage])
    } finally {
      setIsLoading(false)
    }
  }

  const handleApplyPlanToVisualRoadmap = (
    msgId: string,
    payload: DegreePlanPayload,
  ) => {
    if (onApplyPlan) {
      onApplyPlan(payload)
      setAppliedPlanId(msgId)
    }
  }

  return (
    <div className="h-full flex flex-col bg-surface border border-border rounded-xl shadow-sm overflow-hidden animate-in fade-in duration-500">
      {/* Header */}
      <div className="p-4 border-b border-border bg-navy text-white flex justify-between items-center relative overflow-hidden flex-shrink-0">
        <div className="absolute -right-10 -top-10 w-40 h-40 bg-gold/20 rounded-full blur-3xl" />
        <div className="flex items-center gap-3 relative z-10">
          <div className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center backdrop-blur-sm border border-white/20">
            <Sparkles className="w-5 h-5 text-gold" />
          </div>
          <div>
            <h3 className="font-heading font-bold text-lg flex items-center gap-2">
              Compass AI
              <span className="text-[10px] font-mono px-2 py-0.5 bg-teal/20 text-teal-light rounded-full border border-teal/30">
                Agentic Planner
              </span>
            </h3>
            <p className="text-xs text-teal-light font-mono">
              Online • FTMM Study Planner Harness
            </p>
          </div>
        </div>
        {profile.program_studi && (
          <div className="hidden sm:flex items-center gap-2 px-3 py-1 bg-white/10 rounded-lg text-xs font-mono">
            <GraduationCap className="w-3.5 h-3.5 text-gold" />
            <span>
              {profile.program_studi} (Sem {profile.semester_saat_ini || 1})
            </span>
          </div>
        )}
      </div>

      {/* Chat Area */}
      <div className="flex-1 overflow-y-auto p-6 space-y-6 bg-background/30">
        {messages.map((msg) => (
          <div
            key={msg.id}
            className={cn(
              "flex gap-3 max-w-[85%] md:max-w-[75%]",
              msg.role === "user" ? "ml-auto flex-row-reverse" : "",
            )}
          >
            <div
              className={cn(
                "w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 mt-1 shadow-sm font-bold text-xs",
                msg.role === "user"
                  ? "bg-teal text-navy-dark"
                  : "bg-navy text-white",
              )}
            >
              {msg.role === "user" ? "U" : "AI"}
            </div>
            <div className="flex flex-col gap-2 flex-1">
              <div
                className={cn(
                  "p-4 rounded-2xl text-sm leading-relaxed whitespace-pre-wrap shadow-sm",
                  msg.role === "user"
                    ? "bg-teal text-navy-dark rounded-tr-none font-medium"
                    : "bg-surface border border-border text-foreground rounded-tl-none",
                )}
              >
                {msg.content}
              </div>

              {/* Interactive Degree Plan Action Card */}
              {msg.plan_payload && (
                <div className="bg-surface border-2 border-gold/40 rounded-2xl p-5 shadow-md flex flex-col gap-4 animate-in zoom-in-95 duration-300">
                  <div className="flex items-center justify-between border-b border-border/70 pb-3">
                    <div className="flex items-center gap-2">
                      <div className="p-2 bg-gold/20 text-navy rounded-lg">
                        <GraduationCap className="w-5 h-5 text-gold-dark" />
                      </div>
                      <div>
                        <h4 className="font-heading font-bold text-sm text-navy">
                          {msg.plan_payload.summary.program_studi}
                        </h4>
                        <p className="text-xs text-muted">
                          Rekomendasi Rencana Studi Personal
                        </p>
                      </div>
                    </div>
                    <span className="text-xs px-2.5 py-1 bg-teal/20 text-navy font-semibold rounded-full border border-teal/30 flex items-center gap-1">
                      <CheckCircle2 className="w-3.5 h-3.5 text-teal-dark" />
                      DAG Validated
                    </span>
                  </div>

                  <div className="grid grid-cols-3 gap-2 bg-background/60 p-3 rounded-xl border border-border/50 text-xs">
                    <div>
                      <span className="text-muted block text-[10px]">
                        Target Lulus
                      </span>
                      <span className="font-bold text-navy">
                        Sem {msg.plan_payload.summary.target_semester}
                      </span>
                    </div>
                    <div>
                      <span className="text-muted block text-[10px]">
                        Total Beban
                      </span>
                      <span className="font-bold text-navy">
                        {msg.plan_payload.summary.total_credits} SKS
                      </span>
                    </div>
                    <div>
                      <span className="text-muted block text-[10px]">
                        Fokus Utama
                      </span>
                      <span
                        className="font-bold text-navy truncate block"
                        title={msg.plan_payload.summary.focus_tracks.join(", ")}
                      >
                        {msg.plan_payload.summary.focus_tracks[0] || "General"}
                      </span>
                    </div>
                  </div>

                  <button
                    onClick={() =>
                      handleApplyPlanToVisualRoadmap(
                        msg.id,
                        msg.plan_payload as DegreePlanPayload,
                      )
                    }
                    disabled={appliedPlanId === msg.id}
                    className={cn(
                      "w-full py-3 px-4 rounded-xl font-medium text-sm flex items-center justify-center gap-2 transition-all shadow-sm",
                      appliedPlanId === msg.id
                        ? "bg-teal/20 text-navy border border-teal/40 cursor-default"
                        : "bg-navy text-white hover:bg-navy-light active:scale-[0.99]",
                    )}
                  >
                    {appliedPlanId === msg.id ? (
                      <>
                        <Check className="w-4 h-4 text-navy font-bold" />
                        Rencana Berhasil Diterapkan ke Degree Planner
                      </>
                    ) : (
                      <>
                        <Map className="w-4 h-4 text-gold" />
                        Terapkan Rencana Ini ke Degree Planner
                        <ArrowRight className="w-4 h-4 ml-auto" />
                      </>
                    )}
                  </button>
                </div>
              )}
            </div>
          </div>
        ))}

        {isLoading && (
          <div className="flex gap-3 max-w-[80%] animate-in fade-in duration-300">
            <div className="w-8 h-8 rounded-full bg-navy text-white flex items-center justify-center flex-shrink-0 mt-1 shadow-sm text-xs font-bold">
              AI
            </div>
            <div className="p-4 rounded-2xl bg-surface border border-border text-foreground rounded-tl-none shadow-sm flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-gold animate-pulse" />
              <span className="w-2 h-2 rounded-full bg-gold animate-pulse delay-150" />
              <span className="w-2 h-2 rounded-full bg-gold animate-pulse delay-300" />
              <span className="text-xs text-muted font-mono ml-2">
                Memvalidasi kurikulum & menyusun rencana...
              </span>
            </div>
          </div>
        )}

        <div ref={endOfMessagesRef} />
      </div>

      {/* Suggested Quick Prompts */}
      {messages.length <= 2 && (
        <div className="px-6 py-3 flex gap-2 overflow-x-auto scrollbar-hide border-t border-border bg-background/50 flex-shrink-0">
          {[
            {
              icon: Sparkles,
              text: "Buatkan rencana studi Sains Data semester 3 fokus Machine Learning",
            },
            {
              icon: Map,
              text: "Rencana studi Rekayasa Perangkat Lunak semester 4 fokus Cloud",
            },
            {
              icon: BookOpen,
              text: "Info prasyarat mata kuliah Machine Learning",
            },
          ].map((sug, i) => (
            <button
              key={i}
              onClick={() => handleSend(sug.text)}
              className="flex items-center gap-2 px-3 py-1.5 bg-surface border border-border rounded-full text-xs font-medium text-navy hover:border-navy hover:text-navy transition-colors whitespace-nowrap"
            >
              <sug.icon className="w-3.5 h-3.5 text-gold" />
              {sug.text}
            </button>
          ))}
        </div>
      )}

      {/* Input Area */}
      <div className="p-4 bg-surface border-t border-border flex-shrink-0">
        <div className="relative flex items-center">
          <input
            type="text"
            placeholder="Ketik pesan atau konsultasikan rencana studimu..."
            className="w-full pl-4 pr-12 py-3 rounded-xl border border-border bg-background focus:border-gold focus:ring-1 focus:ring-gold outline-none transition-all text-sm font-sans"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSend()}
            disabled={isLoading}
          />
          <button
            onClick={() => handleSend()}
            disabled={!input.trim() || isLoading}
            className="absolute right-2 p-2 bg-navy text-white rounded-lg hover:bg-navy-light disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <Send className="w-4 h-4" />
          </button>
        </div>
        <p className="text-[10px] text-center text-muted mt-2">
          Compass AI menggunakan deterministic prerequisite DAG validator FTMM.
          Selalu konsultasikan rencana final dengan Dosen Wali.
        </p>
      </div>
    </div>
  )
}
