# DevSignal

> AI-powered iOS internship radar — scrapes 4 job platforms, parses and filters
> results intelligently, persists everything to PostgreSQL, scores every
> opportunity with an 8-factor AI model, fires personalized recruiter
> outreach automatically, and runs fully autonomously every 12 hours.

```
pipeline:  scrape → parse → filter → deduplicate → store → score → enrich → notify → track
progress:  █████████████████████████░  Phase 7 of 8 complete
```

---

## What it does

DevSignal runs a fully automated job discovery pipeline targeted at iOS internship
roles. Every 12 hours, n8n wakes up and triggers the full pipeline — pulling from
four job platforms, extracting structured fields from raw description text, dropping
anything that doesn't match the target profile, deduplicating against the full history
in PostgreSQL, and saving only genuinely new opportunities.

Each new job is immediately scored 0–100 by an 8-factor AI model (free via Groq's
Llama 3.1 API), with a per-factor breakdown explaining the score. Jobs above 65
get a personalised recruiter outreach message generated automatically. Jobs above
85 fire an immediate Telegram alert.

High-scoring jobs then go through a 3-layer enrichment pass: domain extraction,
Hunter.io email pattern lookup, and LinkedIn profile discovery via Google Search.
When a recruiter name is found, the outreach message addresses them directly.

The entire pipeline runs without any manual intervention. n8n handles scheduling
and error routing; a local FastAPI server handles execution. If anything fails,
a Telegram alert fires immediately with the error details.

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
| 8 | Streamlit dashboard · portfolio polish | 🔲 Next |

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.12 |
| Database | PostgreSQL 16 (Docker) |
| Orchestration | n8n (Docker) |
| Execution API | FastAPI + uvicorn |
| Process manager | macOS launchd |
| AI scoring | Groq API · Llama 3.1 8B (free tier) |
| Email enrichment | Hunter.io (free tier — 25 req/month) |
| LinkedIn finder | Serper.dev Google Search API (free tier) |
| Notifications | Telegram Bot API |
| Dashboard | Streamlit (Phase 8) |
| Testing | pytest |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AUTOMATION LAYER                        │
│                                                             │
│  n8n (Docker)  ←── Schedule Trigger (every 12 hours)        │
│       │                                                     │
│       │  POST /run-pipeline (host.docker.internal:8000)     │
│       ▼                                                     │
│  FastAPI (Mac) ←── api/pipeline_server.py                   │
│       │             Protected by X-Api-Key header           │
│       │             Managed by macOS launchd                │
│       ▼                                                     │
│  run_pipeline.sh ──── scrape → score → enrich               │
│                                                             │
│  n8n error branch:                                          │
│    HTTP 500 → Parse Error → Telegram Error Alert            │
└───────────┬─────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│                        run_scraper.py                       │
│                      pipeline entry point                   │
└───────────┬─────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│  SCRAPERS  (scrapers/)                                      │
│                                                             │
│  RemoteOKScraper   — JSON API, no auth                      │
│  HackerNewsScraper — Algolia API, monthly hiring threads    │
│  YCScraper         — YC WorkAtAStartup, structured metadata │
│  RemotiveScraper   — Public JSON API, remote-first jobs     │
└───────────┬─────────────────────────────────────────────────┘
            │  raw job dicts
            ▼
┌─────────────────────────────────────────────────────────────┐
│  PROCESSING  (processors/)                                  │
│                                                             │
│  job_parser      — regex extracts exp, salary, remote, visa │
│  filter_engine   — drops senior/non-iOS roles               │
│  deduplicator    — hash-checks against full DB history      │
└───────────┬─────────────────────────────────────────────────┘
            │  filtered, unique jobs only
            ▼
┌─────────────────────────────────────────────────────────────┐
│  STORAGE  (storage/)                                        │
│                                                             │
│  db_client.py  — connection pool, full CRUD, singleton      │
│  schema.sql    — 3 tables, 6 indexes, auto-update trigger   │
│                                                             │
│  PostgreSQL 16  ←──────────────  Docker                     │
└───────────┬─────────────────────────────────────────────────┘
            │  new jobs persisted
            ▼
┌─────────────────────────────────────────────────────────────┐
│  AI LAYER  (ai/)                              FREE via Groq │
│                                                             │
│  ios_classifier.py  — heuristic + Llama 3.1                 │
│                        detects native iOS product companies │
│  scorer.py          — 8-factor model, returns 0-100         │
│                        score + breakdown + summary          │
│  outreach_generator — personalised recruiter messages       │
│                        addresses recruiter by name if found │
│                                                             │
│  run_scorer.py  ←──  standalone batch scorer                │
└───────────┬─────────────────────────────────────────────────┘
            │  scores written to DB
            ▼
┌─────────────────────────────────────────────────────────────┐
│  ENRICHMENT  (processors/)           score >= 70 only       │
│                                                             │
│  domain_finder.py   — extracts company domain from URL/name │
│  hunter_client.py   — email pattern + contacts (25/mo free) │
│                        JSON cache prevents duplicate calls  │
│  linkedin_finder.py — Google search → LinkedIn profile URLs │
│  enricher.py        — orchestrates all 3 layers + AI guess  │
│                                                             │
│  run_enricher.py  ←──  standalone enrichment runner         │
│  run_watchlist.py ←──  track companies not yet hiring       │
└───────────┬─────────────────────────────────────────────────┘
            │  recruiter_name, email, linkedin_profile written to DB
            ▼
┌─────────────────────────────────────────────────────────────┐
│  NOTIFICATIONS  (notifications/)                            │
│                                                             │
│  telegram_bot.py  — digest with scores + recruiter links    │
│                     immediate alert for score >= 85         │
│                     error alert if n8n pipeline fails       │
└─────────────────────────────────────────────────────────────┘
```

---

## Project structure

```
devsignal/
│
├── api/
│   ├── __init__.py
│   └── pipeline_server.py       # FastAPI server — /run-pipeline, /health, /status
│                                #   called by n8n HTTP Request node
│                                #   docs at http://localhost:8000/docs
│
├── n8n/
│   └── workflows/
│       └── main_pipeline.json   # importable n8n workflow definition
│                                #   5 nodes: Schedule → HTTP Request → Log Success
│                                #                                    ↘ Parse Error → Telegram
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
├── logs/                        # created by launchd — gitignored
│   ├── api_server.log
│   └── api_server_error.log
│
├── docker-compose.yml           # PostgreSQL 16 + n8n, health checks, volumes
├── run_pipeline.sh              # shell wrapper called by FastAPI — works in Docker + Mac
├── run_scraper.py               # pipeline entry point — scrape → score → enrich
├── run_scorer.py                # standalone scorer — python run_scorer.py [--limit N]
├── run_enricher.py              # standalone enricher — python run_enricher.py [--min-score N]
├── run_watchlist.py             # watchlist manager — add/list/check iOS companies
└── requirements.txt
```

---

## Running DevSignal

### Start everything

```bash
cd ~/projects/DevSignal
docker compose up -d        # starts Postgres + n8n
python api/pipeline_server.py   # start FastAPI (or rely on launchd)
```

### Stop everything

```bash
docker compose down         # stops containers, keeps data
docker compose down -v      # stops containers AND deletes all data
```

### Manual pipeline run

```bash
source venv/bin/activate
python run_scraper.py       # scrape + score + enrich + notify
python run_scorer.py        # score all unscored jobs
python run_enricher.py      # enrich top jobs
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
- Health check: `GET /health` (no auth)
- Trigger pipeline: `POST /run-pipeline` with `X-Api-Key` header
- Managed by launchd — starts on login, restarts on crash

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
python -m pytest tests/ -v      # run all tests
curl http://localhost:8000/health
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
#   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
#   GROQ_API_KEY        — free at console.groq.com
#   HUNTER_API_KEY      — free at hunter.io (25 searches/month)
#   SERPER_API_KEY      — free at serper.dev (2,500 searches on signup)
#   PIPELINE_API_KEY    — any secret string, e.g. devsignal-local-key-2024

# 4. Start database + n8n
docker compose up -d
docker compose ps   # postgres should show (healthy)

# 5. Confirm schema
python storage/migrations.py
# Expected: "All done." with all 3 tables listed

# 6. Start the FastAPI server (permanent — survives reboots)
launchctl load ~/Library/LaunchAgents/com.devsignal.api.plist

# 7. Import n8n workflow
#    Open http://localhost:5678 → + → Import from file
#    Select: n8n/workflows/main_pipeline.json
#    Toggle workflow to Active

# 8. Run manually to verify end-to-end
curl -X POST http://localhost:8000/run-pipeline \
  -H "X-Api-Key: devsignal-local-key-2024"
```

Run it twice. The second run should insert 0 new jobs. Scores and enrichment data
from the first run are preserved.

**Individual runners:**

```bash
python run_scorer.py                       # score all unscored jobs
python run_scorer.py --limit 5             # test with 5 jobs first

python run_enricher.py                     # enrich unenriched jobs >= default threshold
python run_enricher.py --min-score 70      # explicit score threshold
python run_enricher.py --limit 3           # test with 3 jobs first
python run_enricher.py --all               # enrich every job regardless of score

python run_watchlist.py add "Razorpay" "iOS payment SDK and merchant app"
python run_watchlist.py list
python run_watchlist.py check              # see if any watchlist company has posted
```

---

## Pipeline walkthrough

```
python run_scraper.py   (or triggered automatically by n8n every 12 hours)

  DevSignal — Scraper Pipeline  (Phase 7)
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
    ...

  [Scorer] Scoring all jobs...
    [1/13] nooro                      → 68/100
    [2/13] HN Anonymous Startup       → 18/100
    [3/13] YC S24 Mobile Startup      → 90/100  ← alert sent
    ...

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
    Total stored:     34
    Scored:           34
    Enriched:         3 (this run)
    Remote jobs:      28
    Applied:          0
```

---

## Database schema

Three tables. Everything goes through `schema.sql` — applied automatically on
first container start via Docker's `initdb.d` mechanism.

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

Six indexes cover the most common query patterns: score range, applied status,
date window, source breakdown, hash lookup, and unscored job count.

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

The `IOSClassifier` runs a fast heuristic first (checking for Swift/SwiftUI/Xcode
mentions) before making an API call, saving quota for ambiguous cases. Every score
is stored alongside its full per-factor `breakdown` JSONB and a one-sentence AI
`summary` explaining the result.

Jobs scoring **≥ 65** receive an auto-generated outreach message. If a recruiter
name was found during enrichment, the message opens with `"Hi [Name],"`. Jobs
scoring **≥ 85** trigger an immediate Telegram alert in addition to the regular
digest.

The entire AI layer runs on **Groq's free tier** — 14,400 requests/day,
no credit card required.

---

## Enrichment Strategy

For each high-scoring job (score ≥ 70), enrichment runs in three layers —
cheapest first, premium quota spent last.

```
Layer 1 — Extract from existing data (always free, instant)
  Parse apply_link URL for a direct company domain
  Scan description text for a contact email address
  Never makes an external request

Layer 2 — Hunter.io (25 searches/month free)
  Given the company domain, returns the email format pattern
  Returns real employee names, positions, and LinkedIn URLs
  Cached to disk — one API call covers all jobs at the same company
  Only called for jobs scoring >= 70

Layer 3 — LinkedIn via Serper.dev (2,500 free searches on signup)
  Runs site:linkedin.com/in searches to find recruiter profile URLs
  Never touches LinkedIn directly — uses Google's public index
  Only called when Layer 2 found no LinkedIn profile

Layer 4 — AI fallback (free Groq quota)
  When all else fails, Llama 3.1 suggests the most likely recruiter
  title so you know what to search for manually
  Returns a suggested title — not a real contact
```

| Threshold | Layers that run |
|-----------|----------------|
| Any score | Layer 1 (description text scan) |
| Score ≥ 70 | Layers 1 + 2 (Hunter) + 3 (LinkedIn) |
| Score < 70, no contact found | Layer 4 (AI title guess) |

---

## Key design decisions

**n8n + FastAPI separation** — n8n handles scheduling and error routing; FastAPI
handles execution. Two separate concerns, cleanly separated. Any scheduler — cron,
a GitHub Action, another tool — can trigger the pipeline via `POST /run-pipeline`
without touching the pipeline code. This also gives the pipeline an interactive
docs UI at `/docs` out of the box.

**host.docker.internal** — n8n runs inside Docker; the FastAPI server runs on the
Mac. Docker's special DNS name `host.docker.internal` lets containers reach
services on the host machine without any network configuration.

**launchd over nohup** — macOS launchd manages the FastAPI process like a proper
system service: starts on login, restarts on crash, writes logs to named files.
`nohup` achieves the same result but with no crash recovery and no log rotation.

**Repository pattern** — all SQL lives in `storage/db_client.py`. No other file
imports `psycopg2` directly. One place to change queries, one place to optimise,
one place to add logging.

**Hash-based deduplication** — every job gets an MD5 fingerprint of
`company + role + url`. The deduplicator fetches all existing hashes in a single
query and does membership checks against a Python `set` (O(1)). The INSERT uses
`ON CONFLICT (job_hash) DO NOTHING` as a final safety net.

**Parser before filter** — `job_parser.py` runs before `filter_engine.py`
because the filter uses `experience_req` to make drop decisions. Parsing first
means the filter has structured data to work with instead of doing its own regex.

**Filter conservatism** — when uncertain, jobs are kept. It's better to store a
borderline job and let the AI scorer give it a 30/100 than to silently drop
something valid. Hard drops are reserved for confirmed seniority keywords and
explicit high-experience requirements.

**Heuristic-first classification** — `IOSClassifier` checks for Swift/SwiftUI/Xcode
keywords locally before making a Groq API call. Obvious cases are resolved
instantly with zero quota cost. The API is only called for genuinely ambiguous
descriptions.

**Immediate score persistence** — `run_scorer.py` writes each score to the database
as soon as it's received, not in a batch at the end. If Groq rate-limits mid-run
or the script is interrupted, all previously scored jobs are preserved and the
next run resumes from where it left off (`get_unscored_jobs()` skips already-scored rows).

**Hunter quota conservation** — enrichment only calls Hunter for jobs scoring ≥ 70
(configurable via `ENRICHMENT_MIN_SCORE`). Results are cached to a local JSON file,
so multiple jobs at the same company cost only one API call. The 25 monthly free
requests are reserved for genuinely high-value opportunities.

**LinkedIn via Google, not LinkedIn** — LinkedIn aggressively blocks all scraping.
`linkedin_finder.py` runs `site:linkedin.com/in "Company" "iOS"` queries through
Serper.dev's Google Search API instead. Public profile URLs come back in search
results without ever touching LinkedIn's servers directly.

**Connection pool** — `psycopg2.pool.ThreadedConnectionPool` (1–5 connections)
is created once at import time as a module-level singleton. Every import of
`from storage.db_client import db` shares the same pool — no per-query
connection overhead.

**Docker over native Postgres** — isolated, version-pinned, reproducible. Reset
the entire database in one command. Upgrade Postgres by changing one line.
Never conflicts with other local services.

---

## Tests

```bash
python -m pytest tests/ -v
```

```
tests/test_scrapers.py::test_hash_is_consistent                        PASSED
tests/test_scrapers.py::test_hash_is_different_for_different_jobs      PASSED
tests/test_scrapers.py::test_normalize_has_all_required_fields         PASSED
tests/test_scrapers.py::test_remoteok_is_ios_relevant                  PASSED
tests/test_scrapers.py::test_remoteok_salary_format                    PASSED
tests/test_scrapers.py::test_hn_first_line_parsing                     PASSED
tests/test_processors.py::test_extract_experience_range                PASSED
tests/test_processors.py::test_extract_remote_yes                      PASSED
tests/test_processors.py::test_extract_visa_no                         PASSED
tests/test_processors.py::test_filter_drops_senior_title               PASSED
tests/test_processors.py::test_filter_keeps_when_exp_unknown           PASSED
... (24 total)
tests/test_scorer.py::test_scorer_parse_valid_json                     PASSED
tests/test_scorer.py::test_scorer_parse_json_with_code_block           PASSED
tests/test_scorer.py::test_scorer_score_clamped_to_range               PASSED
tests/test_scorer.py::test_scorer_fallback_on_bad_json                 PASSED
tests/test_scorer.py::test_scorer_fallback_scores_correctly            PASSED
tests/test_scorer.py::test_classifier_heuristic_swift_is_ios           PASSED
tests/test_scorer.py::test_classifier_heuristic_react_native_not_ios   PASSED
tests/test_scorer.py::test_classifier_heuristic_unsure_returns_none    PASSED
tests/test_scorer.py::test_classifier_parse_valid_response             PASSED
tests/test_scorer.py::test_classifier_parse_false_response             PASSED
tests/test_scorer.py::test_classifier_parse_invalid_json_falls_back    PASSED
tests/test_enricher.py::test_extract_company_domain_from_direct_url    PASSED
tests/test_enricher.py::test_extract_strips_www                        PASSED
tests/test_enricher.py::test_extract_skips_job_boards                  PASSED
tests/test_enricher.py::test_extract_skips_remoteok                    PASSED
tests/test_enricher.py::test_extract_skips_hackernews                  PASSED
tests/test_enricher.py::test_extract_email_from_text                   PASSED
tests/test_enricher.py::test_extract_email_ignores_examples            PASSED
tests/test_enricher.py::test_extract_email_not_found                   PASSED
tests/test_enricher.py::test_find_domain_from_direct_url               PASSED
tests/test_enricher.py::test_find_domain_returns_none_for_job_board    PASSED
tests/test_enricher.py::test_linkedin_extract_name_standard_format     PASSED
tests/test_enricher.py::test_linkedin_extract_name_pipe_format         PASSED
tests/test_enricher.py::test_linkedin_extract_role                     PASSED
tests/test_enricher.py::test_linkedin_clean_url_removes_params         PASSED
tests/test_enricher.py::test_linkedin_clean_company_name               PASSED

50 passed in 0.61s
```

All tests are offline — no real API calls made during `pytest`.

---

## Useful commands

```bash
# Container health
docker compose ps
docker compose logs -f postgres

# Postgres shell
docker exec -it devsignal_postgres psql -U radar -d devsignal

# Useful queries
\dt
SELECT job_source, COUNT(*) FROM opportunities GROUP BY job_source;
SELECT company, role, opportunity_score, recruiter_name, email
  FROM opportunities
  WHERE recruiter_name != '' OR email != ''
  ORDER BY opportunity_score DESC NULLS LAST LIMIT 10;

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

# Check n8n execution history (last 3 pipeline runs)
SELECT id, started_at, finished_at, jobs_found, jobs_new
  FROM scrape_runs ORDER BY id DESC LIMIT 3;

# Re-score all jobs
UPDATE opportunities SET opportunity_score = NULL, score_breakdown = NULL;
python run_scorer.py

# Re-enrich all jobs
UPDATE opportunities SET recruiter_name='', email='', linkedin_profile='';
python run_enricher.py --min-score 70

# Watchlist
python run_watchlist.py add "CRED" "iOS-first credit card rewards app"
python run_watchlist.py list
python run_watchlist.py check

# Check Hunter quota
python -c "from processors.hunter_client import HunterClient; print(HunterClient().get_remaining_quota())"

# Wipe everything and start fresh
docker compose down -v && docker compose up -d

# Run tests
python -m pytest tests/ -v
```

---

## Coming in Phase 8

Streamlit analytics dashboard with live stats from the database: score
distribution charts, source breakdown, enrichment coverage, and application
tracking UI. Deploys to Streamlit Cloud for a live public URL — ready to link
from a resume or LinkedIn profile.
