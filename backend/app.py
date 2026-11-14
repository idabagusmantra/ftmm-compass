"""FTMM Compass Gateway: komposisi aplikasi.

Router per resource ada di `api/`; setiap router dipasang dua kali: `/api/v1`
(kanonik) dan `/api` (legacy, tanpa duplikasi handler).
"""

import os
from contextlib import asynccontextmanager

import httpx

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded

from api import (
    academic_periods,
    auth,
    chat,
    course_records,
    courses,
    dashboard,
    degree_plans,
    health,
    plans,
    polling,
)
import settings
from catalog import refresh_from_db
from rate_limit import limiter
from schemas import DegreePlanPayload, PlanValidationResponse


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        import concurrent.futures
        from alembic.config import Config
        from alembic import command
        alembic_ini_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "alembic.ini")
        if os.path.exists(alembic_ini_path):
            alembic_cfg = Config(alembic_ini_path)
            with concurrent.futures.ThreadPoolExecutor() as executor:
                executor.submit(command.upgrade, alembic_cfg, "head").result()
            print("[OK] Alembic migrations successfully applied to head", flush=True)
    except Exception as e:
        print(f"[WARN] Alembic migration notice: {e}", flush=True)

    if settings.AUTO_SEED:
        try:
            from seed import seed_data
            await seed_data()
        except Exception as e:
            print(f"[WARN] Auto-seed skipped or encountered an error: {e}", flush=True)

    try:
        from database import AsyncSessionLocal
        async with AsyncSessionLocal() as session:
            total_courses = await refresh_from_db(session)
        print(f"[OK] Katalog aktif dari database: {total_courses} mata kuliah", flush=True)
    except Exception as e:
        print(f"[WARN] Katalog DB tidak terbaca, memakai Ekstrak: {e}", flush=True)

    current_port = settings.PORT_OVERRIDE or settings.DEFAULT_BACKEND_PORT
    print(f"\n[INFO] FTMM Compass Gateway is LIVE & READY", flush=True)
    print(f"       Base API: http://127.0.0.1:{current_port}/api/v1", flush=True)
    print(f"       Swagger Docs: http://127.0.0.1:{current_port}/docs", flush=True)
    print(f"       Health Check: http://127.0.0.1:{current_port}/api/v1/health\n", flush=True)
    yield



app = FastAPI(
    title="FTMM Compass AI Study Planner Gateway",
    description="Backend Gateway API connecting FTMM Compass UI with the Hybrid RAG-CAG Chatbot microservice and prerequisite validator.",
    version="1.1.0",
    lifespan=lifespan,
)

app.state.limiter = limiter

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def mount_resource(router):
    """Daftarkan resource yang sama pada tier kanonik dan legacy."""
    app.include_router(router, prefix="/api/v1", tags=["v1"])
    app.include_router(router, prefix="/api", include_in_schema=False, tags=["legacy"])


for resource in (
    health,
    auth,
    courses,
    chat,
    plans,
    polling,
    dashboard,
    academic_periods,
    degree_plans,
    course_records,
):
    mount_resource(resource.router)

# Dua path legacy dengan nama berbeda tetap dilayani tanpa salinan handler.
app.add_api_route(
    "/api/plan/validate",
    plans.v1_validate_plan,
    methods=["POST"],
    response_model=PlanValidationResponse,
    include_in_schema=False,
)
app.add_api_route(
    "/api/plan/generate",
    plans.v1_generate_plan,
    methods=["POST"],
    response_model=DegreePlanPayload,
    include_in_schema=False,
)


@app.exception_handler(RateLimitExceeded)
def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        content={
            "error": {
                "code": "rate_limit_exceeded",
                "message": "Batas pengiriman pesan terlampaui (maksimal 20 request per menit).",
                "details": [],
            }
        },
    )

@app.exception_handler(ConnectionError)
async def connection_error_handler(request: Request, exc: ConnectionError):
    message = "Layanan Chatbot AI offline. Pastikan kontainer ftmm-compass-chatbot aktif di port 8000."
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        headers={"Retry-After": "5"},
        content={
            "detail": message,
            "error": {
                "code": "upstream_service_unavailable",
                "message": message,
                "details": [{"message": str(exc)}],
            },
        },
    )


@app.exception_handler(httpx.ConnectError)
async def httpx_connect_error_handler(request: Request, exc: httpx.ConnectError):
    message = "Layanan Chatbot AI offline. Pastikan kontainer ftmm-compass-chatbot aktif di port 8000."
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        headers={"Retry-After": "5"},
        content={
            "detail": message,
            "error": {
                "code": "upstream_service_unavailable",
                "message": message,
                "details": [{"message": str(exc)}],
            },
        },
    )


@app.exception_handler(httpx.TimeoutException)
async def httpx_timeout_handler(request: Request, exc: httpx.TimeoutException):
    message = "Waktu tunggu layanan Chatbot AI habis."
    return JSONResponse(
        status_code=status.HTTP_504_GATEWAY_TIMEOUT,
        content={
            "detail": message,
            "error": {
                "code": "upstream_timeout",
                "message": message,
                "details": [{"message": str(exc)}],
            },
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", status.HTTP_422_UNPROCESSABLE_ENTITY),
        content={
            "detail": "Request validation failed",
            "error": {
                "code": "validation_error",
                "message": "Request validation failed",
                "details": [
                    {
                        "field": ".".join(str(loc) for loc in err["loc"]),
                        "message": err["msg"],
                        "code": err["type"],
                    }
                    for err in exc.errors()
                ],
            },
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    headers = getattr(exc, "headers", None)
    if exc.status_code == status.HTTP_503_SERVICE_UNAVAILABLE:
        code = "upstream_service_unavailable"
    elif exc.status_code == status.HTTP_504_GATEWAY_TIMEOUT:
        code = "upstream_timeout"
    elif exc.status_code in (getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", 422), 422):
        code = "validation_error"
    elif exc.status_code == status.HTTP_404_NOT_FOUND:
        code = "not_found"
    elif exc.status_code == status.HTTP_500_INTERNAL_SERVER_ERROR:
        code = "internal_server_error"
    else:
        code = "http_error"

    return JSONResponse(
        status_code=exc.status_code,
        headers=headers,
        content={
            "detail": exc.detail,
            "error": {
                "code": code,
                "message": str(exc.detail),
                "details": [],
            },
        },
    )



def find_free_port(start_port: int = 8001, max_port: int = 8050) -> int:
    import socket

    if settings.PORT_OVERRIDE:
        return int(settings.PORT_OVERRIDE)
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

    print(f"Starting FTMM Compass Backend Gateway on http://0.0.0.0:{port}")
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)
