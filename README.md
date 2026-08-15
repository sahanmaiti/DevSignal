<div align="center">

# DevSignal

**An AI-powered iOS internship radar — discovers opportunities across 13+ platforms, scores them with a custom LLM, generates personalized recruiter outreach, and delivers everything to a native iOS app. Runs autonomously every 12 hours at zero cost.**

<br>

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-006EFF?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?style=flat-square&logo=postgresql&logoColor=white)](https://postgresql.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.136-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Redis](https://img.shields.io/badge/Redis-ARQ_worker-DC382D?style=flat-square&logo=redis&logoColor=white)](https://redis.io)
[![Alembic](https://img.shields.io/badge/Alembic-migrations-4B8BBE?style=flat-square)](https://alembic.sqlalchemy.org)
[![Oracle Cloud](https://img.shields.io/badge/Oracle_Cloud-Always_Free-F80000?style=flat-square&logo=oracle&logoColor=white)](https://www.oracle.com/cloud/free/)
[![Groq](https://img.shields.io/badge/Groq-Llama_3.1-F55036?style=flat-square)](https://groq.com)
[![License](https://img.shields.io/badge/License-MIT-22c55e?style=flat-square)](LICENSE)

<br>

> _Built by a CS student who got tired of manually refreshing LinkedIn._

</div>

---

## The Problem

Searching for iOS internships is repetitive, noisy, and punishingly manual. For a CS student actively building with Swift and SwiftUI, doing this properly means:

- Checking 15+ platforms every day for new postings
- Most "iOS intern" listings require 3+ years of experience or don't even use Swift
- Recruiter contact details are scattered across LinkedIn, company websites, and job descriptions
- By the time you find a real opportunity, write a personalized message, and apply — it's already a week old and half-filled

**DevSignal solves this with a fully automated discovery-to-outreach pipeline.** It runs every 12 hours, surfaces only what matches your profile, scores every opportunity with AI, finds the recruiter, writes the outreach message, and delivers a ranked digest to your phone — while you're in class or asleep.

DevSignal is a **single native client** product: a self-hosted FastAPI backend on Oracle Cloud, and a SwiftUI iOS app that talks to it directly. There is no web dashboard.

---

## What It Does

| Stage              | What happens                                                                                             |
| ------------------ | ----------------------------------------------------------------------------------------------------------|
| **Discovery**      | Scrapes 13+ job platforms simultaneously for iOS/Swift roles                                              |
| **Parsing**        | Extracts structured fields (experience, salary, remote, visa) from raw descriptions                       |
| **Filtering**      | Drops senior roles, non-iOS positions, and anything requiring more than 2 years of experience              |
| **Deduplication**  | MD5 hash fingerprinting on `(company, role, url)` — the same job never appears twice, across any run       |
| **Classification** | Determines whether the company actually builds a native iOS product                                       |
| **AI Scoring**     | Scores each job 0–100 across a 6-factor model using Groq/Llama 3.1, with a deterministic fallback scorer   |
| **Enrichment**     | Finds recruiter names, LinkedIn profiles, and email patterns via Hunter.io + Serper for jobs scoring ≥ 50  |
| **Outreach**       | Generates a personalized recruiter message for every job scoring ≥ 45                                     |
| **Notification**   | Telegram digest on every run; APNs push planned (see [Roadmap](#roadmap))                                  |
| **Tracking**       | Full application lifecycle tracked in Postgres, atomically synced by a DB trigger, surfaced in the iOS Kanban board |
| **iOS App**        | Native SwiftUI app: browse jobs, copy outreach, track applications, view analytics, all with offline caching |

---

## Features

**Multi-Source Job Discovery**
Scrapes RemoteOK, HackerNews "Who is Hiring", YC WorkAtAStartup, Remotive, Arbeitnow, Himalayas, WeWorkRemotely, Startup.jobs, Google Jobs (Serper), Adzuna, Arc.dev, Cutshort, Naukri, IndieHackers, and Product Hunt across three tiers — free public APIs, API-keyed sources, and best-effort HTML scraping. Every scraper inherits from a common `BaseScraper` abstract class that enforces a consistent `fetch_jobs → normalize → hash → run` interface, so adding a new source means implementing one method.

**6-Factor AI Opportunity Scoring**
Every job is evaluated by Llama 3.1 8B (via Groq's free inference API) against a structured scoring rubric with explicit, discrete point values:

| Factor               | Points        | What it checks                                                |
| --------------------- | ------------- | --------------------------------------------------------------|
| iOS relevance         | 0, 15, or 30  | Swift/SwiftUI explicitly mentioned + confirmed native iOS app  |
| Remote                | 0 or 20       | Remote/WFH/distributed explicitly confirmed                    |
| Experience match      | 0, 10, or 20  | Intern/0–1yr vs. 1–2yr vs. 3+ years required                   |
| Product/company quality | 0, 8, or 15 | YC/funded startup with a real iOS product vs. unclear/agency    |
| Salary mentioned      | 0 or 10       | Any concrete compensation figure stated                        |
| Visa sponsorship      | 0 or 5        | Sponsorship explicitly available                                |

The model returns a structured JSON breakdown explaining each factor, not just a number. On a Groq outage or exhausted retries, a rule-based fallback scorer keeps the pipeline moving rather than skipping the job. Outreach threshold is calibrated to real-world data (45, not the more obvious 65) — HackerNews posts, DevSignal's strongest job source, typically cap around 60 because they rarely state salary or visa terms explicitly.

**iOS Product Classifier**
A two-stage classifier first applies heuristic rules (if "swiftui" appears in the description, it's iOS — no API call needed), then falls back to Groq for ambiguous cases, cutting Groq usage substantially on obvious matches.

**Personalized Recruiter Outreach**
For jobs scoring ≥ 45, the system generates a LinkedIn-ready connection message that references the company's specific iOS product, mentions real shipped projects, and stays under 300 characters. Temperature is raised slightly above the scoring calls to add natural variation — no two messages read identically.

**3-Layer Recruiter Enrichment**
Every free-tier resource is spent intentionally, gated by score:

- **Layer 1** — Extract email addresses directly from job description text. Free, instant, no quota.
- **Layer 2** — Hunter.io domain search for email patterns and named contacts, reserved for jobs scoring ≥ 50. Results are cached locally so the same domain is never queried twice.
- **Layer 3** — Google search via Serper.dev to find LinkedIn profile URLs without touching LinkedIn's scraping-blocked surface directly.
- **Layer 4** — Groq fallback suggesting the most likely recruiter title when nothing else is found.

**Async FastAPI Backend with Redis-Backed Job Queue**
`api/main.py` is the single backend server. `POST /run-pipeline` enqueues a singleton ARQ job on Redis rather than blocking the request thread — `api/worker.py` runs as its own long-lived process and executes the pipeline out of band, with `GET /pipeline/status/{job_id}` for polling. If Redis is unreachable, the endpoint degrades to a `subprocess.Popen` fallback rather than failing outright. All hot-path database calls in the async API layer go through `storage/async_db.py`, which wraps the synchronous, connection-pooled `DBClient` in `asyncio.to_thread()` so the event loop is never blocked by psycopg2.

**Authentication**
Three coexisting auth modes, resolved by `api/middleware.py` in strict priority order: a static `X-API-Key` for the shipped iOS app and the pipeline scheduler, per-user `ds_...` API keys (SHA-256 hashed at rest, looked up per request), and JWT bearer tokens for `/auth`-issued sessions. `hmac.compare_digest` is used for the static-key comparison to avoid timing attacks.

**Native iOS App (SwiftUI)**
A full 5-tab iOS app that consumes the FastAPI layer over async/await `URLSession`, with a hardcoded production endpoint (no onboarding screen — the app is zero-config on first launch) and a SwiftData-backed offline cache for returning users. See [iOS App](#ios-app) below.

**Alembic-Managed Schema**
`storage/schema.sql` is the authoritative fresh-install schema; **Alembic is the sole migration mechanism going forward**. The historical `storage/migrations.py`, `migrate_v2.py`, and `migrate_v3.py` scripts are retired and kept only for reference — they must not be run against a schema that already has Alembic-applied revisions.

**Zero-Cost Architecture**
Every service runs on a free tier, and the only paid resource is a domain name.

| Service            | Free tier                | Usage                              |
| ------------------- | ------------------------- | -----------------------------------|
| Groq                | Generous daily free quota | Scoring, classification, outreach  |
| Hunter.io           | 25 domain searches/month  | Email enrichment                    |
| Serper.dev          | Free-tier searches        | LinkedIn profile finding + Google Jobs |
| Oracle Cloud        | Always Free Ampere A1 VM  | Full production host                |
| Let's Encrypt       | Free                      | HTTPS via Certbot                   |
| Xcode + Simulator   | Free                      | iOS app development                 |

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                  systemd timer  (every 12h)                          │
│                  POST /run-pipeline  →  enqueues ARQ job              │
│                             │                                         │
│                   FastAPI Server  :8000  (api/main.py)                │
│         Auth middleware (static key / per-user key / JWT)             │
│         behind Nginx (reverse proxy + HTTPS via Certbot)               │
└────────────────────────────┬───────────────────────────────────────────┘
                             │
             ┌───────────────▼────────────────┐
             │      ARQ Worker (api/worker.py)│
             │  scrape → parse → filter        │
             │  → deduplicate → store          │
             └───────────────┬────────────────┘
                             │
             ┌───────────────▼────────────────┐
             │           AI Layer             │
             │  Groq Llama 3.1 8B              │
             │  ios_classifier → scorer        │
             │  → outreach_generator           │
             └───────────────┬────────────────┘
                             │
             ┌───────────────▼────────────────┐
             │   PostgreSQL 16 (native, Oracle │
             │   VM) — schema managed by       │
             │   Alembic. jobs + applications  │
             │   + users + api_keys +          │
             │   device_tokens + scrape_runs   │
             └──────┬──────────────┬───────────┘
                    │              │
         ┌──────────▼────┐  ┌──────▼──────────────┐
         │  Redis (ARQ    │  │ /stats cache (5min  │
         │  queue + cache)│  │ TTL, invalidated on │
         └──────┬─────────┘  │ every pipeline run) │
                │            └──────────────────────┘
         ┌──────▼────────┐  ┌──────────────────────┐
         │  Telegram Bot │  │ iOS App (SwiftUI)     │
         │  digest alerts│  │ 5 tabs · SwiftData    │
         └───────────────┘  │ offline cache         │
                            └───────────────────────┘
```

---

## iOS App

A native SwiftUI app built as a full companion to the backend pipeline, distributed with a single shared API key compiled into the binary — DevSignal ships today as a personal tool with a zero-config launch flow, not a multi-tenant product (see [Multi-User Support](#multi-user-support-deferred)).

### Architecture

The iOS app follows **MVVM** with a clean layered architecture:

```
iOS App
├── Core/
│   ├── AppConfig.swift            — Compiled-in production URL + API key
│   ├── AppEnvironment.swift       — @Observable environment, cross-tab refresh signal
│   ├── KeychainManager.swift      — Secure credential storage (currently unused; see notes)
│   ├── AsyncSemaphore.swift       — Actor-based concurrency limiter
│   ├── Cache/
│   │   ├── JobCache.swift         — SwiftData-backed offline cache (24h TTL)
│   │   └── CacheStatus.swift      — live / cached / stale banner state
│   └── Networking/
│       ├── APIClient.swift        — async/await HTTP client, all endpoints
│       ├── APIClientProtocol.swift— protocol for dependency injection in tests
│       └── APIError.swift         — typed error enum
│
├── Models/
│   ├── Job.swift                  — Codable + custom decoder (Int/String id, "Yes"/"No" bools)
│   ├── JobPage.swift               — Paginated response envelope
│   ├── OutreachMessage.swift      — Recruiter message + contact details
│   ├── Application.swift          — Application model + ApplicationStage enum
│   ├── DashboardStats.swift       — Analytics aggregates for Swift Charts
│   └── RunPipelineResponse.swift  — Pipeline trigger response
│
├── Features/
│   ├── Home/                      — Stats cards, top picks feed, manual pipeline trigger
│   ├── Discover/                  — Paginated job list, filter sheet, infinite scroll
│   ├── Outreach/                  — Batch-loaded, expandable cards, inline edit, clipboard copy
│   ├── Tracker/                   — Full-height Kanban board, optimistic stage moves
│   └── Analytics/                 — Swift Charts: score distribution, funnel, top sources
│
├── Onboarding/
│   └── OnboardingView.swift       — Present but currently unreachable (see notes)
│
├── Settings/
│   └── SettingsView.swift         — Connection status, app info
│
└── Shared/Components/             — ScoreBadge, CompanyAvatar, PillBadge, StatCard, AttributeRow
```

### Screens

| Tab           | What it shows                                                                                                                                                                                                 |
| -------------- | -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Home**       | Greeting, real-time KPI cards (total jobs, applied, score ≥ 70), top 5 picks today, one-tap manual pipeline trigger with live status polling                                                                 |
| **Discover**   | Full paginated job list with score badges, remote/visa pills, filter sheet, pull-to-refresh, infinite scroll. Tap → `JobDetailView` with an animated score-breakdown bar chart and an apply button           |
| **Outreach**   | All pre-generated recruiter messages for jobs scoring ≥ 45, loaded in two HTTP calls total (job list + batch outreach fetch — see [Engineering Highlights](#engineering-highlights)). Expandable cards, editable message with a 300-char counter, copy-to-clipboard |
| **Tracker**    | Full-height Kanban board across six stages: Applied → Waiting → Replied → Interview → Offer → Rejected. Tap a card for the stage-mover grid + notes editor. Optimistic UI updates with server-confirmed rollback |
| **Analytics**  | Swift Charts bar chart (score distribution), horizontal funnel bars (Total → Score ≥ 70 → Applied → Interviewed), top-sources table by average score, pipeline last-run status                               |

### Key Engineering Decisions

**Zero-config launch, not user-configurable**
`DevSignalApp.swift` routes straight to `MainTabView` — there is no onboarding gate. `AppConfig.swift` compiles in a fixed production URL and API key, matching the single-shared-dataset model the app currently ships as. `OnboardingView.swift` and `KeychainManager.swift` remain in the codebase as a ready-made foundation for a future per-user login flow, but neither is on the active code path today; don't assume they run.

**Optimistic Updates in the Tracker**
When a user moves a Kanban card, the UI updates instantly via a local `stageOverrides` dictionary. The `PATCH` request fires in the background; on success the override is cleared and the server value takes over, on failure it reverts. No spinner on stage moves — it feels instant.

**Batched Outreach Fetching**
`GET /jobs/outreach?ids=1,2,3,...` returns outreach content for up to 50 jobs in a single request, keyed by job ID. `OutreachViewModel` fetches the qualifying job list once and the outreach batch once — two total requests to populate the entire tab, regardless of how many jobs have outreach content.

**Type-safe JSON Decoding Across a Legacy Schema**
The database stores booleans as `"Yes"/"No"/"Unknown"` strings and primary keys as integers. Custom `init(from:)` decoders on `Job` and `Application` handle both transparently — Swift code always sees `Bool` and `String` regardless of what the row actually contains, with no backend changes required to normalize it.

**Offline-First with SwiftData**
Every successful `/jobs` and `/stats` response is written to a local SwiftData store. On a network failure, `DiscoverViewModel` and `HomeViewModel` fall back to the cache and surface a `live` / `cached` / `stale` banner (`CacheStatus.swift`) rather than showing a bare error screen.

**GeometryReader for Full-Height Kanban**
Each Kanban column is sized using `GeometryReader` measuring the available screen height, then passed down as `availableHeight` to `StageColumn` — columns always fill the screen regardless of card count.

---

## Tech Stack

| Layer               | Technology                                              | Purpose                                     |
| -------------------- | ---------------------------------------------------------| ---------------------------------------------|
| **iOS App**          | SwiftUI 5, Swift 5.9, Swift Charts, Combine, SwiftData    | Native iOS client + offline cache            |
| **iOS Networking**   | URLSession async/await, Codable                           | HTTP client + JSON decoding                  |
| **iOS Storage**      | iOS Keychain, SwiftData                                   | Credential storage (dormant) + offline cache |
| **API Server**       | FastAPI, Uvicorn, slowapi                                 | REST API, rate limiting, pipeline trigger    |
| **Auth**             | python-jose (JWT), passlib/bcrypt, HMAC API keys          | Static key / per-user key / JWT bearer       |
| **Background Jobs**  | ARQ, Redis                                                 | Async pipeline execution, singleton job locking |
| **Scraping**         | Python 3.12, requests, BeautifulSoup4, feedparser, Playwright | Multi-source job collection             |
| **Processing**       | Regex-based field extraction                              | Experience/salary/remote/visa parsing, filtering |
| **AI / LLM**         | Groq API (Llama 3.1 8B)                                    | Scoring, classification, outreach generation |
| **Database**         | PostgreSQL 16, psycopg2 (pooled), SQLAlchemy (Alembic only) | Primary data store                        |
| **Migrations**       | Alembic                                                    | Sole schema migration mechanism going forward |
| **Caching**          | Redis (async, `redis.asyncio`)                             | `/stats` response cache, ARQ backing store  |
| **Automation**       | systemd timer → `POST /run-pipeline`                       | 12h scheduler (n8n retired — see below)     |
| **Enrichment**       | Hunter.io API, Serper.dev API                              | Recruiter contacts + LinkedIn profiles      |
| **Notifications**    | Telegram Bot API                                           | Mobile digest (APNs planned)                |
| **Infrastructure**   | Oracle Cloud Always Free (Ampere A1), Ubuntu LTS, Nginx, Certbot, systemd | Production hosting            |
| **Local Dev**        | Docker Compose (Postgres + Redis)                          | Containerised local dependencies            |
| **Testing**          | pytest, unittest.mock                                      | Backend unit tests, zero real API calls      |

---

## Getting Started

### Prerequisites

- macOS (Apple Silicon) or Linux — for the backend
- Python 3.12+
- Docker Desktop (for local Postgres + Redis)
- Xcode 15+ — for the iOS app
- A free [Groq API key](https://console.groq.com) — no credit card required

### Backend Setup

```bash
# Clone the repository
git clone https://github.com/sahanmaiti/devsignal.git
cd devsignal

# Create and activate a virtual environment
python3.12 -m venv venv
source venv/bin/activate

# Install all dependencies
pip install -r requirements.txt

# Copy the environment template and fill in credentials
cp .env.example .env
# Required at minimum: DATABASE_URL, GROQ_API_KEY, PIPELINE_API_KEY, JWT_SECRET, REDIS_URL

# Start PostgreSQL + Redis locally
docker compose up -d

# Apply the schema — Alembic is the sole migration mechanism
alembic upgrade head

# Run the full pipeline once to populate data
python run_scraper.py
python run_scorer.py
python run_enricher.py

# Start the FastAPI server
uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload

# In a second terminal, start the background worker
arq api.worker.WorkerSettings
```

> **Fresh database note:** `alembic/versions/0001_...` assumes a pre-existing `opportunities` table (it renames it to `jobs`). On a brand-new database there is nothing to rename — apply `storage/schema.sql` directly instead, then run `alembic stamp head` so future migrations apply cleanly on top of it.

### iOS App Setup

```bash
open iOS/DevSignal/DevSignal.xcodeproj
```

1. Set `AppConfig.productionURL` and `AppConfig.apiKey` in `Core/AppConfig.swift.swift` to your local server (`http://127.0.0.1:8000` for the Simulator, your Mac's LAN IP for a physical device) and your `PIPELINE_API_KEY`.
2. Select a simulator (iPhone 16 or later recommended).
3. Press `⌘R` to build and run — the app launches directly into the main tab bar, no setup screen.

### Enable Automation

In production, a systemd timer calls `POST /run-pipeline` directly every 12 hours — see [Deployment](#deployment) below. There is no n8n dependency in the current architecture.

---

## Deployment

Production target: a single Oracle Cloud **Always Free** Ampere A1 VM running Ubuntu LTS.

- **Database & cache**: PostgreSQL and Redis installed natively on the VM (lower memory overhead than Docker on free-tier hardware, simpler backups).
- **Application**: `devsignal-api.service` (`uvicorn api.main:app`) and `devsignal-worker.service` (`arq api.worker.WorkerSettings`) run as systemd units with automatic restart.
- **Scheduling**: a systemd timer calls `POST /run-pipeline` every 12 hours. n8n has been fully removed from the production path — `api/pipeline_server.py`, which n8n used to call, is retired in favor of `api/main.py` as the single backend server.
- **Reverse proxy & TLS**: Nginx terminates HTTPS via Certbot/Let's Encrypt and proxies to the FastAPI app on `127.0.0.1:8000`.
- **Backups**: scheduled `pg_dump` with a rolling retention window, restored and verified periodically.
- **Firewall**: only SSH, HTTP, and HTTPS are exposed; Postgres, Redis, and the app port are reachable only from `localhost`.

For the full step-by-step provisioning checklist, see `DevSignal-Roadmap.md` (Phase 2).

---

## Environment Variables

```bash
# ── Database ───────────────────────────────────────────────────────────────
DATABASE_URL=postgresql://radar:radar_pass@localhost:5433/devsignal

# ── Redis (ARQ worker + /stats cache) ─────────────────────────────────────
REDIS_URL=redis://localhost:6379/0

# ── AI Scoring ─────────────────────────────────────────────────────────────
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxx

# ── Telegram Notifications ─────────────────────────────────────────────────
TELEGRAM_BOT_TOKEN=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_CHAT_ID=xxxxxxxxxx

# ── Recruiter Enrichment ───────────────────────────────────────────────────
HUNTER_API_KEY=xxxxxxxxxxxxxxxx
SERPER_API_KEY=xxxxxxxxxxxxxxxx
ADZUNA_APP_ID=xxxxxxxx
ADZUNA_APP_KEY=xxxxxxxxxxxxxxxx

# ── Auth ────────────────────────────────────────────────────────────────────
PIPELINE_API_KEY=your-static-pipeline-key       # shared key: iOS app + scheduler
JWT_SECRET=a-fixed-persistent-secret            # never leave unset in any long-lived env
JWT_EXPIRE_MINUTES=60

# ── App environment ─────────────────────────────────────────────────────────
APP_ENV=production                              # "development" disables prod CORS/docs lockdown
ALLOWED_ORIGINS=https://your-domain.com         # required when APP_ENV=production
```

> `JWT_SECRET` falls back to a fresh random value generated at process start if unset — harmless for a single throwaway local session, but it silently invalidates every issued JWT on every restart if left unset anywhere persistent. Always set it explicitly outside of local scratch dev.

---

## API Endpoints

`api/main.py` is the **only** backend server — `api/pipeline_server.py` is retired. Every route except `/health`, `/n8n-ping`, `/auth/register`, `/auth/login`, and `/devices` requires authentication via `X-API-Key` or a JWT `Authorization: Bearer` header.

| Method  | Endpoint                | Purpose                                               |
| ------- | ------------------------ | -------------------------------------------------------|
| `GET`   | `/health`                | Server liveness check (public)                         |
| `POST`  | `/auth/register`         | Create a user account, returns a JWT                    |
| `POST`  | `/auth/login`             | Exchange credentials for a JWT                          |
| `GET`   | `/auth/me`                | Current authenticated user                               |
| `POST`  | `/auth/api-keys`          | Issue a new per-user `ds_...` API key                    |
| `GET`   | `/auth/api-keys`          | List active API keys                                     |
| `DELETE`| `/auth/api-keys/{id}`     | Revoke an API key                                        |
| `GET`   | `/jobs`                   | Paginated job list with score/remote/visa/source filters |
| `GET`   | `/jobs/outreach`          | Batch outreach fetch for up to 50 job IDs at once         |
| `GET`   | `/jobs/{id}`              | Single job detail + score breakdown                       |
| `GET`   | `/jobs/{id}/outreach`     | Recruiter message + contact info for one job              |
| `POST`  | `/jobs/{id}/apply`        | Record/update an application stage                        |
| `GET`   | `/applications`           | All tracked applications, joined with job data             |
| `PATCH` | `/applications/{id}`      | Update an application's stage or notes                     |
| `GET`   | `/stats`                  | Aggregated pipeline analytics (Redis-cached, 5min TTL)      |
| `POST`  | `/devices`                | Register an iOS push notification token (APNs not yet wired)|
| `POST`  | `/run-pipeline`           | Enqueue a full pipeline run (rate-limited, ARQ singleton)   |
| `GET`   | `/pipeline/status/{job_id}` | Poll the status of an enqueued pipeline run               |

---

## Project Structure

```
devsignal/
│
├── iOS/DevSignal/                # Native iOS app (SwiftUI)
│   ├── DevSignal/DevSignalApp.swift  # Entry point — routes straight to MainTabView
│   ├── MainTabView.swift             # 5-tab root view
│   ├── Core/
│   │   ├── AppConfig.swift.swift     # Compiled-in production URL + API key
│   │   ├── AppEnvironment.swift
│   │   ├── KeychainManager.swift     # Present, currently dormant
│   │   ├── AsyncSemaphore.swift
│   │   ├── Cache/                    # JobCache (SwiftData), CacheStatus
│   │   └── Networking/               # APIClient, APIClientProtocol, APIError
│   ├── Models/
│   ├── Features/
│   │   ├── Home/
│   │   ├── Discover/
│   │   ├── Outreach/
│   │   ├── Tracker/
│   │   └── Analytics/
│   ├── Onboarding/                   # Present, currently unreachable
│   ├── Settings/
│   ├── Shared/Components/
│   └── tests/                        # MockAPIClient for future XCTest coverage
│
├── scrapers/                    # One file per data source, all inheriting BaseScraper
├── processors/                  # job_parser, filter_engine, deduplicator, enricher,
│                                 # domain_finder, hunter_client, linkedin_finder
├── ai/                          # ios_classifier, scorer, outreach_generator
│
├── storage/
│   ├── schema.sql                # Authoritative fresh-install schema
│   ├── db_client.py              # Sync connection-pooled client (jobs table)
│   ├── async_db.py               # asyncio.to_thread() wrapper for the FastAPI layer
│   ├── cache.py                  # Redis async cache for /stats
│   ├── migrations.py             # Historical — do not run against an Alembic-managed DB
│   ├── migrate_v2.py             # Historical
│   └── migrate_v3.py             # Historical
│
├── alembic/                     # Sole migration mechanism going forward
│   └── versions/0001_rename_to_jobs_fix_applications.py
│
├── api/
│   ├── main.py                   # The one backend server — 20 endpoints
│   ├── auth.py                   # JWT, password hashing, API key issuance/lookup
│   ├── middleware.py              # 3-mode auth resolution
│   ├── worker.py                  # ARQ task definitions + WorkerSettings
│   └── pipeline_server.py         # Retired — kept for historical reference only
│
├── notifications/
│   └── telegram_bot.py
│
├── tests/                        # pytest suite — scrapers, processors, scorer,
│                                  # notifications, enricher
│
├── config/
│   ├── settings.py
│   └── keywords.py
│
├── run_scraper.py
├── run_scorer.py
├── run_enricher.py
├── run_pipeline.sh
├── run_watchlist.py
├── docker-compose.yml            # Local dev: Postgres + Redis
├── alembic.ini
├── requirements.txt
├── .env.example
└── README.md
```

---

## Engineering Highlights

**Full-Stack System Design**
The backend and iOS app are genuinely independent layers. The iOS app knows nothing about Groq, scrapers, or Postgres — it only speaks HTTP to the FastAPI layer, authenticated with a static key baked into the binary. The FastAPI layer knows nothing about SwiftUI. Either side can evolve without touching the other, as long as the JSON contract holds.

**Async Job Queue Over a Synchronous Pipeline**
The scraping pipeline (`run_pipeline.sh`) is a synchronous, long-running shell script. Rather than blocking a FastAPI request thread for its full duration, `POST /run-pipeline` enqueues a singleton ARQ job on Redis and returns immediately; a separate `arq api.worker.WorkerSettings` process picks it up. The `_job_id="pipeline_singleton"` pattern prevents overlapping runs, and stale completed-job results are explicitly cleared before re-enqueueing so a finished run doesn't block the next one from starting.

**ETL Pipeline Design**
Raw data flows through a typed transformation chain with clear stage boundaries. Deduplication relies on the `jobs.job_hash` UNIQUE constraint plus `ON CONFLICT DO NOTHING` at insert time rather than fetching every existing hash into memory. The filter engine distinguishes "confidently exclude" (senior title in the role, a proven 3+ year requirement) from "benefit of the doubt" (experience unstated) — false negatives are treated as more expensive than a few borderline jobs reaching the scorer.

**LLM Prompt Engineering with a Deterministic Fallback**
The scoring prompt specifies exact point values per factor, the full set of valid states, and a required JSON schema. The classifier runs a heuristic pre-pass before ever calling the API — most jobs are decided by a keyword match alone. Every LLM call has fallback logic so a Groq outage degrades scoring quality rather than stopping the pipeline (see the score-breakdown-schema caveat below).

**Three-Mode Authentication, Resolved in One Place**
`api/middleware.py` is the single point where a request becomes an authenticated (or rejected) request: a static pipeline key, a hashed per-user `ds_` key, or a JWT — checked in that order, with `hmac.compare_digest` guarding the static-key comparison against timing attacks. Every downstream endpoint reads `request.state.user` rather than re-implementing auth logic.

**iOS Concurrency**
`OutreachViewModel` collapses what used to be N concurrent per-job HTTP requests into two total requests (job list + one batch outreach call), using Swift's `async`/`await` rather than a manual dispatch queue. `TrackerViewModel` performs optimistic local updates and reconciles with the server response rather than blocking the UI on every stage change.

**Database Design**
The schema uses `SMALLINT` for scores, `JSONB` for the score breakdown (queryable), `TIMESTAMPTZ` for every timestamp, and partial unique indexes on `applications` (`job_id` alone when `user_id IS NULL`, `(user_id, job_id)` otherwise) so the same table cleanly supports both today's single-user mode and a future multi-tenant mode without a schema change. A trigger (`sync_application_to_jobs`) keeps the legacy `applied` / `response_status` / `interview_stage` columns on `jobs` in sync with `applications.stage` inside the same transaction — no dual-write race condition between the two tables.

**Quota-Aware Resource Management**
Hunter.io's 25 monthly searches and Serper's search quota are both spent only on jobs scoring ≥ 50, with domain-level results cached to disk so the same company is never queried twice. The classifier's heuristic pass reduces Groq calls before they happen. Every free-tier constraint is treated as a design constraint, not an afterthought.

---

## Known Issues

These are tracked, evidenced issues — not speculative concerns — carried forward from the project's own stability audit (`DevSignal-Roadmap.md`, Phase 3).

- **Dual score-breakdown schema.** `ai/scorer.py`'s primary Groq path produces a 6-key breakdown matching what `iOS/DevSignal/Models/Job.swift`'s `ScoreBreakdown` expects. Its `_fallback_score()` — triggered on a Groq outage or exhausted retries — writes a different 8-key breakdown to the same column, which the iOS score-breakdown chart can't render meaningfully. Scheduled for a unification fix.
- **`JWT_SECRET` silent fallback.** `config/settings.py` generates a throwaway secret at process start if the environment variable is unset, silently invalidating every issued JWT on restart. Always set this explicitly outside of local scratch development.
- **`OnboardingView.swift` / `KeychainManager.swift` are present but unreachable.** `DevSignalApp.swift` routes directly to `MainTabView`. This code is a ready foundation for a future login flow, not dead weight to delete — but don't assume it currently runs.
- **`scrapers/wellfound_scraper.py` is not wired into `run_scraper.py`.** The scraper and its `playwright` dependency both exist in the repository, but no tier in the pipeline currently calls it.

---

## Roadmap

Status reflects the project's own phase-based roadmap (`DevSignal-Roadmap.md`), not aspirational planning.

- [x] **Multi-source job discovery** — 13+ platforms across three tiers
- [x] **AI scoring** — 6-factor Groq/Llama 3.1 scoring with JSON breakdown + fallback scorer
- [x] **Recruiter enrichment** — Hunter.io + Serper + description-parsing + AI-guess fallback
- [x] **Outreach generation** — Personalized LinkedIn messages for jobs scoring ≥ 45
- [x] **FastAPI REST layer** — single backend server, 20 endpoints, three auth modes
- [x] **Async job queue** — Redis + ARQ worker, singleton pipeline locking, status polling
- [x] **Alembic migrations** — sole schema-management mechanism going forward
- [x] **Native iOS app** — SwiftUI, 5 tabs, offline SwiftData cache
- [x] **iOS Kanban tracker** — optimistic updates, 6 stages, notes editor, DB-triggered sync
- [x] **iOS Analytics** — Swift Charts: score distribution, funnel, sources
- [x] **Streamlit dashboard removed** — iOS app is the only user-facing client
- [ ] **Oracle Cloud production deployment** — Nginx + systemd + Certbot, in progress
- [ ] **C1: score-breakdown schema unification** — see [Known Issues](#known-issues)
- [ ] **APNs push notifications** — blocked on an Apple Developer account
- [ ] **Backend integration test coverage** — `api/main.py`, `api/auth.py`, `api/middleware.py`
- [ ] **iOS XCTest coverage** — `MockAPIClient` exists and is ready; tests not yet written
- [ ] **Multi-tenancy** — schema is ready (`users`, `api_keys`, partial unique indexes); explicitly deferred to a post-launch v2, not part of the initial App Store release
- [ ] **App Store submission** — privacy policy, App Privacy questionnaire, production soak period

---

## Why This Matters

Most portfolio projects demonstrate that you can follow a tutorial. DevSignal demonstrates something different.

It required designing a multi-stage data pipeline under real constraints — limited API quota, changing platform structures, unreliable data quality — and making genuine product decisions: which API to call when, how to spend 25 free Hunter.io searches a month, how to move a synchronous pipeline off the request thread without introducing a race condition, how to keep two tables in sync inside one transaction instead of two. It meant writing LLM prompts that produce consistent structured output reliably, not just in a demo, and correctly responding to a live GitHub secret-scanning alert by purging credentials from git history rather than just rotating the key.

Then building a native iOS app on top of it — as someone who had never written Swift before — learning the language by shipping a real product against a real backend, debugging real concurrency issues, and fixing real SwiftUI edge cases (nested `ScrollView` gesture conflicts, `GeometryReader` layout passes, Codable decoders bridging a schema built before the client existed).

The result is a running, autonomous system that solves a genuine personal problem, costs nothing to operate, has a native mobile interface, and monitors a global market of iOS internship opportunities that would never have been found manually.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

Built by **[Sahan Maiti](https://github.com/sahanmaiti)** · Apple Platforms developer

If DevSignal was useful, a ⭐ helps others find it.

</div>
