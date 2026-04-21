# DevSignal

> AI-powered iOS internship radar. Discovers opportunities across 13 job platforms,
> scores them with an 8-factor AI model, generates personalized recruiter outreach,
> and tracks every application — running automatically every 12 hours.

## Status
🔨 Active development — Phase 2 of 8 complete

## Tech stack
Python 3.12 · PostgreSQL 16 · Docker · n8n · Claude API · Streamlit · Telegram

## Phases
- [x] Phase 1 — Mac setup, project structure, RemoteOK scraper
- [x] Phase 2 — PostgreSQL database, Docker, full persistence layer
- [ ] Phase 3 — More scrapers + filters (HackerNews, YC, Indeed)
- [ ] Phase 4 — Telegram notifications
- [ ] Phase 5 — AI scoring (Claude API)
- [ ] Phase 6 — Recruiter enrichment + outreach generation
- [ ] Phase 7 — n8n automation (runs every 12 hours)
- [ ] Phase 8 — Streamlit dashboard + portfolio polish

## What's working right now
- Scrapes RemoteOK for iOS/Swift jobs on demand
- Hashes every job (company + role + URL → MD5) to fingerprint it permanently
- Persists all jobs to PostgreSQL — survives Terminal restarts, reboots, everything
- Deduplicates across runs — the same job is never inserted twice, ever
- Logs every pipeline run with counts and timestamps to `scrape_runs`
- Prints a clean summary table after every run

## Project structure
```
devsignal/
├── scrapers/
│   └── remoteok_scraper.py     # RemoteOK → normalized job dicts
├── processors/
│   └── deduplicator.py         # hash-based dedup (DB + in-batch)
├── storage/
│   ├── schema.sql              # 3 tables, 6 indexes, auto-updated trigger
│   ├── db_client.py            # connection pool + full CRUD layer
│   └── migrations.py           # apply/re-apply schema manually
├── config/
│   └── settings.py             # DATABASE_URL + env config
├── docker-compose.yml          # Postgres 16 + n8n containers
└── run_scraper.py              # manual pipeline entry point
```

## Database schema
```
opportunities        — every job found, deduplicated by hash
  21 columns: company, role, location, remote, visa_sponsorship,
              tech_stack, description_raw, opportunity_score,
              recruiter info, outreach_message, application tracking…

companies_watchlist  — iOS companies with no internship posted yet

scrape_runs          — log of every pipeline run (found / new / errors)
```

## Setup

### Prerequisites
- Python 3.12
- Docker Desktop (running)

### 1. Clone and create virtual environment
```bash
git clone https://github.com/yourname/devsignal.git
cd devsignal
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Start the database
```bash
docker compose up -d
```
This starts PostgreSQL 16 and n8n. Postgres auto-runs `storage/schema.sql` on
first boot — no manual table creation needed.

Wait for the health check to pass:
```bash
docker compose ps
# devsignal_postgres should show (healthy)
```

### 3. Verify the schema
```bash
python storage/migrations.py
# Expected: "All done." with all 3 tables listed
```

### 4. Run the pipeline
```bash
python run_scraper.py
```

Run it a second time immediately to confirm deduplication — the result should
be `0 new jobs` with the database total unchanged.

## Key design decisions

**Connection pool over raw connections** — `db_client.py` uses
`psycopg2.pool.ThreadedConnectionPool` (1–5 connections). No per-query
connection overhead; pool is created once at import time and shared everywhere
via a singleton.

**Hash-based deduplication** — every job gets an MD5 fingerprint of
`company + role + url`. Before any insert, `deduplicator.py` fetches all
existing hashes in one query and checks the batch against a Python `set` (O(1)
lookup). `ON CONFLICT (job_hash) DO NOTHING` in the INSERT is the final safety
net.

**Repository pattern** — all SQL lives in `storage/db_client.py`. No other
file imports `psycopg2` directly. Schema changes and query optimisations happen
in one place.

**Docker over native Postgres** — Postgres runs in a sealed container. Reset
the entire database with `docker compose down -v`. Share the exact setup with
one file. Never conflicts with anything else on the machine.

## Useful commands

```bash
# Check container health
docker compose ps

# Tail live logs
docker compose logs -f postgres

# Open a Postgres shell
docker exec -it devsignal_postgres psql -U radar -d devsignal

# Wipe the database and start fresh (WARNING: deletes all data)
docker compose down -v && docker compose up -d
```

## Coming in Phase 3
Two more scrapers (HackerNews via Algolia API, YC WorkAtAStartup), a
`job_parser.py` to extract structured data from messy descriptions, and a
`filter_engine.py` to enforce experience-level and role-type rules. By the end
of Phase 3, three job sources will be feeding the database simultaneously.
