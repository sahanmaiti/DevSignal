# 📡 DevSignal

> An AI-powered iOS internship radar that discovers opportunities across 4 job
> platforms, scores them with an 8-factor AI model, generates personalized
> recruiter outreach, and tracks every application — running autonomously
> every 12 hours.

[![Live Dashboard](https://img.shields.io/badge/Live_Dashboard-Streamlit-FF4B4B?style=flat-square&logo=streamlit)](https://YOUR_STREAMLIT_URL)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?style=flat-square&logo=postgresql)](https://postgresql.org)
[![n8n](https://img.shields.io/badge/n8n-Automation-EA4B71?style=flat-square)](https://n8n.io)
[![Groq](https://img.shields.io/badge/Groq-Free_AI-F55036?style=flat-square)](https://groq.com)

**[Live Demo →](https://devsignal-sahanmaiti.streamlit.app/)**

---

## The problem

Finding iOS internships is a full-time job. Job boards update constantly,
opportunities appear across dozens of platforms, recruiter contacts are scattered,
and by the time you find a posting it may already be a week old. Doing this
manually while being a full-time CS student is unsustainable.

## The solution

DevSignal runs every 12 hours and does the work of a dedicated job-search
assistant: scrapes 4 platforms, filters ruthlessly, scores every opportunity
with AI, generates personalized outreach, finds recruiters, and sends a
Telegram digest to your phone.

---

## Status

| Phase | What | Status |
|-------|------|--------|
| 1 | Mac setup · project scaffold · RemoteOK scraper | ✅ Done |
| 2 | PostgreSQL · Docker · full persistence layer | ✅ Done |
| 3 | 3 new scrapers · job parser · filter engine · unit tests | ✅ Done |
| 4 | Telegram notifications | ✅ Done |
| 5 | AI scoring via Groq free API (8-factor model) | ✅ Done |
| 6 | Recruiter enrichment · outreach message generation | ✅ Done |
| 7 | n8n automation — runs every 12 hours | ✅ Done |
| 8 | Streamlit dashboard · Streamlit Cloud deployment | ✅ Done |

---

## System architecture

```
n8n (12h cron) → FastAPI webhook → run_pipeline.sh
                                         │
              ┌──────────────────────────┤
              │                          │
          Scrapers (4)               Processors
          RemoteOK                  job_parser.py
          HackerNews               filter_engine.py
          YC Startup               deduplicator.py
          Remotive                   enricher.py
              │                          │
              └──────────┬───────────────┘
                         │
                   PostgreSQL (local)
                         │
              ┌──────────┴───────────────┐
              │                          │
         AI layer                  Notifications
         ios_classifier.py         telegram_bot.py
         scorer.py (Groq)          (digest + alerts)
         outreach_generator.py
              │
         Neon cloud DB ← db_sync.py
              │
        Streamlit dashboard (public URL)
```

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.12 |
| Orchestration | n8n (Docker) + FastAPI webhook |
| Execution API | FastAPI + uvicorn |
| Process manager | macOS launchd |
| Database | PostgreSQL 16 (Docker) · Neon (cloud mirror) |
| AI / LLM | Groq API · Llama 3.1 8B (free, 14,400 req/day) |
| Email enrichment | Hunter.io (free tier — 25 req/month) |
| LinkedIn finder | Serper.dev Google Search API (free tier) |
| Notifications | Telegram Bot API |
| Dashboard | Streamlit · Plotly · SQLAlchemy |
| Testing | pytest (65 tests) |

**Total cost: $0/month** — every component uses a free tier.

---

## Project structure

```
devsignal/
│
├── api/
│   ├── __init__.py
│   └── pipeline_server.py       # FastAPI server — /run-pipeline, /health, /status
│                                #   called by n8n HTTP Request node
│                                #   interactive docs at http://localhost:8000/docs
│
├── dashboard/
│   ├── app.py                   # main entry point — sidebar nav, page routing
│   ├── db.py                    # cached SQLAlchemy queries (5-min TTL)
│   └── pages/
│       ├── overview.py          # KPI cards, score distribution, funnel, source chart
│       ├── opportunities.py     # filterable job table + inline application tracking
│       ├── outreach.py          # copyable recruiter messages + contact links
│       └── system.py           # pipeline health, run history, quick actions
│
├── n8n/
│   └── workflows/
│       └── main_pipeline.json   # importable n8n workflow definition
│                                #   Schedule → HTTP Request → Log Success
│                                #                           ↘ Parse Error → Telegram
│
├── pages/                       # Streamlit Cloud multi-page entry points
│   ├── 1_Overview.py            # self-contained (inline DB connection + queries)
│   ├── 2_Opportunities.py
│   ├── 3_Outreach.py
│   └── 4_System.py
│
├── scrapers/
│   ├── base_scraper.py          # shared session, hash generation, normalize()
│   ├── remoteok_scraper.py      # RemoteOK JSON API
│   ├── hackernews_scraper.py    # Algolia HN Search API
│   ├── yc_scraper.py            # YC WorkAtAStartup
│   └── remotive_scraper.py      # Remotive JSON API
│
├── processors/
│   ├── job_parser.py            # structured field extraction from raw text
│   ├── filter_engine.py         # profile-based quality gate
│   ├── deduplicator.py          # cross-run hash deduplication
│   ├── domain_finder.py         # extracts company domain from URL or name
│   ├── hunter_client.py         # Hunter.io free API — email pattern + contacts
│   ├── linkedin_finder.py       # Google search via Serper → LinkedIn profiles
│   └── enricher.py              # orchestrates all 3 enrichment layers
│
├── storage/
│   ├── schema.sql               # DDL: tables, indexes, updated_at trigger
│   ├── db_client.py             # psycopg2 pool + repository pattern
│   └── migrations.py            # apply/re-apply schema manually
│
├── ai/
│   ├── __init__.py
│   ├── ios_classifier.py        # heuristic + Llama 3.1 iOS product detection
│   ├── scorer.py                # 8-factor scoring model (0-100) with breakdown
│   └── outreach_generator.py    # recruiter messages — personalised by name
│
├── notifications/
│   └── telegram_bot.py          # digest (scores + recruiter links) + alerts
│
├── config/
│   ├── settings.py              # DATABASE_URL, API keys, thresholds, env vars
│   └── keywords.py              # iOS keyword lists, exclude terms, visa phrases
│
├── tests/
│   ├── test_scrapers.py         # hash consistency, normalization, field detection
│   ├── test_processors.py       # parser + filter unit tests
│   ├── test_scorer.py           # scorer + classifier tests (mocked, no API calls)
│   └── test_enricher.py         # domain, LinkedIn, email extraction tests
│
├── logs/                        # managed by launchd — gitignored
│   ├── api_server.log
│   └── api_server_error.log
│
├── .streamlit/
│   ├── secrets.toml             # gitignored — Neon DB URL for Streamlit Cloud
│   └── secrets.toml.example     # safe template to commit
│
├── docker-compose.yml           # PostgreSQL 16 + n8n, health checks, volumes
├── streamlit_app.py             # root-level Streamlit Cloud entry point
├── run_pipeline.sh              # shell wrapper called by FastAPI
├── db_sync.py                   # syncs top jobs to Neon cloud for public dashboard
├── run_scraper.py               # pipeline entry point — scrape → score → enrich
├── run_scorer.py                # standalone scorer
├── run_enricher.py              # standalone enricher
├── run_watchlist.py             # watchlist manager — add/list/check iOS companies
├── requirements.txt             # full local dependencies
└── requirements_dashboard.txt   # minimal deps for Streamlit Cloud
```

---

## Setup

**Prerequisites:** Python 3.12, Docker Desktop, free API keys for Groq, Hunter.io, and Serper.dev

```bash
# 1. Clone
git clone https://github.com/yourname/devsignal.git
cd devsignal

# 2. Virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Environment variables
cp .env.example .env
# Fill in:
#   DATABASE_URL
#   NEON_DATABASE_URL       — from neon.tech (free cloud Postgres)
#   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
#   GROQ_API_KEY            — free at console.groq.com
#   HUNTER_API_KEY          — free at hunter.io (25 searches/month)
#   SERPER_API_KEY          — free at serper.dev (2,500 searches on signup)
#   PIPELINE_API_KEY        — any secret string, e.g. devsignal-local-key-2024

# 4. Start database + n8n
docker compose up -d
docker compose ps   # postgres should show (healthy)

# 5. Apply schema
python storage/migrations.py

# 6. Start FastAPI server (permanent — survives reboots)
launchctl load ~/Library/LaunchAgents/com.devsignal.api.plist

# 7. Import n8n workflow
#    Open http://localhost:5678 → + → Import from file
#    Select: n8n/workflows/main_pipeline.json
#    Toggle workflow to Active

# 8. Run first pipeline
python run_scraper.py
python run_scorer.py
python run_enricher.py

# 9. Sync to public dashboard
python db_sync.py

# 10. Open local dashboard
streamlit run dashboard/app.py
```

---

## Running DevSignal

### Start everything

```bash
cd ~/projects/DevSignal
docker compose up -d            # starts Postgres + n8n
# FastAPI server starts automatically via launchd on login
```

### Stop everything

```bash
docker compose down             # stops containers, keeps data
docker compose down -v          # stops containers AND deletes all data
```

### Manual pipeline run

```bash
source venv/bin/activate
python run_scraper.py           # scrape + score + enrich + notify
python run_scorer.py            # score all unscored jobs
python run_enricher.py          # enrich top jobs
python db_sync.py               # push to Neon for public dashboard
```

### n8n automation UI

- URL: `http://localhost:5678`
- Username: `admin`
- Password: `devsignal2024`
- Schedule: every 12 hours
- Execution logs: **Executions** tab in n8n sidebar

### FastAPI server

- URL: `http://localhost:8000`
- Interactive docs: `http://localhost:8000/docs`
- Health check: `GET /health` (no auth required)
- Trigger pipeline: `POST /run-pipeline` with `X-Api-Key` header
- Managed by launchd — starts on Mac login, restarts on crash

```bash
# Manually trigger via curl
curl -X POST http://localhost:8000/run-pipeline \
  -H "X-Api-Key: devsignal-local-key-2024"

# Check last run result
curl http://localhost:8000/status \
  -H "X-Api-Key: devsignal-local-key-2024"

# View server logs
tail -f logs/api_server.log
```

### Streamlit dashboard

```bash
# Local (connects to Docker Postgres)
streamlit run dashboard/app.py

# Update public dashboard
python db_sync.py --limit 100   # push top 100 scored jobs to Neon
```

### launchd service management

```bash
# Stop the API server
launchctl stop com.devsignal.api

# Fully unload (disable autostart)
launchctl unload ~/Library/LaunchAgents/com.devsignal.api.plist

# Reload after changes
launchctl unload ~/Library/LaunchAgents/com.devsignal.api.plist
launchctl load   ~/Library/LaunchAgents/com.devsignal.api.plist
```

### Database access

```bash
docker exec -it devsignal_postgres psql -U radar -d devsignal
```

### Check system status

```bash
docker compose ps               # container health
curl http://localhost:8000/health
python -m pytest tests/ -v      # run all 65 tests
```

---

## Dashboard pages

**Overview** — KPI cards (jobs found, score ≥ 70, applied, responses, interviews, avg score), score distribution histogram, jobs-by-source bar chart, application funnel, recent top opportunities feed.

**Opportunities** — Filterable job table with score, remote, visa, and applied status filters. Click any row to expand full details: job description, AI-generated outreach message, recruiter contact info, score breakdown chart, and inline application tracking (applied status, response status, interview stage).

**Outreach** — Focused view of all generated recruiter messages sorted by score. Copyable code blocks, inline LinkedIn and apply links.

**System** — Pipeline health dashboard. Database connection status, time since last run, scrape run history table, new-jobs-per-run bar chart, source performance breakdown, and quick-action buttons to trigger the pipeline, check the API, or clear cache.

---

## Pipeline walkthrough

```
Triggered automatically by n8n every 12 hours
  (or manually: python run_scraper.py)

  DevSignal — Scraper Pipeline
  ══════════════════════════════════════════════════════════════

  [DB] Scrape run #5 started

  Raw jobs by source:
    RemoteOK                  8 jobs
    HackerNews                12 jobs
    YC WorkAtAStartup         5 jobs
    Remotive                  9 jobs
    ─────────────────────────────────
    TOTAL                     34 jobs

  [Parser] Parsed 34 jobs
  [Filter] 34 → 21 jobs
  [Deduplicator] 13 genuinely new jobs
  [DB] Inserted 13 new jobs

  ── AI Scorer ──────────────────────────────────────────────────

  [Classifier] Checking iOS product companies...
    [1/13] nooro                      → iOS
    [2/13] Some Web Agency            → not iOS
    [3/13] YC S24 Mobile Startup      → iOS

  [Scorer] Scoring all jobs...
    [1/13] nooro                      → 68/100
    [2/13] HN Anonymous Startup       → 18/100
    [3/13] YC S24 Mobile Startup      → 90/100  ← alert sent

  [Outreach] Generating messages for 5 jobs (score >= 65)...
    nooro                           ✓ (198 chars)
    YC S24 Mobile Startup           ✓ (163 chars)

  ── Recruiter Enrichment ───────────────────────────────────────

  [Hunter] Remaining quota this month: 22 searches

  [Enricher] Starting enrichment...
    [1/4] nooro                      (score: 68) → enriched (hunter+linkedin)
    [2/4] YC S24 Mobile Startup      (score: 90) → enriched (hunter)
    [3/4] FitTrack                   (score: 74) → enriched (linkedin)
    [4/4] HN Anonymous Startup       (score: 18) → no data found

  Enrichment Summary
  ══════════════════════════════════════════════════════════════
    Jobs processed: 4       Enriched: 3       Empty: 1

  Database totals:
    Total stored:     34    Remote jobs:  28
    Scored:           34    Applied:       0
    Enriched:         3 (this run)
```

---

## Database schema

```sql
opportunities          -- core table, one row per unique job
  id                   SERIAL PRIMARY KEY
  job_hash             VARCHAR(32) UNIQUE          -- MD5 of company+role+url
  company, role        VARCHAR
  remote               VARCHAR  CHECK IN ('Yes','No','Hybrid','Unknown')
  visa_sponsorship     VARCHAR  CHECK IN ('Yes','No','Unknown')
  experience_req       VARCHAR                     -- extracted by job_parser
  tech_stack           TEXT                        -- comma-separated keywords
  opportunity_score    SMALLINT CHECK 0-100        -- filled by AI scorer
  score_breakdown      JSONB                       -- per-factor scores
  outreach_message     TEXT                        -- personalised by recruiter name
  recruiter_name       VARCHAR                     -- filled by enricher
  recruiter_role       VARCHAR                     -- e.g. "iOS Engineering Manager"
  linkedin_profile     TEXT                        -- recruiter LinkedIn URL
  email                VARCHAR                     -- direct or pattern-constructed
  applied              BOOLEAN  DEFAULT FALSE
  response_status      VARCHAR  CHECK IN ('','No response','Viewed','Replied','Rejected')
  interview_stage      VARCHAR  CHECK IN ('','Phone screen','Technical','Final round','Offer','Rejected')
  date_found           TIMESTAMPTZ DEFAULT NOW()
  updated_at           TIMESTAMPTZ                 -- auto-maintained by trigger

companies_watchlist    -- iOS companies with no internship posted yet
scrape_runs            -- full audit log of every pipeline execution
```

---

## AI Scoring Model

Each job is scored 0–100 across 8 weighted factors:

| Factor | Points | Signal |
|--------|--------|--------|
| Remote available | 20 | Confirmed remote/WFH/distributed |
| Visa sponsorship | 15 | Explicitly stated in description |
| Swift / SwiftUI match | 15 | 15 for both, 8 for Swift/iOS only |
| iOS product confirmed | 15 | Company builds native iOS app |
| Experience level | 10 | 10 for 0–1 yrs, 5 for 1–2 yrs, 0 for 3+ |
| Salary mentioned | 10 | Any compensation figure stated |
| Funded startup | 10 | 10 for YC/Series A–C, 5 for early-stage |
| Posted recently | 5 | Within the last 7 days |

Jobs scoring **≥ 65** receive an auto-generated outreach message. If a recruiter name was found during enrichment, the message opens with `"Hi [Name],"`. Jobs scoring **≥ 85** trigger an immediate Telegram alert.

The entire AI layer runs on **Groq's free tier** — 14,400 requests/day, no credit card required.

---

## Enrichment Strategy

```
Layer 1 — Extract from existing data (free, instant)
  Parse apply_link URL for company domain
  Scan description for contact email
  Never makes an external request

Layer 2 — Hunter.io (25 searches/month free)
  Email format pattern + real employee names and LinkedIn URLs
  Cached to disk — one API call covers all jobs at the same company
  Only called for jobs scoring >= 70

Layer 3 — LinkedIn via Serper.dev (2,500 free searches on signup)
  site:linkedin.com/in searches via Google — never touches LinkedIn directly
  Only called when Layer 2 found no LinkedIn profile

Layer 4 — AI fallback (free Groq quota)
  Llama 3.1 suggests the most likely recruiter title to search for manually
```

---

## Key design decisions

**n8n + FastAPI separation** — n8n handles scheduling and error routing; FastAPI handles execution. Any scheduler can trigger the pipeline via `POST /run-pipeline` without touching pipeline code. The FastAPI server also auto-generates interactive docs at `/docs`.

**Self-contained Streamlit pages** — each file in `pages/` contains its own `get_engine()` and all queries inline, with no cross-module imports that silently fail on Streamlit Cloud. The `dashboard/` folder is used for local development; `pages/` is the Cloud-safe version.

**Neon as a read-only mirror** — Streamlit Cloud can't reach `localhost`. `db_sync.py` pushes top-scored jobs to Neon's free serverless Postgres after each scoring run, keeping the public dashboard fresh without exposing the local database.

**host.docker.internal** — n8n runs inside Docker; the FastAPI server runs on the Mac. Docker's special DNS name `host.docker.internal` lets containers reach the host without any network configuration.

**launchd over nohup** — macOS launchd manages the FastAPI process like a proper system service: starts on login, restarts on crash, writes logs to named files with no manual supervision.

**Repository pattern** — all SQL lives in `storage/db_client.py`. No other file imports `psycopg2` directly. One place to change queries, optimise, or add logging.

**Hash-based deduplication** — every job gets an MD5 fingerprint of `company + role + url`. The deduplicator fetches all existing hashes in a single query and checks against a Python `set` (O(1)). `ON CONFLICT DO NOTHING` is a final safety net.

**Heuristic-first classification** — `IOSClassifier` checks for Swift/SwiftUI/Xcode keywords locally before making a Groq API call. Obvious cases resolve instantly with zero quota cost.

**Immediate score persistence** — scores are written to the database as each one is received. If Groq rate-limits mid-run, all previously scored jobs are preserved and the next run resumes via `get_unscored_jobs()`.

**Hunter quota conservation** — enrichment only calls Hunter for jobs scoring ≥ 70. Results are cached to disk, so multiple jobs at the same company cost one API call.

---

## Tests

```bash
python -m pytest tests/ -v
# 65 passed — all offline, no real API calls during pytest
```

---

## Useful commands

```bash
# Postgres shell
docker exec -it devsignal_postgres psql -U radar -d devsignal

# Score distribution
SELECT
  CASE
    WHEN opportunity_score >= 80 THEN '80-100 (Excellent)'
    WHEN opportunity_score >= 65 THEN '65-79  (Good)'
    WHEN opportunity_score >= 50 THEN '50-64  (Average)'
    ELSE                              '0-49   (Low)'
  END AS range,
  COUNT(*) AS count
FROM opportunities
WHERE opportunity_score IS NOT NULL
GROUP BY range ORDER BY range DESC;

# Enrichment coverage
SELECT
  COUNT(*)                                               AS total,
  COUNT(*) FILTER (WHERE recruiter_name != '')           AS have_recruiter,
  COUNT(*) FILTER (WHERE email != '')                    AS have_email,
  COUNT(*) FILTER (WHERE linkedin_profile != '')         AS have_linkedin
FROM opportunities;

# Recent scrape runs
SELECT id, started_at, finished_at, jobs_found, jobs_new
  FROM scrape_runs ORDER BY id DESC LIMIT 5;

# Watchlist
python run_watchlist.py add "CRED" "iOS-first credit card rewards app"
python run_watchlist.py list
python run_watchlist.py check

# Re-score all jobs
UPDATE opportunities SET opportunity_score = NULL, score_breakdown = NULL;
python run_scorer.py

# Re-enrich all jobs
UPDATE opportunities SET recruiter_name='', email='', linkedin_profile='';
python run_enricher.py --min-score 70

# Sync to public dashboard
python db_sync.py --limit 100

# Check Hunter quota
python -c "from processors.hunter_client import HunterClient; print(HunterClient().get_remaining_quota())"

# Wipe everything and start fresh
docker compose down -v && docker compose up -d

# Run tests
python -m pytest tests/ -v
```

---

*Built this cause I got tired of manually refreshing LinkedIn.*
