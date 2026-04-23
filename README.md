# DevSignal

> AI-powered iOS internship radar — scrapes 4 job platforms, parses and filters
> results intelligently, persists everything to PostgreSQL, scores every
> opportunity with an 8-factor AI model, and fires recruiter outreach automatically.

```
pipeline:  scrape → parse → filter → deduplicate → store → score → notify → track
progress:  ████████████████░░░░░░░░  Phase 5 of 8 complete
```

---

## What it does

DevSignal runs a fully automated job discovery pipeline targeted at iOS internship
roles. Every 12 hours (Phase 7), it pulls from four job platforms, extracts
structured fields from raw description text, drops anything that doesn't match
the target profile, deduplicates against the full history in PostgreSQL, and saves
only genuinely new opportunities.

Each new job is immediately scored 0–100 by an 8-factor AI model (free via Groq's
Llama 3.1 API), with a per-factor breakdown explaining the score. Jobs above 65
get a personalised recruiter outreach message generated automatically. Jobs above
85 fire an immediate Telegram alert.

Later phases add recruiter enrichment, n8n automation, and a Streamlit dashboard —
but the scoring and outreach foundation is already production-grade.

---

## Status

| Phase | What | Status |
|-------|------|--------|
| 1 | Mac setup · project scaffold · RemoteOK scraper | ✅ Done |
| 2 | PostgreSQL · Docker · full persistence layer | ✅ Done |
| 3 | 3 new scrapers · job parser · filter engine · unit tests | ✅ Done |
| 4 | Telegram notifications | ✅ Done |
| 5 | AI scoring via Groq free API (8-factor model) | ✅ Done |
| 6 | Recruiter enrichment · outreach message generation | 🔲 Next |
| 7 | n8n automation — runs every 12 hours | 🔲 |
| 8 | Streamlit dashboard · portfolio polish | 🔲 |

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.12 |
| Database | PostgreSQL 16 (Docker) |
| Orchestration | n8n (Docker) |
| AI scoring | Groq API · Llama 3.1 8B (free tier) |
| Notifications | Telegram Bot API |
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
│                        generated for jobs scoring >= 65     │
│                                                             │
│  run_scorer.py  ←──  standalone batch scorer                │
└───────────┬─────────────────────────────────────────────────┘
            │  scores + outreach written back to DB
            ▼
┌─────────────────────────────────────────────────────────────┐
│  NOTIFICATIONS  (notifications/)                            │
│                                                             │
│  telegram_bot.py  — digest of top scored jobs               │
│                     immediate alert for score >= 85         │
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
├── ai/                          # ── Phase 5 ──────────────────────────────
│   ├── __init__.py
│   ├── ios_classifier.py        # heuristic + Llama 3.1 iOS product detection
│   ├── scorer.py                # 8-factor scoring model (0-100) with breakdown
│   └── outreach_generator.py   # personalised recruiter messages (score >= 65)
│
├── notifications/
│   └── telegram_bot.py          # digest + high-score alerts
│
├── config/
│   ├── settings.py              # DATABASE_URL, GROQ_API_KEY, thresholds, env vars
│   └── keywords.py              # iOS keyword lists, exclude terms, visa phrases
│
├── tests/
│   ├── test_scrapers.py         # hash consistency, normalization, field detection
│   ├── test_processors.py       # parser + filter unit tests
│   └── test_scorer.py           # scorer + classifier tests (mocked, no API calls)
│
├── docker-compose.yml           # PostgreSQL 16 + n8n, health checks, volumes
├── run_scraper.py               # manual pipeline entry point (auto-scores new jobs)
├── run_scorer.py                # standalone scorer — python run_scorer.py [--limit N]
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
  opportunity_score    SMALLINT CHECK 0-100        -- filled by AI scorer (Phase 5)
  score_breakdown      JSONB                       -- per-factor scores (Phase 5)
  outreach_message     TEXT                        -- generated for score >= 65
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

Jobs scoring **≥ 65** receive an auto-generated personalized recruiter outreach
message (under 280 characters, references the company's specific iOS product).
Jobs scoring **≥ 85** trigger an immediate Telegram alert in addition to the
regular digest.

The entire AI layer runs on **Groq's free tier** — 14,400 requests/day,
no credit card required.

---

## Setup

**Prerequisites:** Python 3.12, Docker Desktop, Groq API key (free at console.groq.com)

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
# Fill in: DATABASE_URL, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, GROQ_API_KEY

# 4. Start database
docker compose up -d
# Wait ~30s for the health check to pass
docker compose ps   # postgres should show (healthy)

# 5. Confirm schema
python storage/migrations.py
# Expected: "All done." with all 3 tables listed

# 6. Run
python run_scraper.py
# Scrapes, filters, stores, then automatically scores new jobs
```

Run it twice. The second run should insert 0 new jobs — deduplication is working
correctly if the database total stays flat. Scores from the first run are
preserved.

To score existing unscored jobs without running the full scrape:

```bash
python run_scorer.py            # score all unscored jobs
python run_scorer.py --limit 5  # test with 5 jobs first
```

---

## Pipeline walkthrough

```
python run_scraper.py

  DevSignal — Scraper Pipeline  (Phase 5)
  ══════════════════════════════════════════════════════════════

  [DB] Scrape run #4 started

  Raw jobs by source:
    RemoteOK                  8 jobs
    HackerNews                12 jobs
    YC WorkAtAStartup         5 jobs
    Remotive                  9 jobs
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
  [Deduplicator] Result: 13 genuinely new jobs

  [DB] Inserted 13 new jobs

  ── AI Scorer ──────────────────────────────────────────────────

  [Classifier] Checking which companies build iOS products...
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
    ...

  ══════════════════════════════════════════════════════════════
  Scoring Complete
  ══════════════════════════════════════════════════════════════

  Jobs scored:      13
  Average score:    54.3/100
  Score >= 70:      4 jobs
  Score >= 85:      1 jobs (alerts sent)

  Top 5 opportunities:
  Score    Company                   Role
  ──────── ───────────────────────── ──────────────────────────────
  90       YC S24 Mobile Startup     Junior iOS Developer
  74       FitTrack                  iOS Intern
  68       nooro                     iOS Developer Intern
  ...

  Database totals:
    Total stored:     34
    Scored:           34
    Remote jobs:      28
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

**Heuristic-first classification** — `IOSClassifier` checks for Swift/SwiftUI/Xcode
keywords locally before making a Groq API call. Obvious cases (strong iOS signals
or clear non-iOS signals) are resolved instantly with zero quota cost. The API is
only called for genuinely ambiguous descriptions.

**Immediate score persistence** — `run_scorer.py` writes each score to the database
as soon as it's received, not in a batch at the end. If Groq rate-limits mid-run
or the script is interrupted, all previously scored jobs are preserved and the
next run resumes from where it left off (`get_unscored_jobs()` skips already-scored rows).

**Outreach threshold** — messages are only generated for jobs scoring ≥ 65. Below
that threshold, the quality signal is too weak to justify the API call and the
recruiter's attention.

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
tests/test_scorer.py::test_scorer_parse_valid_json                 PASSED
tests/test_scorer.py::test_scorer_parse_json_with_code_block       PASSED
tests/test_scorer.py::test_scorer_score_clamped_to_range           PASSED
tests/test_scorer.py::test_scorer_fallback_on_bad_json             PASSED
tests/test_scorer.py::test_scorer_fallback_scores_correctly        PASSED
tests/test_scorer.py::test_classifier_heuristic_swift_is_ios       PASSED
tests/test_scorer.py::test_classifier_heuristic_react_native_not_ios PASSED
tests/test_scorer.py::test_classifier_heuristic_unsure_returns_none  PASSED
tests/test_scorer.py::test_classifier_parse_valid_response         PASSED
tests/test_scorer.py::test_classifier_parse_false_response         PASSED
tests/test_scorer.py::test_classifier_parse_invalid_json_falls_back PASSED

35 passed in 0.44s
```

Scorer tests use mocking throughout — no real Groq API calls are made during
`pytest`. The full suite runs in under half a second.

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
SELECT company, role, opportunity_score, remote, visa_sponsorship
  FROM opportunities ORDER BY opportunity_score DESC NULLS LAST LIMIT 10;
SELECT id, jobs_found, jobs_new FROM scrape_runs ORDER BY started_at DESC;

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

# Re-score all jobs (wipes existing scores first)
UPDATE opportunities SET opportunity_score = NULL, score_breakdown = NULL;
python run_scorer.py

# Wipe everything and start fresh
docker compose down -v && docker compose up -d

# Run tests
python -m pytest tests/ -v
```

---

## Coming in Phase 6

Recruiter enrichment. For each high-scoring company, DevSignal finds the iOS
team lead or recruiter on LinkedIn and discovers their email pattern via Hunter.io
(free tier: 25 lookups/month). The outreach messages generated in Phase 5 then
have a real name and direct email address — turning a generic message into a
targeted cold email.
