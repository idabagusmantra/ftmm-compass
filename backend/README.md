# FTMM Compass — Backend API

FastAPI backend gateway for FTMM Compass, powering academic study plan synthesis, Docker microservice proxying, and deterministic prerequisite graph validation.

---

## 🏗️ Architecture & Structure

```
backend/
├── app.py                     # Komposisi aplikasi: middleware, mount router /api/v1 + /api, port discovery
├── settings.py                # Satu-satunya pembaca environment (DATABASE_URL, port, JWT, rate limit, CORS)
├── api/                       # Router per resource: auth, courses, chat, dashboard, health, plans, polling, academic_periods
├── auth.py                    # JWT, password hashing, dependency user aktif
├── database.py                # Async engine & session factory
├── models.py                  # Model SQLAlchemy (tabel PostgreSQL V2.1 RC1)
├── schemas.py                 # Pydantic request/response contracts
├── academics.py               # Batas SKS, total kredit, konversi nilai, parity semester
├── catalog.py                 # Katalog dari database + fallback Ekstrak, alias prodi
├── rate_limit.py              # Rate limiter bersama seluruh router
├── seed.py                    # Seeder idempoten (user, katalog, record akademik)
├── build_catalog.py           # Bangun katalog canonical dari tabel Panduan Pendidikan
├── seed_full_catalog.py       # Seed katalog penuh dari database/seed/*.json
├── reconcile_catalog.py       # Rekonsiliasi Ekstrak/*.json ke keputusan reviewer
├── verify_catalog_sources.py  # Cocokkan kode MK ke PDF kurikulum sumber
├── alembic.ini                # Konfigurasi migrasi
├── migrations/                # Revisi Alembic
├── tools/
│   ├── planner.py             # Deterministic 8-semester degree plan synthesis engine
│   └── prerequisite_validator.py # DAG-based prerequisite & semester parity validator
├── pyproject.toml             # Astral UV project definition & dependencies
├── uv.lock                    # Dependency lockfile
├── .env.example               # Environment variable templates
└── tests/                     # Suite pytest (domain, endpoint, polling, chat)
```

---

## 🚀 Setup & Running

This backend uses **[Astral UV](https://docs.astral.sh/uv/)** for fast, reliable Python dependency and environment management.

### Prerequisites

- Python `>= 3.10`
- [Astral UV](https://docs.astral.sh/uv/getting-started/installation/)
- [Ollama](https://ollama.ai) (optional, for local LLM inference with `qwen2.5:3b-instruct`)

### 1. Install Dependencies

```bash
cd backend
uv sync
```

### 2. Configure Environment

Copy `.env.example` to `.env` (optional, sane defaults are provided):

```bash
cp .env.example .env
```

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://postgres:postgres@localhost:5432/ftmm_compass_dev` | Async SQLAlchemy DSN for PostgreSQL |
| `BACKEND_PORT` / `PORT` | kosong (auto-detect 8001–8050) | Listening port for FastAPI server |
| `HOST` | `0.0.0.0` | Bind host address |
| `AUTO_SEED` | `true` | Seed database saat startup |
| `CHATBOT_SERVICE_URL` | `http://127.0.0.1:8000` (host) / `http://ftmm-compass-chatbot:8000` (Docker) | Upstream URL for Chatbot AI microservice |
| `CHATBOT_TIMEOUT_SECONDS` | `45.0` | Timeout in seconds for Chatbot microservice calls |
| `JWT_SECRET_KEY` | dev default | Signing key access token |
| `DEFAULT_RATE_LIMIT` | `300/minute` | Slowapi limit per client |
| `CORS_ORIGINS` | `*` | Allowed CORS origins, dipisah koma |
### 3. Run Development Server

From within `backend/`:
```bash
uv run python app.py
```

Or from project root using pnpm scripts:
```bash
pnpm dev:backend   # runs backend only
pnpm dev:all       # runs backend and Vite frontend concurrently
```

When started via `app.py`, the backend automatically finds an open port between 8001 and 8050, records it to `.backend-port`, and the Vite frontend proxy automatically routes `/api/*` calls.


### 4. Run via Docker Compose (Multi-Container ftmm-network)

Dalam lingkungan kontainer Docker terisolasi (Opsi B):
```bash
# 1. Pastikan bridge network bersama telah aktif
docker network create ftmm-network 2>/dev/null || true

# 2. Jalankan gateway & frontend
docker compose up -d
```
Kontainer `ftmm-compass-gateway` secara otomatis terhubung ke `ftmm-network` dan berkomunikasi langsung dengan `http://ftmm-compass-chatbot:8000` via DNS internal Docker.
---

## 📡 API Endpoints (Dual-Tier REST Architecture)

### Canonical REST Endpoints (`/api/v1`)
- `GET /api/v1/health` — Gateway health check, PostgreSQL status, and Docker Chatbot microservice connectivity.
- `POST /api/v1/auth/login` — Login NIM/NIP/email + password, mengembalikan access token JWT.
- `GET /api/v1/auth/me` — Identitas dan profil akun aktif.
- `PATCH /api/v1/auth/me/profile` — Perbarui profil (bio, minat karier, kontak).
- `GET /api/v1/notifications/me` — Daftar notifikasi pengguna aktif.
- `PATCH /api/v1/notifications/{notification_id}/read` — Tandai satu notifikasi terbaca.
- `POST /api/v1/notifications/mark-all-read` — Tandai semua notifikasi terbaca.
- `GET /api/v1/courses` — Catalog dari database PostgreSQL (`page`, `per_page`, filter prodi/tipe/semester, `q`).
- `GET /api/v1/courses/search` — Pencarian kode dan nama mata kuliah (`q`, `prodi`, `top_k`).
- `POST /api/v1/admin/courses` — Tambah mata kuliah kustom (admin).
- `PUT /api/v1/admin/courses/{course_id}` — Ubah mata kuliah kustom (admin).
- `DELETE /api/v1/admin/courses/{course_id}` — Hapus mata kuliah kustom (admin).
- `POST /api/v1/chat` — Conversational study planner gateway to Hybrid RAG-CAG microservice.
- `POST /api/v1/chat/stream` — Real-time Server-Sent Events (SSE) streaming endpoint for live token generation.
- `DELETE /api/v1/chat/sessions/{session_id}` — Hapus riwayat sesi chat.
- `POST /api/v1/plans/validations` — Validate student study plans against prerequisite graph DAG and semester parity constraints.
- `POST /api/v1/plans` — Generate deterministic, DAG-validated degree plan from complete student profile.
- `GET /api/v1/degree-plans` — Daftar skenario rencana studi tersimpan milik pengguna aktif (maks 10).
- `GET /api/v1/degree-plans/catalog` — MK milik kurikulum yang di-assign ke mahasiswa (dipakai picker Degree Planner).
- `POST /api/v1/degree-plans` — Buat skenario baru (`name`, `items`), 201 + `Location`.
- `GET /api/v1/degree-plans/{plan_id}` — Detail satu skenario; 404 bila bukan milik pengguna.
- `PUT /api/v1/degree-plans/{plan_id}/items` — Ganti seluruh isi rencana (idempoten), 422 untuk kode MK asing/paritas salah/duplikat.
- `PATCH /api/v1/degree-plans/{plan_id}` — Ubah nama dan/atau status (`draft`, `active`); satu `active` per pengguna.
- `DELETE /api/v1/degree-plans/{plan_id}` — Hapus skenario beserta itemnya (204).
- `GET /api/v1/me/course-records` — Transkrip mahasiswa aktif: status (`taking`/`passed`/`failed`/`transferred`), nilai, dan periode tiap MK.
- `POST /api/v1/me/course-records` — Tandai MK lulus (`course_code`, `final_grade`); upsert attempt periode aktif, 409 bila sudah lulus, 422 untuk nilai gagal/tidak dikenal.
- `DELETE /api/v1/me/course-records/{record_id}` — Batalkan catatan transkrip milik sendiri (204).
- `GET /api/v1/dashboard/me` — Telemetri dashboard adaptif per peran (student/lecturer/faculty_staff/admin). Untuk mahasiswa, `courses_planned`/`sks_planned` = item skenario `active` yang belum lulus.
- `GET /api/v1/academic-periods/current` — Periode akademik aktif.
- `GET /api/v1/polling/periods/active` — Periode polling MK pilihan yang sedang dibuka.
- `POST /api/v1/admin/polling/periods` — Buka periode polling baru (admin).
- `GET /api/v1/polling/my-votes` — Vote MK pilihan milik pengguna aktif.
- `POST /api/v1/polling/votes` — Submit/update vote prioritas.
- `DELETE /api/v1/polling/votes/{course_id}` — Batalkan vote.
- `GET /api/v1/polling/demand-analytics` — Rekap kuorum dan demand forecasting.
- `GET /api/v1/admin/polling/demand-analytics` — Rekap kuorum seluruh prodi (admin/dosen).

### Legacy Compatibility Endpoints (`/api`)
Setiap router yang sama dipasang ulang di `/api` tanpa duplikasi handler, sehingga semua path kanonik di atas juga tersedia sebagai `/api/<path>`. Alias historis yang tetap dipertahankan:
- `GET /api/health` — Legacy health check alias.
- `GET /api/courses` — Legacy courses catalog alias.
- `GET /api/courses/search` — Legacy courses search alias.
- `POST /api/chat` — Legacy chat alias.
- `POST /api/chat/stream` — Legacy chat streaming alias.
- `POST /api/plan/validate` — Legacy plan validation alias.
- `POST /api/plan/generate` — Legacy plan generation alias.
- `GET /docs` — Interactive OpenAPI / Swagger UI documentation.

### Standard Error Envelope
All 4xx and 5xx responses follow the standardized error payload:
```json
{
  "detail": "Descriptive message",
  "error": {
    "code": "upstream_service_unavailable | upstream_timeout | validation_error | http_error",
    "message": "Descriptive message",
    "details": []
  }
}
```
## 🧪 Testing

Run automated unit and integration tests:

```bash
# Domain, endpoint, polling, and chat gateway tests
uv run python -m pytest tests -q
```

---

## 🗄️ Database Coordination (PostgreSQL Baseline)

The relational schema baseline is `database/schema_v2_1_rc1.sql` (PostgreSQL 16); perubahan schema sejak baseline dikelola lewat migrasi Alembic di `backend/migrations/versions/` (`alembic upgrade head`). Migrasi indeks `c4d2e6f8a1b3` menjalankan `CREATE EXTENSION pg_trgm`, jadi role database harus boleh membuat ekstensi tersebut (atau ekstensi sudah di-provision oleh admin). Katalog asli 5 prodi diisi oleh `python seed_full_catalog.py` (tidak otomatis saat startup). Untuk detail lihat `database/seed/README.md`.
