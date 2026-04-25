# db_sync.py
#
# PURPOSE:
#   Syncs top-scored jobs from local Postgres to Neon cloud Postgres.
#   Run this after scoring to keep the public dashboard fresh.
#
# USAGE:
#   python db_sync.py              # sync top 50 jobs
#   python db_sync.py --limit 100  # sync top 100
#
# PLACEMENT: project root

import sys
import os
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

LOCAL_DB = os.getenv(
    "DATABASE_URL",
    "postgresql://radar:radar_pass@localhost:5432/devsignal"
)
NEON_DB = os.getenv("NEON_DATABASE_URL", "")

# Minimal schema for Neon — same structure as local
NEON_SCHEMA = """
CREATE TABLE IF NOT EXISTS opportunities (
    id                  SERIAL PRIMARY KEY,
    date_found          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    job_source          TEXT            NOT NULL DEFAULT '',
    apply_link          TEXT            NOT NULL DEFAULT '',
    job_hash            VARCHAR(32)     NOT NULL UNIQUE,
    company             TEXT            NOT NULL DEFAULT '',
    role                TEXT            NOT NULL DEFAULT '',
    location            TEXT            NOT NULL DEFAULT '',
    remote              VARCHAR(10)     NOT NULL DEFAULT 'Unknown',
    visa_sponsorship    VARCHAR(10)     NOT NULL DEFAULT 'Unknown',
    experience_req      VARCHAR(100)    NOT NULL DEFAULT '',
    tech_stack          TEXT            NOT NULL DEFAULT '',
    description_raw     TEXT            NOT NULL DEFAULT '',
    recruiter_name      VARCHAR(200)    NOT NULL DEFAULT '',
    recruiter_role      VARCHAR(200)    NOT NULL DEFAULT '',
    linkedin_profile    TEXT            NOT NULL DEFAULT '',
    email               VARCHAR(200)    NOT NULL DEFAULT '',
    opportunity_score   SMALLINT,
    score_breakdown     JSONB,
    outreach_message    TEXT            NOT NULL DEFAULT '',
    applied             BOOLEAN         NOT NULL DEFAULT FALSE,
    response_status     VARCHAR(20)     NOT NULL DEFAULT '',
    interview_stage     VARCHAR(20)     NOT NULL DEFAULT '',
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scrape_runs (
    id           SERIAL PRIMARY KEY,
    started_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at  TIMESTAMPTZ,
    jobs_found   INTEGER NOT NULL DEFAULT 0,
    jobs_new     INTEGER NOT NULL DEFAULT 0,
    jobs_scored  INTEGER NOT NULL DEFAULT 0,
    errors       TEXT NOT NULL DEFAULT '',
    triggered_by VARCHAR(20) NOT NULL DEFAULT 'manual'
);

CREATE TABLE IF NOT EXISTS companies_watchlist (
    id               SERIAL PRIMARY KEY,
    company          VARCHAR(200) NOT NULL UNIQUE,
    ios_product_desc TEXT NOT NULL DEFAULT '',
    company_url      TEXT NOT NULL DEFAULT '',
    linkedin_url     TEXT NOT NULL DEFAULT '',
    funding_stage    VARCHAR(50) NOT NULL DEFAULT '',
    notes            TEXT NOT NULL DEFAULT '',
    added_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""


def sync(limit: int = 50):
    if not NEON_DB:
        print("ERROR: NEON_DATABASE_URL not set in .env")
        print("Get your connection string from neon.tech")
        return

    print("=" * 55)
    print("  DevSignal — Syncing to Neon cloud database")
    print("=" * 55)

    local_engine = create_engine(LOCAL_DB)
    neon_engine  = create_engine(NEON_DB)

    # ── Step 1: Apply schema to Neon ─────────────────────────────────────
    print("\n[Neon] Applying schema...")
    with neon_engine.begin() as conn:
        conn.execute(text(NEON_SCHEMA))
    print("[Neon] Schema ready")

    # ── Step 2: Fetch top jobs from local ─────────────────────────────────
    print(f"\n[Local] Fetching top {limit} scored jobs...")
    fetch_sql = text("""
        SELECT * FROM opportunities
        WHERE opportunity_score IS NOT NULL
        ORDER BY opportunity_score DESC NULLS LAST
        LIMIT :limit
    """)

    with local_engine.connect() as conn:
        result = conn.execute(fetch_sql, {"limit": limit})
        rows   = result.fetchall()
        cols   = result.keys()

    print(f"[Local] Got {len(rows)} jobs")

    if not rows:
        print("[Local] No scored jobs to sync. Run run_scorer.py first.")
        return

    # ── Step 3: Upsert into Neon ──────────────────────────────────────────
    print("\n[Neon] Upserting jobs...")

    import json

    upsert_sql = text("""
        INSERT INTO opportunities (
            date_found, job_source, apply_link, job_hash,
            company, role, location, remote, visa_sponsorship,
            experience_req, tech_stack, description_raw,
            recruiter_name, recruiter_role, linkedin_profile, email,
            opportunity_score, score_breakdown, outreach_message,
            applied, response_status, interview_stage
        ) VALUES (
            :date_found, :job_source, :apply_link, :job_hash,
            :company, :role, :location, :remote, :visa_sponsorship,
            :experience_req, :tech_stack, :description_raw,
            :recruiter_name, :recruiter_role, :linkedin_profile, :email,
            :opportunity_score, :score_breakdown, :outreach_message,
            :applied, :response_status, :interview_stage
        )
        ON CONFLICT (job_hash) DO UPDATE SET
            opportunity_score = EXCLUDED.opportunity_score,
            score_breakdown   = EXCLUDED.score_breakdown,
            outreach_message  = EXCLUDED.outreach_message,
            recruiter_name    = EXCLUDED.recruiter_name,
            linkedin_profile  = EXCLUDED.linkedin_profile,
            email             = EXCLUDED.email,
            applied           = EXCLUDED.applied,
            response_status   = EXCLUDED.response_status,
            interview_stage   = EXCLUDED.interview_stage
    """)

    col_names  = list(cols)
    upserted   = 0

    with neon_engine.begin() as conn:
        for row in rows:
            row_dict = dict(zip(col_names, row))

            # Convert JSONB to string if needed
            sb = row_dict.get("score_breakdown")
            if sb and not isinstance(sb, str):
                row_dict["score_breakdown"] = json.dumps(sb)

            try:
                conn.execute(upsert_sql, row_dict)
                upserted += 1
            except Exception as e:
                print(f"  Skip {row_dict.get('company', '?')}: {e}")

    # ── Step 4: Sync scrape runs ──────────────────────────────────────────
    print("\n[Neon] Syncing scrape run history...")
    runs_sql = text("SELECT * FROM scrape_runs ORDER BY started_at DESC LIMIT 20")

    with local_engine.connect() as conn:
        runs_result = conn.execute(runs_sql)
        runs_rows   = runs_result.fetchall()
        runs_cols   = runs_result.keys()

    runs_upsert = text("""
        INSERT INTO scrape_runs
            (started_at, finished_at, jobs_found, jobs_new, jobs_scored, errors, triggered_by)
        VALUES
            (:started_at, :finished_at, :jobs_found, :jobs_new, :jobs_scored, :errors, :triggered_by)
        ON CONFLICT DO NOTHING
    """)

    with neon_engine.begin() as conn:
        for run in runs_rows:
            try:
                conn.execute(runs_upsert, dict(zip(list(runs_cols), run)))
            except Exception:
                pass

    # ── Step 5: Sync watchlist ────────────────────────────────────────────
    watch_sql = text("SELECT * FROM companies_watchlist")
    with local_engine.connect() as conn:
        watch_result = conn.execute(watch_sql)
        watch_rows   = watch_result.fetchall()
        watch_cols   = watch_result.keys()

    if watch_rows:
        watch_upsert = text("""
            INSERT INTO companies_watchlist
                (company, ios_product_desc, company_url, linkedin_url, funding_stage, notes)
            VALUES (:company, :ios_product_desc, :company_url, :linkedin_url, :funding_stage, :notes)
            ON CONFLICT (company) DO NOTHING
        """)
        with neon_engine.begin() as conn:
            for w in watch_rows:
                try:
                    conn.execute(watch_upsert, dict(zip(list(watch_cols), w)))
                except Exception:
                    pass

    # ── Summary ───────────────────────────────────────────────────────────
    print(f"\n[Neon] Sync complete — {upserted}/{len(rows)} jobs upserted")
    print("[Neon] Your public dashboard now has fresh data")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=50)
    args = parser.parse_args()
    sync(limit=args.limit)