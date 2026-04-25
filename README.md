<div align="center">

# DevSignal

**An AI-powered job radar that discovers iOS internship opportunities across multiple platforms, scores them with a custom LLM model, generates personalized recruiter outreach, and runs autonomously every 12 hours — at zero cost.**

<br>

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?style=flat-square&logo=postgresql&logoColor=white)](https://postgresql.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Streamlit](https://img.shields.io/badge/Streamlit-1.35-FF4B4B?style=flat-square&logo=streamlit&logoColor=white)](https://streamlit.io)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white)](https://docker.com)
[![n8n](https://img.shields.io/badge/n8n-Automation-EA4B71?style=flat-square)](https://n8n.io)
[![Groq](https://img.shields.io/badge/Groq-Llama_3.1-F55036?style=flat-square)](https://groq.com)
[![Tests](https://img.shields.io/badge/Tests-65_passing-22c55e?style=flat-square)](tests/)
[![License](https://img.shields.io/badge/License-MIT-22c55e?style=flat-square)](LICENSE)

<br>

[![Live Dashboard](https://img.shields.io/badge/Live_Dashboard-devsignal.streamlit.app-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white)](https://devsignal-sahanmaiti.streamlit.app/)

<br>

> *Built by a CS student who got tired of manually refreshing LinkedIn.*

</div>

---

## The Problem

Searching for iOS internships is repetitive, noisy, and punishingly manual. For a CS student actively building with Swift and SwiftUI, doing this properly means:

- Checking 10+ platforms every day for new postings
- Most "iOS intern" listings require 3+ years of experience or don't even use Swift
- Recruiter contact details are scattered across LinkedIn, company websites, and job descriptions
- By the time you find a real opportunity, write a personalized message, and apply — it's already a week old and half-filled

**DevSignal solves this with a fully automated discovery-to-outreach pipeline.** It runs every 12 hours, surfaces only what matches your profile, scores every opportunity with AI, finds the recruiter, writes the outreach message, and delivers a ranked digest to your phone — while you're in class or asleep.

---

## What It Does

| Stage | What happens |
|---|---|
| **Discovery** | Scrapes 4 job platforms simultaneously for iOS/Swift roles |
| **Parsing** | Extracts structured fields (experience, salary, remote, visa) from raw descriptions |
| **Filtering** | Drops senior roles, non-iOS positions, and anything requiring 3+ years |
| **Deduplication** | MD5 hash fingerprinting — the same job never appears twice, across any number of runs |
| **Classification** | Determines whether the company actually builds a native iOS product |
| **AI Scoring** | Scores each job 0–100 across 8 weighted factors using Groq/Llama 3.1 |
| **Enrichment** | Finds recruiter names, LinkedIn profiles, and email patterns via Hunter.io + Serper |
| **Outreach** | Generates a personalized recruiter message for every job scoring ≥65 |
| **Notification** | Telegram digest with top 5 scored opportunities sent to your phone |
| **Tracking** | Full application lifecycle — applied, responded, interview stage — tracked in Postgres |

---

## Features

**Multi-Source Job Discovery**
Monitors RemoteOK (JSON API), HackerNews "Who is Hiring" threads (Algolia API), YC WorkAtAStartup, and Remotive simultaneously. Every scraper inherits from a common `BaseScraper` abstract class that enforces a consistent `normalize → hash → run` interface. Adding a new source means implementing one method.

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
For jobs scoring ≥65, the system generates a LinkedIn-ready connection message that references the company's specific iOS product, mentions your real projects, and stays under 280 characters. Temperature is set slightly higher than scoring to add natural variation — no two messages are identical.

**3-Layer Recruiter Enrichment**
Every free-tier resource is spent intentionally:
- **Layer 1** — Extract email addresses directly from job description text. Free, instant, no quota.
- **Layer 2** — Hunter.io domain search for email patterns and recruiter contacts. 25 searches/month free, reserved for jobs scoring ≥70 only. Results are locally cached in JSON so the same domain is never queried twice.
- **Layer 3** — Google search via Serper.dev to find LinkedIn profile URLs without ever touching LinkedIn's blocked scraping surface.
- **Layer 4** — Groq fallback to suggest the most likely recruiter title when all else fails.

**Automated Pipeline via n8n + FastAPI**
n8n fires on a 12-hour schedule and calls a local FastAPI webhook at `/run-pipeline`. FastAPI executes the pipeline and returns structured JSON. This architecture cleanly separates orchestration from execution — any scheduler (cron, GitHub Actions, another tool) can trigger the pipeline over HTTP without touching the pipeline code.

**Live Analytics Dashboard**
Four-page Streamlit dashboard deployed to Streamlit Cloud. Reads from a Neon cloud Postgres mirror so it's publicly accessible. Shows KPI cards, score distribution histogram, application funnel, outreach messages, pipeline health, and run history.

**Zero-Cost Architecture**
Every service runs on a free tier. Monthly operational cost: **$0**.

| Service | Free tier | Usage |
|---|---|---|
| Groq | 14,400 req/day | Scoring, classification, outreach |
| Neon | 512 MB Postgres | Cloud dashboard mirror |
| Streamlit Cloud | Unlimited public apps | Dashboard hosting |
| Hunter.io | 25 domain searches/month | Email enrichment |
| Serper.dev | 2,500 searches on signup | LinkedIn profile finding |
| Docker | Free | Local Postgres + n8n |

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    n8n Scheduler  (every 12h)                   │
│                    POST /run-pipeline                           │
│                           │                                     │
│                  FastAPI Server  :8000                          │
│                  (run_pipeline.sh)                              │
└──────────────────────────┬──────────────────────────────────────┘
                           │
           ┌───────────────▼────────────────┐
           │         Scraper Layer          │
           │                                │
           │  RemoteOK    →  JSON API       │
           │  HackerNews  →  Algolia API    │
           │  YC Startup  →  JSON API       │
           │  Remotive    →  JSON API       │
           └───────────────┬────────────────┘
                           │  raw job dicts
           ┌───────────────▼────────────────┐
           │       Processing Layer         │
           │                                │
           │  job_parser.py   (regex NLP)   │
           │  filter_engine.py              │
           │  deduplicator.py (MD5 + DB)    │
           │  enricher.py                   │
           │    ├─ Layer 1: description     │
           │    ├─ Layer 2: Hunter.io       │
           │    ├─ Layer 3: Serper/LinkedIn │
           │    └─ Layer 4: Groq fallback   │
           └───────────────┬────────────────┘
                           │  clean, enriched jobs
           ┌───────────────▼────────────────┐
           │           AI Layer             │
           │      Groq API (Llama 3.1 8B)   │
           │                                │
           │  ios_classifier.py             │
           │  scorer.py        (0–100)      │
           │  outreach_generator.py         │
           └───────────────┬────────────────┘
                           │
              ┌────────────▼─────────────┐
              │   PostgreSQL 16 (local)  │
              │   Docker container       │
              └──────────┬───────────────┘
                         │
           ┌─────────────┴───────────────┐
           │                             │
    ┌──────▼──────┐             ┌────────▼────────┐
    │  Telegram   │             │  Neon Postgres  │
    │  Bot digest │             │  (cloud mirror) │
    └─────────────┘             └────────┬────────┘
                                         │
                                ┌────────▼────────┐
                                │    Streamlit    │
                                │    Dashboard    │
                                │  (public URL)   │
                                └─────────────────┘
```

---

## Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Dashboard** | Streamlit 1.35, Plotly | Analytics UI, application tracking |
| **API Server** | FastAPI, Uvicorn | Pipeline webhook endpoint |
| **Scraping** | Python 3.12, requests, feedparser | HTTP + RSS job collection |
| **Processing** | re, custom NLP | Field extraction, filtering, deduplication |
| **AI / LLM** | Groq API (Llama 3.1 8B) | Scoring, classification, outreach |
| **Database** | PostgreSQL 16, psycopg2, SQLAlchemy | Primary store + Neon cloud mirror |
| **Automation** | n8n (Docker), launchd | 12h scheduler + process management |
| **Enrichment** | Hunter.io API, Serper.dev API | Recruiter contacts + LinkedIn profiles |
| **Notifications** | Telegram Bot API | Real-time mobile digest |
| **Infrastructure** | Docker Compose | Containerised Postgres + n8n |
| **Testing** | pytest, unittest.mock | 65 unit tests, zero real API calls in CI |

---

## Dashboard

Live at **[devsignal.streamlit.app](https://devsignal-sahanmaiti.streamlit.app/)**

**Overview** — KPI summary (jobs found, score ≥70, applied, responses, interviews, avg score), score distribution histogram with threshold marker, jobs-by-source bar chart coloured by average score, application funnel, recent top opportunities feed.

**Opportunities** — Filterable table: min-score slider, remote-only, unapplied-only, source filter. Click any row to expand full details: job description, AI score breakdown chart per factor, generated outreach message, recruiter contact, and inline application tracking (applied → response status → interview stage → save to DB).

**Outreach** — Focused recruiter outreach view. Every generated message displayed in a copyable code block alongside recruiter name, email, LinkedIn link, and direct Apply button.

**System** — Pipeline health: last-run freshness, total jobs, unscored count. Scrape run history table with duration, jobs found, new jobs inserted. Per-run bar chart. Source performance table with average score per platform.

---

## Getting Started

### Prerequisites

- macOS (Apple Silicon M1–M4) or Linux
- Python 3.12+
- Docker Desktop
- A free [Groq API key](https://console.groq.com) — no credit card required

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/devsignal.git
cd devsignal

# Create and activate a virtual environment
python3.12 -m venv venv
source venv/bin/activate

# Install all dependencies
pip install -r requirements.txt
```

### Configuration

```bash
# Copy the environment template and fill in your credentials
cp .env.example .env
```

See [Environment Variables](#environment-variables) for all required and optional keys.

### Start Infrastructure

```bash
# Start PostgreSQL 16 + n8n via Docker Compose
docker compose up -d

# Confirm both containers are healthy
docker compose ps

# Apply the database schema (idempotent — safe to re-run)
python storage/migrations.py
```

### First Run

```bash
# Run the full scraping pipeline
python run_scraper.py

# Score all discovered jobs with AI
python run_scorer.py

# Enrich top-scored jobs with recruiter data
python run_enricher.py

# Open the local dashboard
streamlit run streamlit_app.py
```

### Enable Automation

```bash
# Start the FastAPI webhook server (stays running via launchd on macOS)
python api/pipeline_server.py

# Import the n8n workflow
# Open http://localhost:5678 → Import → n8n/workflows/main_pipeline.json
# Toggle the workflow to Active
# The pipeline now runs every 12 hours automatically
```

---

## Environment Variables

```bash
# ── Database ───────────────────────────────────────────────────────────────
DATABASE_URL=postgresql://radar:radar_pass@localhost:5432/devsignal
NEON_DATABASE_URL=postgresql://user:pass@host.neon.tech/neondb?sslmode=require

# ── AI Scoring — free via Groq (console.groq.com) ──────────────────────────
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxx

# ── Telegram Notifications ─────────────────────────────────────────────────
TELEGRAM_BOT_TOKEN=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_CHAT_ID=xxxxxxxxxx

# ── Recruiter Enrichment ───────────────────────────────────────────────────
HUNTER_API_KEY=xxxxxxxxxxxxxxxx          # hunter.io — 25 domain searches/month free
SERPER_API_KEY=xxxxxxxxxxxxxxxx          # serper.dev — 2500 searches free on signup

# ── Pipeline API ───────────────────────────────────────────────────────────
PIPELINE_API_KEY=your-local-api-key
```

The `.env` file is gitignored. A safe `.env.example` with placeholder values is committed in its place. GitHub secret scanning is enabled on this repository.

---

## Usage

```bash
# ── Core pipeline ──────────────────────────────────────────────────────────
python run_scraper.py                  # Scrape → parse → filter → dedup → store → notify
python run_scorer.py                   # AI score all unscored jobs
python run_scorer.py --limit 5         # Score only 5 (useful for testing)
python run_enricher.py                 # Enrich jobs scoring ≥70
python run_enricher.py --min-score 60  # Lower the enrichment threshold
python run_enricher.py --limit 10      # Limit for testing

# ── Database sync ──────────────────────────────────────────────────────────
python db_sync.py                      # Push top 50 scored jobs to Neon cloud
python db_sync.py --limit 100          # Sync more jobs

# ── Watchlist ──────────────────────────────────────────────────────────────
python run_watchlist.py add "Razorpay" "iOS payment SDK and merchant app"
python run_watchlist.py list
python run_watchlist.py check          # Check if any watched companies posted jobs

# ── Dashboard ──────────────────────────────────────────────────────────────
streamlit run streamlit_app.py         # Local dashboard → http://localhost:8501

# ── API server ─────────────────────────────────────────────────────────────
python api/pipeline_server.py          # FastAPI → http://localhost:8000
                                       # Interactive docs → http://localhost:8000/docs

# ── Tests ──────────────────────────────────────────────────────────────────
python -m pytest tests/ -v             # Run all 65 tests
python -m pytest tests/test_scorer.py  # Run a specific module

# ── Infrastructure ─────────────────────────────────────────────────────────
docker compose up -d                   # Start Postgres + n8n
docker compose ps                      # Check container health
docker compose down                    # Stop (data preserved)
docker compose down -v                 # Stop + delete all volumes
```

---

## Project Structure

```
devsignal/
│
├── scrapers/                    # One file per data source
│   ├── base_scraper.py          # Abstract base: normalize(), hash(), run()
│   ├── remoteok_scraper.py      # RemoteOK public JSON API
│   ├── hackernews_scraper.py    # HN "Who is Hiring" via Algolia API
│   ├── yc_scraper.py            # YC WorkAtAStartup
│   └── remotive_scraper.py      # Remotive public JSON API
│
├── processors/                  # Data cleaning and enrichment
│   ├── job_parser.py            # Regex extraction: exp, salary, remote, visa
│   ├── filter_engine.py         # Drops senior/non-iOS/over-experience roles
│   ├── deduplicator.py          # MD5 hash dedup vs. full database
│   ├── enricher.py              # Orchestrates 3-layer enrichment pipeline
│   ├── domain_finder.py         # Extracts company domain from URL or name
│   ├── hunter_client.py         # Hunter.io API with local JSON cache
│   └── linkedin_finder.py       # Google/Serper search for LinkedIn profiles
│
├── ai/                          # LLM-powered modules (Groq free API)
│   ├── ios_classifier.py        # Heuristic + AI: confirms iOS product
│   ├── scorer.py                # 8-factor opportunity scoring (0–100)
│   └── outreach_generator.py    # Personalized recruiter message generation
│
├── storage/                     # Database interface
│   ├── schema.sql               # DDL: 3 tables, 6 indexes, updated_at trigger
│   ├── db_client.py             # Connection pool + full CRUD, singleton instance
│   └── migrations.py            # Applies schema idempotently
│
├── notifications/
│   └── telegram_bot.py          # Digest, high-score alerts, error notifications
│
├── api/
│   └── pipeline_server.py       # FastAPI webhook: /run-pipeline, /health, /status
│
├── dashboard/
│   ├── app.py                   # Entry point + shared CSS config
│   ├── db.py                    # Cached SQLAlchemy queries (5-min TTL)
│   └── pages/
│       ├── overview.py          # KPIs, charts, funnel, recent feed
│       ├── opportunities.py     # Filterable table + inline app tracking
│       ├── outreach.py          # Generated messages + recruiter contacts
│       └── system.py            # Pipeline health + run history
│
├── pages/                       # Streamlit Cloud native multipage routing
│   ├── 1_Overview.py
│   ├── 2_Opportunities.py
│   ├── 3_Outreach.py
│   └── 4_System.py
│
├── n8n/workflows/
│   └── main_pipeline.json       # Importable workflow: 12h cron → HTTP → error branch
│
├── tests/                       # 65 unit tests — zero real API calls
│   ├── test_scrapers.py         # Hash consistency, normalize schema, keyword detection
│   ├── test_processors.py       # Parser regex, filter rules, visa/remote detection
│   ├── test_scorer.py           # JSON parsing, code block stripping, score clamping
│   ├── test_notifications.py    # HTML escaping, message splitting, digest formatting
│   └── test_enricher.py         # Domain extraction, LinkedIn name parsing
│
├── config/
│   ├── settings.py              # Centralised env var loading via python-dotenv
│   └── keywords.py              # iOS keywords, tech terms, seniority exclusions
│
├── run_scraper.py               # Main pipeline: scrape → parse → filter → store → notify
├── run_scorer.py                # Batch AI scorer with --limit flag
├── run_enricher.py              # Enrichment runner with --min-score, --limit flags
├── run_pipeline.sh              # Shell wrapper called by n8n and launchd
├── run_watchlist.py             # Company watchlist: add / list / check
├── db_sync.py                   # Sync local Postgres → Neon cloud (--limit flag)
├── streamlit_app.py             # Streamlit Cloud entry point
├── docker-compose.yml           # PostgreSQL 16-alpine + n8n containers
├── requirements.txt
├── requirements_dashboard.txt   # Minimal deps for Streamlit Cloud
├── .env.example
└── README.md
```

---

## Engineering Highlights

This project was built to demonstrate production-level thinking, not just working code.

**System Design and Separation of Concerns**
The pipeline is structured in strict layers: scraping, processing, AI, storage, and notification. Each layer communicates through defined interfaces. Any layer can fail, be replaced, or be extended without touching the others. The `BaseScraper` abstract class enforces a contract — every new source automatically gets normalization, hash generation, error handling, and the `run()` entrypoint for free.

**ETL Pipeline Design**
Raw data flows through a typed transformation chain with clear stage boundaries. The deduplicator fetches all existing hashes in a single query, builds a Python `set`, and checks the entire batch in O(1) per job. The filter engine distinguishes between "confidently exclude" (senior title, proven 4+ year requirement) and "benefit of the doubt" (unknown experience) — false negatives are cheaper than missed opportunities.

**LLM Prompt Engineering**
The scoring prompt specifies exact point values, possible states per factor, a required JSON schema, and an explicit instruction not to infer information not present in the text. The classifier uses a heuristic pre-pass (string matching against known iOS/non-iOS signals) before making an API call — reducing Groq usage by ~60% on obvious cases. Every LLM call has fallback logic so Groq downtime never stops the pipeline.

**Database Design**
The PostgreSQL schema uses proper column types throughout: `SMALLINT` for scores (0–100, wastes no storage), `JSONB` for score breakdowns (queryable, not just a dumped string), `TIMESTAMPTZ` for all timestamps (timezone-aware), and `TEXT` instead of `VARCHAR(N)` for variable-length fields after learning the hard way that HackerNews job titles have no length limit. Six named indexes cover the query patterns the dashboard and pipeline actually run. A `BEFORE UPDATE` trigger maintains `updated_at` automatically.

**Quota-Aware Resource Management**
Hunter.io's 25 monthly searches are spent only on jobs scoring ≥70. Hunter results are cached to disk so the same domain is never queried twice across runs. Serper searches follow the same threshold. The classifier heuristic reduces Groq calls. Every free-tier constraint is treated as a design constraint, not an afterthought.

**Resilient Automation**
When n8n's newer versions removed the `Execute Command` node, the system was redesigned around a FastAPI webhook — a cleaner architecture than running shell commands from a workflow engine. The pipeline is now triggerable by any HTTP client. `run_pipeline.sh` detects whether it's running inside Docker (`/app`) or on the host Mac and adjusts paths accordingly. The launchd plist ensures the FastAPI server restarts automatically after reboots.

**Testing Without Real Dependencies**
65 unit tests, zero real API calls. The Groq client, psycopg2, and requests are all mocked with `unittest.mock`. Tests cover LLM response edge cases (malformed JSON, markdown-fenced JSON, score values outside valid range), filter decision logic, HTML escaping correctness for the Telegram formatter, and message splitting at the exact 4096-character boundary.

---

## Roadmap

- [ ] **Resume tailoring** — Given a job description, rewrite specific resume bullets to match using the same Groq pipeline
- [ ] **LinkedIn outreach automation** — Browser automation layer to send generated messages directly from the dashboard
- [ ] **Ranking model v2** — Train a lightweight classifier on personal application outcome data collected over time
- [ ] **Additional sources** — Glassdoor, Cutshort, Naukri, Otta (Playwright-based with proxy rotation)
- [ ] **Email digest** — Weekly HTML report via SendGrid as an alternative to Telegram
- [ ] **Interview prep assistant** — For each accepted application, auto-generate company-specific Swift/iOS questions
- [ ] **Gmail integration** — Parse recruiter replies and auto-update response status in the database
- [ ] **Salary benchmarking** — Aggregate and surface salary data from collected job descriptions

---

## Why This Matters

Most portfolio projects demonstrate that you can follow a tutorial. DevSignal demonstrates something different.

It required designing a multi-stage data pipeline under real constraints — limited API quota, changing platform structures, unreliable data quality. Making genuine product decisions: which API to call when, how to spend 25 free Hunter.io searches a month, how to handle failures at every stage without crashing the system. Writing LLM prompts that produce consistent structured output reliably, not just in demos. Responding to a live GitHub secret scanning alert and purging credentials from git history correctly.

These are engineering problems that appear in production. The result is a running, autonomous system that solves a genuine personal problem, costs nothing to operate, and has surfaced iOS internship opportunities that would not have been found manually.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

Built by **[Sahan Maiti](https://github.com/sahanmaiti)** · CS student · iOS developer

If DevSignal was useful, a ⭐ helps others find it.

</div>
