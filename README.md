<div align="center">

# DevSignal

**An AI-powered iOS internship radar — discovers opportunities across 13+ platforms, scores them with a custom LLM, generates personalized recruiter outreach, and delivers everything to a native iOS app. Runs autonomously every 12 hours at zero cost.**

<br>

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-006EFF?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?style=flat-square&logo=postgresql&logoColor=white)](https://postgresql.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white)](https://docker.com)
[![n8n](https://img.shields.io/badge/n8n-Automation-EA4B71?style=flat-square)](https://n8n.io)
[![Groq](https://img.shields.io/badge/Groq-Llama_3.1-F55036?style=flat-square)](https://groq.com)
[![Tests](https://img.shields.io/badge/Tests-65_passing-22c55e?style=flat-square)](tests/)
[![License](https://img.shields.io/badge/License-MIT-22c55e?style=flat-square)](LICENSE)

<br>

> *Built by a CS student who got tired of manually refreshing LinkedIn.*

</div>

---

## The Problem

Searching for iOS internships is repetitive, noisy, and punishingly manual. For a CS student actively building with Swift and SwiftUI, doing this properly means:

- Checking 15+ platforms every day for new postings
- Most "iOS intern" listings require 3+ years of experience or don't even use Swift
- Recruiter contact details are scattered across LinkedIn, company websites, and job descriptions
- By the time you find a real opportunity, write a personalized message, and apply — it's already a week old and half-filled

**DevSignal solves this with a fully automated discovery-to-outreach pipeline.** It runs every 12 hours, surfaces only what matches your profile, scores every opportunity with AI, finds the recruiter, writes the outreach message, and delivers a ranked digest to your phone — while you're in class or asleep.

---

## What It Does

| Stage | What happens |
|---|---|
| **Discovery** | Scrapes 13 job platforms simultaneously for iOS/Swift roles |
| **Parsing** | Extracts structured fields (experience, salary, remote, visa) from raw descriptions |
| **Filtering** | Drops senior roles, non-iOS positions, and anything requiring 3+ years |
| **Deduplication** | MD5 hash fingerprinting — the same job never appears twice, across any number of runs |
| **Classification** | Determines whether the company actually builds a native iOS product |
| **AI Scoring** | Scores each job 0–100 across 8 weighted factors using Groq/Llama 3.1 |
| **Enrichment** | Finds recruiter names, LinkedIn profiles, and email patterns via Hunter.io + Serper for jobs scoring ≥50 |
| **Outreach** | Generates a personalized recruiter message for every job scoring ≥45 |
| **Notification** | Telegram digest + iOS push notifications with top opportunities |
| **Tracking** | Full application lifecycle tracked in Postgres — surfaced in the iOS Kanban board |
| **iOS App** | Native SwiftUI app: browse jobs, copy outreach, track applications, view analytics |

---

## Features

**Multi-Source Job Discovery**
Monitors RemoteOK, HackerNews "Who is Hiring", YC WorkAtAStartup, Remotive, Arbeitnow, Himalayas, WeWorkRemotely, Startup.jobs, Wellfound, Cutshort, Naukri, IndieHackers, Arc.dev and additional hybrid sources simultaneously. Every scraper inherits from a common `BaseScraper` abstract class that enforces a consistent `normalize → hash → run` interface. Adding a new source means implementing one method.

**8-Factor AI Opportunity Scoring**
Every job is evaluated by Llama 3.1 8B (via Groq's free inference API) against a structured scoring rubric with explicit point weights:

| Factor | Points | Rationale |
|---|---|---|
| Remote available | +20 | Maximises global reach |
| Visa sponsorship | +15 | Critical for international candidates |
| Swift/SwiftUI mentioned | +15 | Exact tech stack confirmation |
| iOS product confirmed | +15 | Real iOS work vs. vague "mobile" |
| Experience 0–1 years | +10 | Best match for current level |
| Salary/compensation listed | +10 | Company transparency signal |
| Funded startup (Seed–Series C) | +10 | Growth and learning potential |
| Posted within 7 days | +5 | Recency bonus |

The model returns a structured JSON breakdown explaining each factor — not just a number. Fallback rule-based scoring runs if Groq is unavailable.

**iOS Product Classifier**
A two-stage classifier first applies heuristic rules (if "swiftui" appears in the description, it's iOS — no API call needed), then falls back to Groq for ambiguous cases. Saves ~60% of API quota on clear cases.

**Personalized Recruiter Outreach**
For jobs scoring ≥45, the system generates a LinkedIn-ready connection message that references the company's specific iOS product, mentions your real projects, and stays under 300 characters. Temperature is set slightly higher than scoring to add natural variation — no two messages are identical.

**3-Layer Recruiter Enrichment**
Every free-tier resource is spent intentionally:
- **Layer 1** — Extract email addresses directly from job description text. Free, instant, no quota.
- **Layer 2** — Hunter.io domain search for email patterns and recruiter contacts. 25 searches/month free, reserved for jobs scoring ≥50 only. Results are locally cached in JSON so the same domain is never queried twice.
- **Layer 3** — Google search via Serper.dev to find LinkedIn profile URLs without ever touching LinkedIn's blocked scraping surface.
- **Layer 4** — Groq fallback to suggest the most likely recruiter title when all else fails.

**Automated Pipeline via n8n + FastAPI**
n8n fires on a 12-hour schedule and calls a local FastAPI webhook at `/run-pipeline`. FastAPI executes the pipeline and returns structured JSON. This architecture cleanly separates orchestration from execution — any scheduler (cron, GitHub Actions, another tool) can trigger the pipeline over HTTP without touching the pipeline code.

**Native iOS App (SwiftUI)**
A full 5-tab iOS app that consumes the FastAPI layer. Credentials stored securely in the iOS Keychain. Runs entirely offline for returning users using SwiftData caching. See [iOS App](#ios-app) section for full details.

**Zero-Cost Architecture**
Every service runs on a free tier. Monthly operational cost: **$0**.

| Service | Free tier | Usage |
|---|---|---|
| Groq | 14,400 req/day | Scoring, classification, outreach |
| Neon | 512 MB Postgres | Production cloud database |
| Streamlit Cloud | Unlimited public apps | Dashboard hosting |
| Hunter.io | 25 domain searches/month | Email enrichment |
| Serper.dev | 2,500 searches on signup | LinkedIn profile finding |
| Docker | Free | Local Postgres + n8n |
| Xcode + Simulator | Free | iOS app development |

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                      n8n Scheduler  (every 12h)                      │
│                      POST /run-pipeline                              │
│                             │                                        │
│                   FastAPI Server  :8000  (api/main.py)               │
│                   10 REST endpoints + API key middleware             │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
             ┌───────────────▼────────────────┐
             │         Scraper Layer          │
             │  13 sources → parse → filter   │
             │  → deduplicate → store         │
             └───────────────┬────────────────┘
                             │
             ┌───────────────▼────────────────┐
             │           AI Layer             │
             │  Groq Llama 3.1 8B             │
             │  ios_classifier → scorer       │
             │  → outreach_generator          │
             └───────────────┬────────────────┘
                             │
             ┌───────────────▼────────────────┐
             │       PostgreSQL 16            │
             │  opportunities + applications  │
             │  + device_tokens tables        │
             └──────┬──────────────┬──────────┘
                    │              │
         ┌──────────▼────┐  ┌──────▼───────────┐
         │  Telegram Bot │  │ iOS App (SwiftUI)│
         │  digest alerts│  │ 5 tabs, Keychain │
         └───────────────┘  │ auth, offline    │
                            └──────────────────┘
```

---

## iOS App

A native SwiftUI app built as a full companion to the backend pipeline. Designed for App Store distribution — not a prototype.

### Architecture

The iOS app follows **MVVM** (Model-View-ViewModel) with a clean layered architecture:

```
iOS App
├── Core/
│   ├── AppEnvironment.swift      — @Observable config, Keychain-backed credentials
│   ├── KeychainManager.swift     — Secure credential storage (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
│   └── Networking/
│       ├── APIClient.swift       — Generic async/await HTTP client, all 10 endpoints
│       └── APIError.swift        — Typed error enum (unauthorized, notFound, serverError, etc.)
│
├── Models/
│   ├── Job.swift                 — Codable + custom init (handles Int/String id, "Yes"/"No" Bool fields)
│   ├── JobsPage.swift            — Paginated response envelope
│   ├── OutreachMessage.swift     — Recruiter message + contact details
│   ├── Application.swift        — Application model + ApplicationStage enum
│   └── DashboardStats.swift     — Analytics aggregates + Swift Charts data
│
├── Features/
│   ├── Home/                     — Stats cards + top picks feed
│   ├── Discover/                 — Paginated job list, filter sheet, infinite scroll
│   ├── Outreach/                 — Expandable cards, inline edit, clipboard copy
│   ├── Tracker/                  — Full-height Kanban board, optimistic stage moves
│   └── Analytics/                — Swift Charts: score distribution, funnel, sources
│
├── Onboarding/
│   └── OnboardingView.swift      — Welcome + server setup, validates against /stats
│
├── Settings/
│   └── SettingsView.swift        — Connection status, credential reset
│
└── Shared/Components/            — ScoreBadge, CompanyAvatar, PillBadge, StatCard, AttributeRow
```

### Screens

| Tab | What it shows |
|---|---|
| **Home** | Greeting, real-time KPI cards (total jobs, applied, score ≥70), top 5 picks today |
| **Discover** | Full paginated job list with score badges, remote/visa pills, filter sheet, pull-to-refresh, infinite scroll. Tap → JobDetailView with score breakdown bars and apply button |
| **Outreach** | All pre-generated recruiter messages. Expandable cards with recruiter email, LinkedIn link, editable message (300 char counter), copy-to-clipboard with haptic |
| **Tracker** | Full-height Kanban board (GeometryReader-sized columns). 6 stages: Applied → Waiting → Replied → Interview → Offer → Rejected. Tap card → stage mover grid + notes editor. Optimistic updates with server-confirmed rollback |
| **Analytics** | Swift Charts bar chart (score distribution), horizontal funnel bars (Total → Applied → Interview), top sources table with avg score, pipeline last run status |

### Key Engineering Decisions

**Optimistic Updates in the Tracker**
When a user moves a Kanban card, the UI updates instantly via a local `stageOverrides` dict. The PATCH request fires in the background. On success, the override is removed and the server value takes over. On failure, the override reverts. No spinner on stage moves — feels instant.

**Type-safe JSON Decoding**
The database stores booleans as `"Yes"/"No"` strings and IDs as integers. Custom `init(from:)` decoders handle both transparently — Swift code always sees `Bool` and `String` regardless of what the DB returns, without any changes to the backend.

**Secure Credential Storage**
The API key and server URL are stored in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — never backed up to iCloud, only accessible when the device is unlocked. First launch shows an onboarding screen that validates credentials against a protected endpoint before saving.

**Nested ScrollView Gesture Conflict Resolution**
`ScrollView(.horizontal)` containing `ScrollView(.vertical)` eats button taps in SwiftUI. Resolved by replacing the inner vertical ScrollView with a plain `VStack` and using `.onTapGesture` + `.contentShape(Rectangle())` instead of `Button` for card interactions.

**GeometryReader for Full-Height Kanban**
Each Kanban column is sized using `GeometryReader` measuring the available screen height, then passed as `availableHeight` to `StageColumn`. This ensures columns always fill the entire screen regardless of card count, preventing the "floating small box" problem.

---

## Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **iOS App** | SwiftUI 5, Swift 5.9, Swift Charts, Combine | Native iOS client |
| **iOS Networking** | URLSession async/await, Codable | HTTP client + JSON decoding |
| **iOS Storage** | iOS Keychain, @AppStorage | Secure credentials + preferences |
| **Dashboard** | Streamlit 1.35, Plotly | Web analytics UI |
| **API Server** | FastAPI, Uvicorn | REST API + pipeline webhook |
| **Scraping** | Python 3.12, requests, BeautifulSoup4, feedparser | Multi-source job collection |
| **Processing** | re, custom NLP | Field extraction, filtering, deduplication |
| **AI / LLM** | Groq API (Llama 3.1 8B) | Scoring, classification, outreach |
| **Database** | PostgreSQL 16, psycopg2, SQLAlchemy | Primary store + Neon cloud DB |
| **Automation** | n8n (Docker), launchd | 12h scheduler + process management |
| **Enrichment** | Hunter.io API, Serper.dev API | Recruiter contacts + LinkedIn profiles |
| **Notifications** | Telegram Bot API | Mobile digest |
| **Infrastructure** | Docker Compose | Containerised Postgres + n8n |
| **Testing** | pytest, unittest.mock | 65 unit tests, zero real API calls |

---

## Getting Started

### Prerequisites

- macOS (Apple Silicon M1–M4) or Linux — for the backend
- Python 3.12+
- Docker Desktop
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

# Copy environment template and fill in credentials
cp .env.example .env

# Start PostgreSQL + n8n via Docker
docker compose up -d

# Apply the database schema
python storage/migrations.py
python storage/migrate_v2.py   # adds device_tokens + applications tables

# Run the full pipeline once to populate data
python run_scraper.py
python run_scorer.py
python run_enricher.py

# Start the FastAPI server (used by both n8n and iOS app)
uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
```

### iOS App Setup

```bash
# Open the iOS project in Xcode
open ios/DevSignal/DevSignal.xcodeproj
```

```
1. Select a simulator (iPhone 16 or later recommended)
2. Press ⌘R to build and run
3. On first launch, enter:
   - Server URL: http://127.0.0.1:8000
   - API Key: your PIPELINE_API_KEY from .env
4. Tap Connect — the app validates against /stats and saves to Keychain
```

For a physical device, use your Mac's local IP address instead of `127.0.0.1`:
```bash
# Find your Mac's local IP
ipconfig getifaddr en0
# Use this as the Server URL in the iOS onboarding screen
```

### Enable Automation

```bash
# Import the n8n workflow
# Open http://localhost:5678 → Import → n8n/workflows/main_pipeline.json
# Toggle the workflow to Active
# The pipeline now runs every 12 hours automatically
```

---

## Environment Variables

```bash
# ── Database ───────────────────────────────────────────────────────────────
DATABASE_URL=postgresql://radar:radar_pass@localhost:5433/devsignal
NEON_DATABASE_URL=postgresql://user:pass@host.neon.tech/neondb?sslmode=require

# ── AI Scoring ─────────────────────────────────────────────────────────────
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxx

# ── Telegram Notifications ─────────────────────────────────────────────────
TELEGRAM_BOT_TOKEN=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_CHAT_ID=xxxxxxxxxx

# ── Recruiter Enrichment ───────────────────────────────────────────────────
HUNTER_API_KEY=xxxxxxxxxxxxxxxx
SERPER_API_KEY=xxxxxxxxxxxxxxxx

# ── Pipeline API (must match iOS app onboarding) ───────────────────────────
PIPELINE_API_KEY=your-local-api-key
APP_ENV=development
```

---

## API Endpoints

The FastAPI server (`api/main.py`) exposes 10 REST endpoints, all protected by `X-API-Key` header middleware except `/health`.

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/health` | Server liveness check (public) |
| `GET` | `/jobs` | Paginated job list with filters |
| `GET` | `/jobs/{id}` | Single job detail + score breakdown |
| `GET` | `/jobs/{id}/outreach` | Recruiter message + contact info |
| `POST` | `/jobs/{id}/apply` | Record an application |
| `GET` | `/applications` | All tracked applications |
| `PATCH` | `/applications/{id}` | Update stage or notes |
| `GET` | `/stats` | Aggregated pipeline analytics |
| `POST` | `/devices` | Register iOS push notification token |
| `POST` | `/run-pipeline` | Trigger full scrape pipeline |

---

## Project Structure

```
devsignal/
│
├── ios/DevSignal/               # Native iOS app (SwiftUI)
│   ├── DevSignalApp.swift       # Entry point + AppRouter (onboarding vs main)
│   ├── MainTabView.swift        # 5-tab root view
│   ├── Core/
│   │   ├── AppEnvironment.swift # Keychain-backed config singleton
│   │   ├── KeychainManager.swift
│   │   └── Networking/
│   │       ├── APIClient.swift
│   │       └── APIError.swift
│   ├── Models/
│   │   ├── Job.swift
│   │   ├── JobsPage.swift
│   │   ├── OutreachMessage.swift
│   │   ├── Application.swift
│   │   └── DashboardStats.swift
│   ├── Features/
│   │   ├── Home/
│   │   ├── Discover/
│   │   ├── Outreach/
│   │   ├── Tracker/
│   │   └── Analytics/
│   ├── Onboarding/
│   ├── Settings/
│   └── Shared/Components/
│
├── scrapers/                    # One file per data source
│   ├── base_scraper.py
│   ├── remoteok_scraper.py
│   ├── hackernews_scraper.py
│   └── ... (13 total)
│
├── processors/                  # Data cleaning and enrichment
│   ├── job_parser.py
│   ├── filter_engine.py
│   ├── deduplicator.py
│   ├── enricher.py
│   ├── domain_finder.py
│   ├── hunter_client.py
│   └── linkedin_finder.py
│
├── ai/                          # LLM-powered modules
│   ├── ios_classifier.py
│   ├── scorer.py
│   └── outreach_generator.py
│
├── storage/
│   ├── schema.sql
│   ├── db_client.py             # Connection pool + full CRUD, singleton
│   ├── migrations.py            # Original schema
│   └── migrate_v2.py            # Adds device_tokens + applications tables
│
├── api/
│   ├── main.py                  # Full REST API — 10 endpoints
│   ├── middleware.py            # API key authentication middleware
│   ├── pipeline_server.py       # Legacy webhook (superseded by main.py)
│   └── start.sh                 # Convenience startup script
│
├── notifications/
│   └── telegram_bot.py
│
├── tests/                       # 65 unit tests
│   ├── test_scrapers.py
│   ├── test_processors.py
│   ├── test_scorer.py
│   ├── test_notifications.py
│   └── test_enricher.py
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
├── docker-compose.yml
├── requirements.txt
├── .env.example
└── README.md
```

---

## Engineering Highlights

This project was built to demonstrate production-level thinking across two distinct stacks.

**Full-Stack System Design**
The backend and iOS app are genuinely independent layers. The iOS app knows nothing about Groq, scrapers, or Postgres — it only speaks HTTP to the FastAPI layer. The FastAPI layer knows nothing about SwiftUI. This means the pipeline, web dashboard, and iOS app can all evolve independently without touching each other.

**ETL Pipeline Design**
Raw data flows through a typed transformation chain with clear stage boundaries. The deduplicator fetches all existing hashes in a single query, builds a Python `set`, and checks the entire batch in O(1) per job. The filter engine distinguishes between "confidently exclude" (senior title, proven 4+ year requirement) and "benefit of the doubt" (unknown experience) — false negatives are cheaper than missed opportunities.

**LLM Prompt Engineering**
The scoring prompt specifies exact point values, possible states per factor, a required JSON schema, and an explicit instruction not to infer information not present in the text. The classifier uses a heuristic pre-pass before making an API call — reducing Groq usage by ~60% on obvious cases. Every LLM call has fallback logic so Groq downtime never stops the pipeline.

**iOS Concurrency**
The `OutreachViewModel` uses `withThrowingTaskGroup` to fetch outreach messages for all jobs concurrently — equivalent to `asyncio.gather()` in Python. The `TrackerViewModel` uses optimistic updates: stage changes are reflected in the UI immediately while the PATCH request runs in the background, with automatic rollback on failure.

**Database Design**
The PostgreSQL schema uses `SMALLINT` for scores, `JSONB` for score breakdowns (queryable), `TIMESTAMPTZ` for all timestamps, and `TEXT` instead of `VARCHAR(N)`. Six named indexes cover all query patterns. A `BEFORE UPDATE` trigger maintains `updated_at` automatically on all tables.

**Quota-Aware Resource Management**
Hunter.io's 25 monthly searches are spent only on jobs scoring ≥50. Results are cached to disk so the same domain is never queried twice. Serper searches follow the same threshold. The classifier heuristic reduces Groq calls. Every free-tier constraint is treated as a design constraint.

**Cross-Platform Data Compatibility**
The database stores booleans as `"Yes"/"No"` strings (legacy column type) and IDs as integers. The iOS `Codable` decoders handle both transparently using custom `init(from:)` implementations — Swift always sees proper `Bool` and `String` types without any backend changes required.

**Resilient Automation**
When n8n's newer versions removed the `Execute Command` node, the system was redesigned around a FastAPI webhook. The pipeline is now triggerable by any HTTP client. `run_pipeline.sh` detects whether it's running inside Docker or on the host Mac and adjusts paths accordingly. The launchd plist ensures the FastAPI server restarts automatically after reboots.

**Testing Without Real Dependencies**
65 unit tests, zero real API calls. The Groq client, psycopg2, and requests are all mocked with `unittest.mock`. Tests cover LLM response edge cases (malformed JSON, markdown-fenced JSON, score values outside valid range), filter decision logic, and HTML escaping correctness.

---

## Roadmap

- [x] **Multi-source job discovery** — 13 platforms scraped simultaneously
- [x] **AI scoring** — 8-factor Groq/Llama 3.1 scoring with JSON breakdown
- [x] **Recruiter enrichment** — Hunter.io + Serper + 4-layer fallback
- [x] **Outreach generation** — Personalized LinkedIn messages for jobs scoring ≥45
- [ ] **Public web dashboard** — *Retired in Phase 1*
- [ ] **Neon production database** — *Retired in Phase 1*
- [x] **FastAPI REST layer** — 10 endpoints, API key middleware, pagination
- [x] **Native iOS app** — SwiftUI, 5 tabs, Keychain auth, offline cache
- [x] **iOS Kanban tracker** — Optimistic updates, 6 stages, notes editor
- [x] **iOS Analytics** — Swift Charts: score distribution, funnel, sources
- [x] **iOS Onboarding** — Secure credential setup, Keychain storage
- [ ] **APNs push notifications** — Live job alerts direct to iPhone
- [ ] **Resume tailoring** — Rewrite resume bullets to match a job description using Groq
- [ ] **LinkedIn outreach automation** — Send generated messages directly from the app
- [ ] **Ranking model v2** — Train on personal application outcome data over time
- [ ] **Additional sources** — Glassdoor, LinkedIn, Indeed (Playwright-based)
- [ ] **Email digest** — Weekly HTML report via SendGrid
- [ ] **Gmail integration** — Parse recruiter replies, auto-update Kanban stage
- [ ] **Salary benchmarking** — Aggregate and surface salary data from job descriptions

---

## Why This Matters

Most portfolio projects demonstrate that you can follow a tutorial. DevSignal demonstrates something different.

It required designing a multi-stage data pipeline under real constraints — limited API quota, changing platform structures, unreliable data quality. Making genuine product decisions: which API to call when, how to spend 25 free Hunter.io searches a month, how to handle failures at every stage without crashing the system. Writing LLM prompts that produce consistent structured output reliably, not just in demos. Responding to a live GitHub secret scanning alert and purging credentials from git history correctly.

Then building a native iOS app on top of it — as someone who had never written Swift before — learning the language by building a real product, debugging real concurrency issues, shipping real fixes for real SwiftUI edge cases (nested ScrollView gesture conflicts, Keychain threading, GeometryReader layout passes).

These are engineering problems that appear in production. The result is a running, autonomous system that solves a genuine personal problem, costs nothing to operate, has a native mobile interface, and monitors a global market of iOS internship opportunities that would not have been found manually.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

Built by **[Sahan Maiti](https://github.com/sahanmaiti)** · CS student · iOS developer

If DevSignal was useful, a ⭐ helps others find it.

</div>
