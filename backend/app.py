import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from schemas import (
    ChatRequest,
    ChatResponse,
    StudentProfile,
    DegreePlanPayload,
    PlanValidationRequest,
    PlanValidationResponse,
)
from agent import process_chat_message, OLLAMA_BASE_URL, DEFAULT_MODEL
from data_loader import get_courses_for_program, normalize_prodi
from tools.planner import generate_study_plan
from tools.prerequisite_validator import validate_plan_constraints


app = FastAPI(
    title="FTMM Compass AI Study Planner API",
    description="Backend API with LangChain / LLM slot-filling agent and deterministic prerequisite validator for FTMM study planning.",
    version="1.0.0",
)

# Enable CORS for Vite frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
async def health_check():
    """
    Checks backend health and Ollama local server connectivity.
    """
    ollama_online = False
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            if resp.status_code == 200:
                ollama_online = True
    except Exception:
        ollama_online = False

    return {
        "status": "healthy",
        "service": "FTMM Compass AI Planner",
        "ollama_online": ollama_online,
        "default_model": DEFAULT_MODEL,
    }


@app.get("/api/courses")
async def list_courses(prodi: str = "Teknologi Sains Data"):
    """
    Returns the official course catalog for the specified study program.
    """
    norm_prodi = normalize_prodi(prodi) or "Teknologi Sains Data"
    courses = get_courses_for_program(norm_prodi)
    return {
        "program_studi": norm_prodi,
        "total_courses": len(courses),
        "courses": [c.model_dump() for c in courses],
    }


@app.post("/api/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    """
    Main conversational endpoint: slot-filling, clarifying questions, and planner tool execution.
    """
    try:
        response = await process_chat_message(request)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing chat: {str(e)}")


@app.post("/api/plan/generate", response_model=DegreePlanPayload)
async def generate_plan_endpoint(profile: StudentProfile):
    """
    Generates a deterministic, prerequisite-validated study plan from a complete student profile.
    """
    try:
        return generate_study_plan(profile)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating plan: {str(e)}")


@app.post("/api/plan/validate", response_model=PlanValidationResponse)
async def validate_plan_endpoint(request: PlanValidationRequest):
    """
    Validates a student degree plan against prerequisite DAGs, parities, and SKS limits.
    """
    try:
        return validate_plan_constraints(
            plan=request.plan,
            riwayat_matkul_lulus=request.riwayat_matkul_lulus,
            maks_sks_per_semester=request.maks_sks_per_semester,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error validating plan: {str(e)}")


def find_free_port(start_port: int = 8000, max_port: int = 8050) -> int:
    import socket
    import os
    env_port = os.getenv("BACKEND_PORT", os.getenv("PORT"))
    if env_port:
        return int(env_port)
    for p in range(start_port, max_port + 1):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("0.0.0.0", p))
                return p
            except OSError:
                continue
    return start_port


if __name__ == "__main__":
    import atexit
    import uvicorn
    from pathlib import Path

    port = find_free_port()
    port_file = Path(__file__).resolve().parent.parent / ".backend-port"
    try:
        port_file.write_text(str(port), encoding="utf-8")

        def cleanup_port_file():
            if port_file.exists():
                try:
                    port_file.unlink()
                except OSError:
                    pass

        atexit.register(cleanup_port_file)
    except Exception as e:
        print(f"Warning: could not write .backend-port: {e}")

    print(f"Starting FTMM Compass Backend on http://0.0.0.0:{port}")
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)
