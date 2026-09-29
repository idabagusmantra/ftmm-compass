# FTMM Compass — Academic Advisor & Agentic Study Planner

Academic-advisor web app and AI study planner for **FTMM (Fakultas Teknologi Maju dan Multidisiplin), Universitas Airlangga**.

FTMM Compass helps students plan their degree journey across 8 semesters, explore official course catalogs, visualize prerequisite DAGs, manage weekly class timetables, and consult with **Compass AI** — an agentic study planner that personalizes course roadmaps based on student backgrounds, career interests, and strict FTMM academic constraints.

---

## System Architecture

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                           FTMM COMPASS ARCHITECTURE                            │
└────────────────────────────────────────────────────────────────────────────────┘

 ┌──────────────────────────────────────────────────────────────────────────────┐
 │                              Frontend (React 19)                             │
 │                                                                              │
 │   ┌───────────────┐   ┌────────────────┐   ┌─────────────────────────────┐   │
 │   │   Dashboard   │   │  CourseFinder  │   │        DegreePlanner        │   │
 │   │ (Stats & Sched)│  │ (Catalog & DAG)│   │ (8-Sem Roadmap & Drag/Drop) │   │
 │   └───────────────┘   └────────────────┘   └──────────────▲──────────────┘   │
 │                                                           │                  │
 │                                      [Apply AI Plan] ─────┘                  │
 │                                                           │                  │
 │                                            ┌──────────────┴──────────────┐   │
 │                                            │      Compass AI Chatbot     │   │
 │                                            │   (Interactive Action Card) │   │
 │                                            └──────────────▲──────────────┘   │
 └───────────────────────────────────────────────────────────┼──────────────────┘
                                                             │
                                                     REST API (Port 8000)
                                                             │
 ┌───────────────────────────────────────────────────────────▼──────────────────┐
 │                          Backend Service (FastAPI)                           │
 │                                                                              │
 │   ┌──────────────────────────────────────────────────────────────────────┐   │
 │   │               Agent Controller & Slot-Filling Engine                 │   │
 │   │        (Anti-Assumption Guardrails + Multi-turn Intent Parsing)      │   │
 │   └───────────────────┬───────────────────────────────┬──────────────────┘   │
 │                       │                               │                      │
 │                       ▼                               ▼                      │
 │        ┌─────────────────────────────┐ ┌───────────────────────────────┐     │
 │        │  Deterministic Tools Layer  │ │     Local LLM Integration     │     │
 │        │ • Prerequisite DAG Validator│ │ • Ollama / llama.cpp          │     │
 │        │ • Semester Parity Validator │ │ • Model: qwen2.5:7b-instruct  │     │
 │        │ • Curriculum Course Loader  │ │   (or qwen2.5:3b-instruct)    │     │
 │        │ • Study Plan Synthesizer    │ └───────────────────────────────┘     │
 │        └─────────────────────────────┘                                       │
 └──────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Features

### 1. Dashboard
- Ringkasan statistik akademik: SKS Kumulatif, Semester Aktif, dan IPK.
- Widget jadwal mingguan interaktif (*Timetable*) dengan deteksi bentrok jadwal (*conflict highlighting*).

### 2. Course Finder
- Pencarian dan filter katalog mata kuliah berdasarkan prodi, semester, SKS, dan tipe (Wajib/Pilihan).
- Modal detail mata kuliah dilengkapi **Prerequisite Flow Diagram (SVG)** untuk melihat rantai mata kuliah prasyarat.

### 3. Degree Planner
- Papan visual rencana studi 8 semester (*Roadmap*):
  - Mata kuliah **Wajib** otomatis terkunci di semesternya.
  - Mata kuliah **Pilihan** dapat dipindah-pindah via *drag and drop*.
  - Menegakkan aturan paritas semester (**Ganjil/Odd** $\rightarrow$ Semester 1, 3, 5, 7; **Genap/Even** $\rightarrow$ Semester 2, 4, 6, 8).
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

### Backend
- **Python 3.10+** (managed via **[Astral UV](https://docs.astral.sh/uv/)**)
- **FastAPI** + **Uvicorn** (RESTful API & CORS)
- **Pydantic v2** (Strict data validation schemas)
- **HTTPX** (Asynchronous HTTP client for Ollama LLM)
- **Ollama / llama.cpp** (Local LLM inference: `qwen2.5:7b-instruct` / `qwen2.5:3b-instruct`)
---

## Cara Menjalankan Project

### 1. Prasyarat & Instalasi Tools

Sebelum memulai, pastikan perangkat Anda telah terpasang:

1. **Node.js (v22 LTS)**:
   - Unduh dari situs resmi [nodejs.org](https://nodejs.org/) (pilih versi 22 LTS), atau pasang lewat version manager seperti `nvm` / `fnm`.
   - Verifikasi: `node -v` (harus `v22.x.x`).

2. **pnpm (Package Manager Frontend)**:
   - Melalui Corepack (bawaan Node.js):
     ```bash
     corepack enable pnpm
     ```
   - Atau via npm global:
     ```bash
     npm install -g pnpm
     ```
   - Verifikasi: `pnpm -v`.

3. **Python (v3.10+) & Astral UV (Package Manager Backend)**:
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

4. **Ollama (Opsional — untuk LLM Lokal)**:
   - Unduh installer dari [ollama.com](https://ollama.com).
   - Model rekomendasi: `ollama run qwen2.5:3b-instruct` (ringan, ~2 GB) atau `ollama run qwen2.5:7b-instruct`.
   - *(Jika Ollama tidak aktif, backend otomatis menggunakan fallback slot-filling deterministik sehingga aplikasi tetap berjalan lancar).*

---

### 2. Menjalankan Sekaligus (Frontend + Backend — Rekomendasi)

Jalankan perintah berikut untuk mengaktifkan frontend dan backend secara bersamaan lintas OS (Linux, macOS, Windows):

```bash
# 1. Install dependencies frontend
pnpm install

# 2. Sinkronisasi dependencies backend (otomatis membuat venv via uv)
uv sync --directory backend

# 3. Jalankan frontend + backend bersamaan
pnpm dev:all
```

- **Cross-Platform**: Menggunakan `concurrently` yang mendukung signal terminate (Ctrl+C) bersih di Linux maupun Windows.
- **Dynamic Port Auto-Discovery**: Backend otomatis memindai port kosong (mulai dari 8000 $\rightarrow$ 8001, dst. jika port 8000 sedang dipakai proses lain). Vite dev proxy secara dinamis membaca port aktif dan meneruskan request `/api`.
- Buka **`http://localhost:8443`** di browser. Login dengan NIM dan password apa saja (simulasi autentikasi).

---

### 3. Menjalankan Terpisah (2 Tab Terminal)

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

## Testing & QA Audit

Proyek ini dilengkapi rangkaian pengujian otomatis untuk memvalidasi fungsi backend dan integritas tipe frontend:

```bash
# 1. Jalankan unit test logic planner, validator, dan slot-filling agent
uv run --directory backend python test_backend.py

# 2. Jalankan integration test endpoint FastAPI
uv run --directory backend python test_api_endpoints.py

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
├── .github/workflows/ci.yml       # Automated CI pipeline (Node 22 + Python 3.11)
├── AI_PLANNER_PIPELINE.md         # Dokumentasi detail arsitektur Study Planner Agent
├── backend/                       # Python FastAPI Backend
│   ├── README.md                  # Dokumentasi API, setup uv, & arsitektur backend
│   ├── app.py                     # API server & endpoint routes (/api/chat, /api/courses, etc.)
│   ├── agent.py                   # Slot-filling conversational agent & Ollama controller
│   ├── schemas.py                 # Pydantic data models & payload contracts
│   ├── data_loader.py             # Loader kurikulum resmi FTMM & pemetaan prasyarat
│   ├── pyproject.toml             # Konfigurasi dependensi uv (Astral)
│   ├── uv.lock                    # Deterministic lockfile backend
│   ├── requirements.txt           # Export dependensi pip standar
│   ├── .env.example               # Template konfigurasi environment backend
│   ├── tools/
│   │   ├── prerequisite_validator.py  # Deterministic DAG, parity, & SKS validator
│   │   └── planner.py             # Study plan synthesis & elective scoring engine
│   ├── test_backend.py            # Unit tests for tools & agent dialog
│   └── test_api_endpoints.py      # Integration tests for FastAPI endpoints
├── src/                           # React Frontend
│   ├── App.tsx                    # Top-level state & planner payload wiring
│   ├── main.tsx                   # React DOM entrypoint
│   ├── data.ts                    # Core TypeScript models & mock schedules
│   ├── courseData.ts              # Catalog normalizer
│   ├── index.css                  # Tailwind v4 @theme design tokens
│   ├── utils.ts                   # cn() helper
│   ├── pages/
│   │   ├── Login.tsx              # Simulated authentication page
│   │   ├── Dashboard.tsx          # Academic stats & weekly timetable
│   │   ├── CourseFinder.tsx       # Course search & SVG prerequisite diagram
│   │   ├── DegreePlanner.tsx      # Interactive 8-semester roadmap
│   │   └── Chatbot.tsx            # Compass AI UI with interactive Action Cards
│   └── components/
│       └── TimetableGrid.tsx      # Weekly timetable grid component
├── RANCANGAN DIAGRAM AWAL.sql     # PostgreSQL 16 baseline schema
└── SCHEMA_REVIEW.md               # Database decision records
```

---

## Database Baseline — v2

`RANCANGAN DIAGRAM AWAL.sql` adalah baseline PostgreSQL 16 untuk arsitektur basis data akademik FTMM masa depan. Dokumen tinjauan keputusan database dapat dibaca di [`SCHEMA_REVIEW.md`](./SCHEMA_REVIEW.md).
