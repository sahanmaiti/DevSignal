# DevSignal

> AI-powered iOS internship radar — scrapes 4 job platforms, parses and filters
> results intelligently, persists everything to PostgreSQL, and will score every
> opportunity with an 8-factor AI model and fire recruiter outreach automatically.

```
pipeline:  scrape → parse → filter → deduplicate → store → score → notify → track
progress:  ████████████░░░░░░░░░░░░  Phase 3 of 8 complete
```

---

## What it does

DevSignal runs a fully automated job discovery pipeline targeted at iOS internship
roles. Every 12 hours (Phase 7), it pulls from four job platforms, extracts
structured fields from raw description text, drops anything that doesn't match
the target profile, deduplicates against the full history in PostgreSQL, and saves
only genuinely new opportunities.

Later phases add Claude-powered scoring, recruiter enrichment, Telegram digests,
and a Streamlit dashboard — but the data foundation is already production-grade.

---

## Status

| Phase | What | Status |
|-------|------|--------|
| 1 | Mac setup · project scaffold · RemoteOK scraper | ✅ Done |
| 2 | PostgreSQL · Docker · full persistence layer | ✅ Done |
| 3 | 3 new scrapers · job parser · filter engine · unit tests | ✅ Done |
| 4 | Telegram notifications | 🔲 Next |
| 5 | AI scoring via Claude API (8-factor model) | 🔲 |
| 6 | Recruiter enrichment · outreach message generation | 🔲 |
| 7 | n8n automation — runs every 12 hours | 🔲 |
| 8 | Streamlit dashboard · portfolio polish | 🔲 |

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.12 |
| Database | PostgreSQL 16 (Docker) |
| Orchestration | n8n (Docker) |
| AI scoring | Claude API (Phase 5) |
| Notifications | Telegram Bot API (Phase 4) |
| Dashboard | Streamlit (Phase 8) |
| Testing | pytest |

---

## Architecture

```
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
└─────────────────────────────────────────────────────────────┘
```

---

## Project structure

```
devsignal/
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
│   └── deduplicator.py          # cross-run hash deduplication
│
├── storage/
│   ├── schema.sql               # DDL: tables, indexes, updated_at trigger
│   ├── db_client.py             # psycopg2 pool + repository pattern
│   └── migrations.py            # apply/re-apply schema manually
│
├── config/
│   ├── settings.py              # DATABASE_URL, thresholds, env vars
│   └── keywords.py              # iOS keyword lists, exclude terms, visa phrases
│
├── tests/
│   ├── test_scrapers.py         # hash consistency, normalization, field detection
│   └── test_processors.py       # parser + filter unit tests (24 tests total)
│
├── docker-compose.yml           # PostgreSQL 16 + n8n, health checks, volumes
├── run_scraper.py               # manual pipeline entry point
└── requirements.txt
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
  opportunity_score    SMALLINT CHECK 0-100        -- filled in Phase 5
  score_breakdown      JSONB                       -- per-factor scores
  outreach_message     TEXT                        -- generated in Phase 6
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

## Setup

**Prerequisites:** Python 3.12, Docker Desktop

```bash
# 1. Clone
git clone https://github.com/yourname/devsignal.git
cd devsignal

# 2. Virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Start database
docker compose up -d
# Wait ~30s for the health check to pass
docker compose ps   # postgres should show (healthy)

# 4. Confirm schema
python storage/migrations.py
# Expected: "All done." with all 3 tables listed

# 5. Run
python run_scraper.py
```

Run it twice. The second run should insert 0 jobs — deduplication is working
correctly if the database total stays flat.

---

## Pipeline walkthrough

```
python run_scraper.py

  DevSignal — Scraper Pipeline  (Phase 3)
  ══════════════════════════════════════════════════════════════

  [DB] Scrape run #3 started

  Raw jobs by source:
    RemoteOK                  8 jobs
    HackerNews                12 jobs
    YC WorkAtAStartup         5 jobs
    Rmotive                    9 jobs
    ─────────────────────────────────
    TOTAL                     34 jobs

  [Parser] Parsed 34 jobs:
  [Parser]   Experience extracted: 19
  [Parser]   Remote confirmed:     22
  [Parser]   Visa status known:    8

  [Filter] 34 jobs in → 21 jobs out
  [Filter]   Dropped 6 senior title roles
  [Filter]   Dropped 4 over-experience roles
  [Filter]   Dropped 3 non-iOS roles

  [Deduplicator] Checking 21 jobs against database...
  [Deduplicator] Found 8 existing jobs in database
  [Deduplicator] Result: 13 genuinely new jobs

  [DB] Inserted 13 new jobs

  Database totals:
    Total stored:     21
    Unscored:         21  ← ready for Phase 5 AI scoring
    Remote jobs:      17
    Applied:          0
```

---

## Key design decisions

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
tests/test_scrapers.py::test_hash_is_consistent                    PASSED
tests/test_scrapers.py::test_hash_is_different_for_different_jobs  PASSED
tests/test_scrapers.py::test_normalize_has_all_required_fields     PASSED
tests/test_scrapers.py::test_remoteok_is_ios_relevant              PASSED
tests/test_scrapers.py::test_remoteok_salary_format                PASSED
tests/test_scrapers.py::test_hn_first_line_parsing                 PASSED
tests/test_processors.py::test_extract_experience_range            PASSED
tests/test_processors.py::test_extract_remote_yes                  PASSED
tests/test_processors.py::test_extract_visa_no                     PASSED
tests/test_processors.py::test_filter_drops_senior_title           PASSED
tests/test_processors.py::test_filter_keeps_when_exp_unknown       PASSED
... (24 total)

24 passed in 0.31s
```

---

## Useful commands

```bash
# Container health
docker compose ps
docker compose logs -f postgres

# Postgres shell
docker exec -it devsignal_postgres psql -U radar -d devsignal

# Useful queries
\dt                                         -- list tables
SELECT job_source, COUNT(*) FROM opportunities GROUP BY job_source;
SELECT company, role, remote, visa_sponsorship FROM opportunities LIMIT 10;
SELECT id, jobs_found, jobs_new FROM scrape_runs ORDER BY started_at DESC;

# Wipe everything and start fresh
docker compose down -v && docker compose up -d

# Run tests
python -m pytest tests/ -v
```

---

## Coming in Phase 4

Telegram notifications. After each pipeline run, a bot fires a digest to your
phone — top 5 opportunities ranked by raw score signals, with company, role,
remote status, and apply link. No more opening a terminal to check if anything
new came in.
