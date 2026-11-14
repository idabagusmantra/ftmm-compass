# FTMM Compass — Academic Advisor & Agentic Study Planner

Academic-advisor web app and AI study planner for **FTMM (Fakultas Teknologi Maju dan Multidisiplin), Universitas Airlangga**.

FTMM Compass helps students plan their degree journey across 8 semesters, explore official course catalogs, visualize prerequisite DAGs, manage weekly class timetables, and consult with **Compass AI** — an agentic study planner that personalizes course roadmaps based on student backgrounds, career interests, and strict FTMM academic constraints.

---

## System Architecture

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                   FTMM COMPASS 3-TIER GATEWAY ARCHITECTURE                     │
└────────────────────────────────────────────────────────────────────────────────┘

 ┌──────────────────────────────────────────────────────────────────────────────┐
 │                     Tier 1: Modular Frontend (React 19)                      │
 │                                                                              │
 │   ┌───────────────┐   ┌────────────────┐   ┌─────────────────────────────┐   │
 │   │   Dashboard   │   │  CourseFinder  │   │        DegreePlanner        │   │
 │   │ (Stats & Grid)│   │(Detail/Modal/  │   │ (PlannerHeader, SemColumn,  │   │
 │   └───────────────┘   │ PrereqDiagram) │   │  PickerModal, ElectiveBank) │   │
 │                       └────────────────┘   └──────────────▲──────────────┘   │
 │                                                           │                  │
 │                                      [Apply AI Plan] ─────┘                  │
 │                                                           │                  │
 │                                            ┌──────────────┴──────────────┐   │
 │                                            │      Compass AI Chatbot     │   │
 │                                            │ (SSE Stream & Action Cards) │   │
 │                                            └──────────────▲──────────────┘   │
 └───────────────────────────────────────────────────────────┼──────────────────┘
                                                             │
                               Vite Dynamic Proxy (/api/v1/* & /api/* via .backend-port)
                                                             │
 ┌───────────────────────────────────────────────────────────▼──────────────────┐
 │                     Tier 2: Backend Gateway Service (FastAPI)                │
 │                                                                              │
 │   ┌──────────────────────────────────────────────────────────────────────┐   │
 │   │      Dual-Router Gateway (/api/v1 & /api) + Resilient Fallback       │   │
 │   │       (Probes Microservice; Falls Back to Local Tools if Offline)    │   │
 │   └───────────────────────┬──────────────────────────────┬───────────────┘   │
 │                           │                              │                   │
 │        [HTTP / SSE Forward /api/v1/chat]       [Local Deterministic Engine]  │
 │                           │                              │                   │
 │                           ▼                              ▼                   │
 │ ┌──────────────────────────────────┐   ┌───────────────────────────────────┐ │
 │ │ Tier 3: AI Microservice (Docker) │   │     Deterministic Tools Layer     │ │
 │ │ • Repo: ftmm-compass-chatbot     │   │ • Prerequisite DAG Validator      │ │
 │ │ • Port: 8000 (Hybrid RAG-CAG)    │   │ • Semester Parity Validator       │ │
 │ │ • Ollama: qwen2.5:3b (Port 11434)│   │ • 5-Prodi FTMM Curriculum Loader  │ │
 │ │ • FAISS Cosine Vector Retriever  │   │ • 8-Semester Plan Synthesizer     │ │
 │ └──────────────────────────────────┘   └───────────────────────────────────┘ │
 └──────────────────────────────────────────────────────────────────────────────┘
```
---

## Key Features

### 1. Dashboard
- Ringkasan statistik akademik dari `/api/v1/dashboard/me`: SKS kumulatif, semester aktif, dan IPK (data PostgreSQL, tanpa angka demo; tampilan kosong bila DB belum di-seed). Angka **Direncanakan** dihitung dari item skenario rencana studi `active` yang belum lulus, bukan dari `record_status='taking'`.
- Widget jadwal mingguan interaktif (*Timetable*) dengan deteksi bentrok jadwal (*conflict highlighting*).

### 2. Course Finder
- Pencarian dan filter katalog mata kuliah berdasarkan prodi, semester, SKS, dan tipe (Wajib/Pilihan). Katalog dibaca dari database lewat `/api/v1/courses`.
- Modal detail mata kuliah dilengkapi **Prerequisite Flow Diagram (SVG)** untuk melihat rantai mata kuliah prasyarat.

### 3. Degree Planner
- Papan visual rencana studi 8 semester (*Roadmap*):
  - Mata kuliah **Wajib** otomatis terkunci di semesternya.
  - Mata kuliah **Pilihan** dapat dipindah-pindah via *drag and drop*.
  - Menegakkan aturan paritas semester (**Ganjil/Odd** $\rightarrow$ Semester 1, 3, 5, 7; **Genap/Even** $\rightarrow$ Semester 2, 4, 6, 8).
  - Mata kuliah yang sudah **lulus** di transkrip (`/api/v1/me/course-records`) tampil terkunci di semester kurikulumnya dan otomatis dikeluarkan dari payload skenario; MK yang sedang ditempuh dapat ditandai selesai (beserta nilai) atau dibatalkan dari modal detail.
- Rencana disimpan di server (`degree_plans` / `degree_plan_items` via `/api/v1/degree-plans`), bukan di `localStorage`: data bertahan setelah ganti perangkat atau membersihkan browser, dan status simpan ditampilkan di header.
- Beberapa skenario rencana per mahasiswa (maksimal 10, satu `active`) dengan aksi salin dan hapus skenario.
- Tab **Jadwal Aktif** untuk melihat distribusi kelas per semester.
- Banner rencana personalisasi saat rencana dari Compass AI diterapkan.

### 4. Compass AI (Agentic Study Planner)
- **Slot-Filling Conversational Flow**: Mengumpulkan profil mahasiswa (Prodi, Semester, Riwayat Kelulusan, Minat Karir, Target Kelulusan) melalui percakapan alami.
- **Anti-Assumption Guardrails**: Tidak pernah menebak atau mengasumsikan data mahasiswa yang belum jelas. Jika data kurang, agen akan menanyakan klarifikasi secara ramah.
- **Deterministic DAG & Parity Validation**: Menguji validitas rencana secara deterministik dengan aturan resmi kurikulum FTMM sebelum diserahkan ke mahasiswa.
- **One-Click UI Transfer**: Hasil rencana studi dilengkapi kartu aksi interaktif **[Terapkan Rencana Ini ke Degree Planner]** yang langsung mengisi papan visual roadmap.

---

## Tech Stack

### Frontend
- **React 19** + **TypeScript 5.7**
- **Vite 8** dev server & production bundler
- **Tailwind CSS v4** via `@tailwindcss/vite` (desain sistem dengan palet Navy, Gold, Teal)
- **Lucide React** untuk icon UI

### Backend & AI Services
- **Python 3.10+** (managed via **[Astral UV](https://docs.astral.sh/uv/)**)
- **FastAPI Gateway** + **Uvicorn** (RESTful API, dynamic port auto-discovery 8001–8050, & CORS; port 8000 dipakai microservice chatbot)
- **HTTPX** (Asynchronous client with timeout & resilient local fallback)
- **Pydantic v2** (Strict data validation schemas & DegreePlanPayload contracts)
- **AI Microservice (Docker)**: Hybrid RAG-CAG engine (`ftmm-compass-chatbot` on Port 8000)
- **Local LLM & Embeddings**: Ollama (`qwen2.5:3b`, `nomic-embed-text` on Port 11434)

## Cara Menjalankan Project

> **Panduan Pengembang Lengkap:** Untuk panduan onboarding mendalam, diagnosa toolchain, arsitektur lingkungan pengembang, dan referensi automasi `Makefile`, baca [**`docs/ONBOARDING.md`**](./docs/ONBOARDING.md).

### 1. Quick Start Automasi (`Makefile` — Direkomendasikan)

Jika Anda menggunakan sistem berbasis POSIX (Linux, macOS, atau Windows WSL2), seluruh alur inisialisasi lingkungan pengembang dan eksekusi server dapat dijalankan secara instan via `Makefile`:

```bash
# 1. Setup otomatis: verifikasi toolchain, buat .env, pasang pnpm/uv, jalankan DB, migrasi, & seed data
make setup

# 2. Jalankan Frontend & Backend secara bersamaan (Mode Hybrid: DB di Docker, App di host)
make dev
```

Perintah pembantu lainnya:
- `make doctor` — Memeriksa kesiapan toolchain (Node, pnpm, Python, uv, Docker).
- `make db-up` / `make db-down` — Menyalakan/menghentikan container PostgreSQL 16.
- `make db-reset` — Mereset database dari nol (recreate volume, migrasi Alembic, & seeding).
- `make help` — Menampilkan seluruh daftar perintah automasi yang tersedia.

---

### 2. Dua Mode Menjalankan Aplikasi: Hybrid vs Full Docker

Terdapat dua mode eksekusi yang didukung:

#### Mode A: Hybrid Mode (Sangat Direkomendasikan untuk Daily Coding)
- **Database**: PostgreSQL 16 berjalan di container Docker (`make db-up` atau `docker compose up -d postgres`).
- **Frontend & Backend**: Berjalan langsung di host OS (`make dev` atau `pnpm dev:all`).
- **Keuntungan**:
  - **Hot Module Replacement (Vite HMR) instan (<50 ms)**: setiap perubahan kode frontend maupun backend langsung tersinkronisasi tanpa lag.
  - Sangat hemat RAM (<300 MB).
  - Integrasi LSP, typechecking, dan autocomplete IDE bekerja optimal secara native.

#### Mode B: Full Docker Mode (Untuk QA, Reviewer, atau Deployment Server)
- Menjalankan seluruh stack (`postgres`, `gateway`, dan `frontend`) terisolasi di dalam container Docker:
  ```bash
  make docker-up
  # atau manual: docker compose up -d --build
  ```
- **Catatan Penting Sinkronisasi Kode**:
  Karena `Dockerfile.backend` dan `Dockerfile.frontend` menyalin (*COPY*) berkas kode sumber ke dalam image saat build time (tanpa host volume bind mount di `docker-compose.yml`), **perubahan kode di host tidak otomatis tersinkronisasi ke dalam kontainer yang sedang berjalan**. Setiap perubahan kode di tengah jalan memerlukan proses rebuild:
  ```bash
  docker compose up -d --build
  # atau hentikan dan nyalakan ulang:
  make docker-down && make docker-up
  ```

---

### 3. Prasyarat & Instalasi Toolchain

Sebelum memulai, pastikan perangkat Anda telah terpasang:

1. **Node.js (v22 LTS)**:
   - Unduh dari situs resmi [nodejs.org](https://nodejs.org/) (pilih versi 22 LTS), atau pasang lewat version manager seperti `nvm` / `fnm`.
   - Verifikasi: `node -v` (harus `v22.x.x`).

2. **pnpm (Package Manager Frontend)**:
   - Versi pnpm dipatok di `package.json` (`packageManager: pnpm@10.18.3`). Corepack memakai nilai itu secara otomatis:
     ```bash
     corepack enable pnpm
     ```
   - Atau via npm global (pasang versi yang sama dengan pin):
     ```bash
     npm install -g pnpm@10.18.3
     ```
   - Verifikasi: `pnpm -v` (harus `10.18.3`). Jangan mendeklarasikan versi pnpm di tempat lain (mis. input `version` pada `pnpm/action-setup` di CI); dua nilai yang berbeda membuat action gagal.

3. **Python (v3.10+, direkomendasikan 3.12 sesuai CI) & Astral UV (Package Manager Backend)**:
   - **Python:** Unduh dari [python.org](https://www.python.org/) atau via package manager bawaan OS.
   - **Astral UV** (pengelola virtual environment & paket Python super cepat):
     - *Linux & macOS:*
       ```bash
       curl -LsSf https://astral.sh/uv/install.sh | sh
       ```
     - *Windows (PowerShell):*
       ```powershell
       powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
       ```
     - *Atau via pip / winget:*
       ```bash
       pip install uv
       # atau di Windows:
       winget install astral-sh.uv
       ```
     - Verifikasi: `uv --version`.

4. **Docker Engine & Docker Compose**:
   - Pastikan Docker Daemon aktif untuk PostgreSQL lokal (`make db-up`) atau full stack container (`make docker-up`).

5. **Ollama (Opsional — untuk LLM Lokal)**:
   - Unduh installer dari [ollama.com](https://ollama.com).
   - Model rekomendasi: `ollama run qwen2.5:3b-instruct` (ringan, ~2 GB) atau `ollama run qwen2.5:7b-instruct`.
   - *(Jika Ollama tidak aktif, backend otomatis menggunakan fallback slot-filling deterministik sehingga aplikasi tetap berjalan lancar).*

6. **AI Chatbot Microservice (Opsional — untuk Inferensi Hybrid RAG-CAG Penuh)**:
   - Microservice AI berjalan di repositori sibling `ftmm-compass-chatbot`:
     ```bash
     cd ../ftmm-compass-chatbot
     # Ingest index kurikulum FAISS (hanya sekali di awal)
     uv run python scripts/ingest_faiss.py
     # Jalankan kontainer Docker
     docker compose up -d
     ```
   - Microservice akan aktif di `http://localhost:8000` dan terhubung langsung ke Ollama host.
   - *(Jika kontainer Docker tidak diaktifkan, Backend Gateway otomatis beralih ke agen slot-filling lokal sehingga seluruh fitur aplikasi tetap 100% berfungsi tanpa kendala).*

---

### 4. Menjalankan Manual (Alternatif Tanpa `Makefile`)

#### A. Menjalankan Sekaligus (Frontend + Backend)
Jalankan perintah berikut untuk mengaktifkan frontend dan backend secara bersamaan lintas OS (Linux, macOS, Windows):

```bash
# 1. Install dependencies frontend
pnpm install

# 2. Sinkronisasi dependencies backend (otomatis membuat venv via uv)
uv sync --directory backend

# 3. Jalankan database PostgreSQL di Docker
docker compose up -d postgres

# 4. Jalankan frontend + backend bersamaan
pnpm dev:all
```

- **Cross-Platform**: Menggunakan `concurrently` yang mendukung signal terminate (Ctrl+C) bersih di Linux maupun Windows.
- **Dynamic Port Auto-Discovery**: Backend memindai port kosong pada rentang 8001–8050 (port 8000 disediakan untuk microservice chatbot) dan menuliskan port aktif ke `.backend-port`. Vite dev proxy membaca berkas itu dan meneruskan request `/api` ke port tersebut.
- Buka **`http://localhost:8443`** di browser. Login memakai akun hasil seeding: `mahasiswa.testing@ftmm.unair.ac.id` / `Mahasiswa2026!` (student), `dosen.testing@ftmm.unair.ac.id` / `DosenFTMM2026!` (lecturer), atau `admin@ftmm.unair.ac.id` / `AdminFTMM2026!` (admin). Identifier menerima NIM, NIP, maupun email.
- Database harus sudah di-migrate dan di-seed (`make db-up && make migrate && make seed`), karena kredensial dan katalog dibaca dari PostgreSQL, bukan dari data statis frontend.

#### B. Menjalankan Terpisah (2 Tab Terminal)
Jika Anda lebih menyukai tab terminal terpisah untuk memantau log masing-masing service:

- **Terminal 1 — Backend FastAPI**:
  ```bash
  pnpm dev:backend
  # atau manual:
  uv run --directory backend python app.py
  ```
  Backend aktif di `http://localhost:<PORT>` (Swagger interactive docs di `/docs`).

- **Terminal 2 — Frontend Vite**:
  ```bash
  pnpm dev
  ```
  Vite aktif di `http://localhost:8443`.

*(Opsional)* Jalankan model LLM lokal di terminal terpisah:
```bash
ollama run qwen2.5:3b-instruct
# atau model lebih besar:
ollama run qwen2.5:7b-instruct
```

---

### 5. Pengujian Remote Chatbot via Cloudflare Tunnel (Tanpa Backend/LLM Lokal)

Jika rekan tim atau tester ingin menguji respons dan streaming Chatbot AI tanpa perlu menginstal backend FastAPI atau model Ollama lokal:

1. Salin template `.env.example` ke `.env`:
   ```bash
   cp .env.example .env
   ```
2. Masukkan base URL Cloudflare Tunnel yang dibagikan tim backend ke `VITE_API_BASE`:
   ```bash
   VITE_API_BASE=https://<subdomain>.trycloudflare.com
   ```
   *(Kosongkan bila backend berjalan lokal; request `/api` otomatis lewat proxy Vite. Nilai ini hanya base URL, tanpa akhiran endpoint.)*
3. Jalankan frontend:
   ```bash
   pnpm dev
   ```
4. Akses halaman **Compass AI** di `http://localhost:8443`. Indikator status di header otomatis menyala hijau (**Live • `<model>`**), menandakan koneksi langsung ke remote backend tunnel berhasil.

---

### 6. Menjalankan via Docker Compose (Multi-Container `ftmm-network`)

Untuk deployment terisolasi berbasis kontainer atau setup di server/VPS baru:

#### A. Inisialisasi Jaringan Host (Hanya 1x di Server/Host Baru)
```bash
# 1. Buat bridge network bersama untuk komunikasi inter-kontainer
docker network create ftmm-network 2>/dev/null || true

# 2. Jika Ollama berjalan di host dengan firewall UFW aktif (misal Ubuntu/WSL2):
sudo ufw allow 11434/tcp
```

#### B. Menjalankan Layanan Kontainer
```bash
# 1. Jalankan Chatbot Microservice (port 8000)
cd ../ftmm-compass-chatbot && docker compose up -d

# 2. Jalankan Gateway (port 8001) dan Frontend UI (port 8443)
cd ../ftmm-compass-ui && docker compose up -d
```

#### C. Verifikasi Konektivitas
- **Frontend Web UI**: `http://localhost:8443`
- **Gateway Health**: `curl -s http://localhost:8001/api/v1/health | jq .` (memverifikasi status `chatbot_service_online: true` dan `ollama_online: true`).
- **Chatbot Direct Health**: `curl -s http://localhost:8000/api/v1/health | jq .`
- **Hentikan Seluruh Layanan**:
  ```bash
  docker compose down && docker compose -f ../ftmm-compass-chatbot/docker-compose.yml down
  ```

## Testing & QA Audit

Suite backend berjalan terhadap PostgreSQL yang sudah di-migrate. Fixture `tests/conftest.py` menanam pengguna demo sendiri, tetapi tes katalog dan degree-plan membaca katalog 5 prodi, sehingga database harus sudah dijalankan `make seed` (yang kini juga menjalankan `seed_full_catalog.py`). CI melakukan urutan yang sama: schema baseline → `alembic upgrade head` → `seed_full_catalog.py` → `pytest`.

```bash
# ----------------------------------------------------
# A. Menggunakan Makefile (Cepat & Terintegrasi)
# ----------------------------------------------------
make test          # Typecheck TypeScript + suite pytest backend
make lint          # Pemeriksaan format (oxfmt) + typecheck
make format        # Auto-format seluruh codebase via oxfmt

# ----------------------------------------------------
# B. Perintah Manual / Spesifik Sub-Sistem
# ----------------------------------------------------
# 1. Seed katalog (sekali per database baru; idempoten)
uv run --directory backend python seed_full_catalog.py

# 2. Jalankan seluruh suite backend (domain + endpoint + polling + chat + degree-plan)
uv run --directory backend python -m pytest tests -q

# 3. Jalankan build test & type check frontend
pnpm build

# 4. Verifikasi format code (oxfmt)
pnpm format:check
# atau auto-format in-place:
pnpm format
```

---

## Struktur Direktori

```
ftmm-compass-ui/
├── .github/workflows/ci.yml       # Automated CI pipeline (Node 22 + Python 3.12)
├── Makefile                       # Developer automation interface (setup, dev, db, test)
├── AI_PLANNER_PIPELINE.md         # Dokumentasi detail arsitektur Study Planner Agent
├── DESIGN.md                      # Spesifikasi sistem desain & token visual FTMM
├── Dockerfile.frontend            # Container image definition untuk React + Vite
├── Dockerfile.backend             # Multi-stage container image untuk FastAPI (uv)
├── docker-compose.yml             # Orkestrasi multi-container (ftmm-network)
├── backend/                       # Python FastAPI Backend Gateway
│   ├── README.md                  # Dokumentasi API, setup uv, & arsitektur backend
│   ├── app.py                     # Mount router (/api/v1 kanonik + /api legacy), lifespan, error handler
│   ├── settings.py                # Satu-satunya pembaca environment (DSN, port, Ollama, CORS)
│   ├── models.py                  # Pemetaan ORM SQLAlchemy (termasuk degree_plans & degree_plan_items)
│   ├── schemas.py                 # Pydantic v2 data models & payload contracts
│   ├── catalog.py                 # Pipeline katalog: baca DB → normalisasi → list/get course
│   ├── academics.py               # Batas SKS, total kredit, konversi nilai, parity
│   ├── plan_storage.py            # Persistensi degree-plan & exception domain
│   ├── course_records.py          # Transkrip mahasiswa: baca, tandai lulus, batalkan
│   ├── api/                       # Router per resource (dipasang di /api/v1 dan /api)
│   ├── migrations/                # Revisi Alembic (baseline skema + perubahan berikutnya)
│   ├── pyproject.toml             # Konfigurasi dependensi uv (Astral)
│   ├── uv.lock                    # Deterministic lockfile backend
│   ├── .env.example               # Template konfigurasi environment backend
│   ├── seed.py                    # Seed pengguna demo, transkrip, polling, notifikasi
│   ├── seed_full_catalog.py       # Seed katalog 5 prodi dari database/seed
│   ├── tools/
│   │   ├── prerequisite_validator.py  # Deterministic DAG, parity, & SKS validator
│   │   └── planner.py             # Study plan synthesis & elective scoring engine
│   └── tests/                     # Suite pytest (domain, endpoint, polling, chat, degree-plan)
├── src/                           # React 19 + TypeScript + Tailwind v4 SPA
│   ├── App.tsx                    # Shell navigasi halaman & komposisi provider state
│   ├── main.tsx                   # React DOM entrypoint
│   ├── data.ts                    # Tipe model (Course, ScheduleItem, offering) & TIMETABLE_DAYS
│   ├── courseData.ts              # fetchCatalog(): katalog dari backend, normalisasi tipe
│   ├── index.css                  # Tailwind v4 @theme design tokens (Navy, Gold, Teal)
│   ├── utils.ts                   # cn() class merger helper
│   ├── api/
│   │   ├── client.ts              # Satu transport fetch: base URL, ApiError, authHeaders
│   │   └── session.ts             # Akses token/sesi tersimpan
│   ├── domain/                    # Aturan akademik murni (tanpa React)
│   │   ├── academics.ts           # Batas SKS, konversi nilai, parity semester
│   │   ├── course.ts              # Normalisasi tipe/parity mata kuliah
│   │   ├── plan.ts                # Kontrak payload rencana studi
│   │   ├── prerequisites.ts       # Evaluasi DAG prasyarat
│   │   └── timetable.ts           # Deteksi bentrok jadwal
│   ├── state/                     # Satu pemilik state per domain
│   │   ├── session.tsx            # Sesi login & identitas pengguna
│   │   ├── catalog.tsx            # Katalog & status pemuatan
│   │   ├── polling.tsx            # Polling MK pilihan
│   │   ├── academic.tsx           # Periode akademik aktif
│   │   ├── planner.tsx            # Rencana studi aktif & jembatan ke draft
│   │   ├── degreeDrafts.ts        # Draft rencana di server: muat, simpan, salin, hapus
│   │   └── courseRecords.ts       # Transkrip: MK lulus terkunci di planner
│   ├── services/                  # Binding endpoint per resource
│   │   ├── authService.ts         # Login, profil, notifikasi
│   │   ├── dashboardService.ts    # Telemetri dashboard
│   │   ├── academicService.ts     # Periode akademik
│   │   ├── degreePlanService.ts   # CRUD degree-plan (rencana studi tersimpan)
│   │   ├── courseRecordService.ts # Transkrip MK: list, tandai lulus, batalkan
│   │   └── pollingService.ts      # Periode & vote MK pilihan
│   ├── pages/
│   │   ├── Login.tsx              # Login ke /api/v1/auth/login (JWT)
│   │   ├── Dashboard.tsx          # Statistik akademik & widget jadwal
│   │   ├── CourseFinder.tsx       # Katalog kurikulum & filter
│   │   ├── DegreePlanner.tsx      # Roadmap 8 semester drag-and-drop
│   │   ├── Chatbot.tsx            # Compass AI (SSE + fallback rule engine)
│   │   └── Profile.tsx            # Profil akademik & logout
│   └── components/
│       ├── TimetableGrid.tsx      # Grid jadwal mingguan & indikator konflik
│       ├── NotificationDropdown.tsx # Daftar notifikasi akademik
│       ├── MarkdownRenderer.tsx   # GFM markdown renderer for chat messages
│       ├── course/                # Badge, workload grid, dan modal shell bersama
│       ├── course-finder/
│       │   ├── CourseDetailView.tsx     # Detail silabus & beban kerja
│       │   ├── CourseQuickModal.tsx     # Preview cepat
│       │   └── PrerequisiteDiagram.tsx  # Visualisasi DAG prasyarat (SVG)
│       ├── degree-planner/
│       │   ├── PlannerHeader.tsx        # Banner AI, legenda, hint drag
│       │   ├── SemesterColumn.tsx       # Kolom semester, kartu MK, bank MK pilihan
│       │   ├── CoursePickerModal.tsx    # Penambahan MK manual (dibatasi kurikulum mahasiswa)
│       │   ├── CourseInspectModal.tsx   # Detail MK saat inspeksi
│       │   ├── ClassSelectorPanel.tsx   # Pemilihan kelas/section per MK
│       │   └── types.ts                 # Tipe planner & aturan parity/lock
│       └── chatbot/
│           ├── DegreePlanActionCard.tsx # Kartu penerapan rencana AI ke planner
│           └── chatService.ts           # Chat types, SSE, & error sanitizer
├── database/                      # Canonical Database Baseline V2.1 RC1
│   ├── schema_v2_1_rc1.sql        # PostgreSQL 16+ DDL (38 tables, 26 functions, 44 triggers)
│   ├── schema_v2_1_rc1.dbml       # DBML diagram definition
│   ├── seed/                      # Input seed katalog 5 prodi (canonical + reconciliation)
│   └── README.md                  # Ringkasan paket skema database
├── docs/                          # Dokumentasi teknis & onboarding
│   ├── ONBOARDING.md              # Developer Onboarding & Local Setup Guide (Makefile DX)
│   ├── plans/                     # Plan & decision log refactor (low-level, per fase)
│   └── database/                  # Dokumentasi & Audit Skema Database V2.1 RC1
│       ├── DATABASE_SCHEMA_V2_1_RC1.md    # Spesifikasi arsitektur 38 tabel & rule tree
│       ├── SCHEMA_VALIDATION_V2_1_RC1.md  # Laporan 97/97 static release audit checks
│       └── CHANGELOG_V2_TO_V2_1_RC1.md    # Catatan migrasi dari v2 ke v2.1 RC1
├── RANCANGAN DIAGRAM AWAL.sql     # Arsip baseline awal PostgreSQL 16 (v2)
└── SCHEMA_REVIEW.md               # Arsip catatan tinjauan skema v2
```

---

## Database Baseline — V2.1 RC1

`database/schema_v2_1_rc1.sql` adalah canonical baseline PostgreSQL 16+ untuk arsitektur basis data akademik FTMM (**38 tabel, 26 fungsi PL/pgSQL, 44 trigger, 2 read views**, dan lulus **97/97 static audit checks**). Dokumentasi lengkap keputusan desain tersedia di [`docs/database/DATABASE_SCHEMA_V2_1_RC1.md`](./docs/database/DATABASE_SCHEMA_V2_1_RC1.md) dan laporan validasinya di [`docs/database/SCHEMA_VALIDATION_V2_1_RC1.md`](./docs/database/SCHEMA_VALIDATION_V2_1_RC1.md).
