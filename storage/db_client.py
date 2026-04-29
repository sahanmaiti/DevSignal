# storage/db_client.py
#
# PURPOSE:
#   The single database interface for all of DevSignal.
#   Every read and write to PostgreSQL goes through this class.
#   No other file in the project imports psycopg2 directly.
#
# DESIGN — Repository Pattern:
#   By centralising all DB logic here, if we ever need to change
#   something about how we talk to the database, we change it in
#   one place. Nothing else breaks.
#
# USAGE:
#   from storage.db_client import db   ← import the singleton
#
#   db.insert_jobs(list_of_dicts)      ← save scraped jobs
#   db.get_unscored_jobs()             ← fetch jobs needing AI scores
#   db.hash_exists("abc123")           ← check for duplicates
#
# PLACEMENT: storage/db_client.py

import psycopg2
import psycopg2.extras       # RealDictCursor: rows returned as dicts, not tuples
from psycopg2 import pool    # connection pool
from contextlib import contextmanager
import json
import os
import sys

# Add project root to path so settings.py can be imported
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import DATABASE_URL


class DBClient:
    """
    Thread-safe PostgreSQL client for DevSignal.

    Uses a connection pool to avoid the overhead of opening
    a new connection for every query.

    All methods are designed to match the columns in schema.sql exactly.
    """

    def __init__(self, min_connections: int = 1, max_connections: int = 5):
        """
        Creates the connection pool.
        Called once when the module is first imported.

        min_connections: always keep at least this many connections open
        max_connections: never open more than this many simultaneously
        """
        print(f"[DB] Connecting to PostgreSQL...")
        print(f"[DB] URL: {DATABASE_URL[:45]}...")

        try:
            self._pool = pool.ThreadedConnectionPool(
                minconn=min_connections,
                maxconn=max_connections,
                dsn=DATABASE_URL,
            )
            print(f"[DB] Connection pool ready ({min_connections}-{max_connections} connections)")

        except psycopg2.OperationalError as e:
            print(f"\n[DB] FATAL: Could not connect to PostgreSQL.")
            print(f"[DB] Error: {e}")
            print(f"\n[DB] Checklist:")
            print(f"  1. Is Docker running?  →  open Docker Desktop")
            print(f"  2. Are containers up?  →  docker compose ps")
            print(f"  3. Is Postgres healthy? →  docker compose logs postgres")
            print(f"  4. Is port 5432 free?  →  lsof -i :5432")
            raise

    # ─────────────────────────────────────────────────────────────────────
    # CONNECTION CONTEXT MANAGER
    # ─────────────────────────────────────────────────────────────────────

    @contextmanager
    def get_conn(self):
        """
        Borrows a connection from the pool for the duration of a `with` block.

        Usage:
            with db.get_conn() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT COUNT(*) FROM opportunities")
                    print(cur.fetchone())

        On success: automatically commits the transaction.
        On error:   automatically rolls back (no partial data saved).
        Always:     returns the connection to the pool when done.
        """
        conn = self._pool.getconn()
        try:
            yield conn
            conn.commit()             # success → save changes
        except Exception:
            conn.rollback()           # error → undo changes
            raise                     # re-raise so the caller sees the error
        finally:
            self._pool.putconn(conn)  # always return to pool

    # ─────────────────────────────────────────────────────────────────────
    # DEDUPLICATION METHODS
    # Called by processors/deduplicator.py
    # ─────────────────────────────────────────────────────────────────────

    def hash_exists(self, job_hash: str) -> bool:
        """
        Returns True if a job with this hash is already in the database.

        Uses the idx_opp_hash index — essentially instant even with
        millions of rows.
        """
        sql = "SELECT 1 FROM opportunities WHERE job_hash = %s LIMIT 1"
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (job_hash,))
                return cur.fetchone() is not None

    def get_all_hashes(self) -> set:
        """
        Returns ALL existing job hashes as a Python set.

        Used by deduplicator.py to bulk-check an entire scrape batch
        in one database round-trip instead of one query per job.

        Why a set? set lookup is O(1) — checking if hash X is in a set
        of 50,000 hashes takes the same time as checking a set of 10.
        A list lookup is O(n) — it gets slower as the list grows.
        """
        sql = "SELECT job_hash FROM opportunities"
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql)
                # Set comprehension: creates a set from the first column of each row
                return {row[0] for row in cur.fetchall()}

    # ─────────────────────────────────────────────────────────────────────
    # WRITE METHODS
    # ─────────────────────────────────────────────────────────────────────

    def insert_jobs(self, jobs: list) -> int:
        """
        Inserts a list of job dicts into the opportunities table.

        Returns the number of rows actually inserted.

        Key design decisions:
        1. ON CONFLICT (job_hash) DO NOTHING
        If a hash already exists, skip it silently. No error, no crash.
        This is the final safety net after deduplication.

        2. execute_values() instead of a loop
        Sends all rows in a single SQL statement rather than one INSERT
        per job. 50x faster for large batches.

        3. %s placeholders — NEVER use f-strings or .format() for SQL values.
        Psycopg2's %s is parameterised — it prevents SQL injection and
        handles special characters (quotes, backslashes) automatically.
        """
        if not jobs:
            return 0

        # Build tuples in column order matching the INSERT statement below
        rows = []
        for j in jobs:
            rows.append((
                j.get("job_source", "")[:50],
                j.get("apply_link", ""),              # TEXT — no limit
                j.get("job_hash", "")[:32],
                j.get("company", "")[:200],
                j.get("role", "")[:300],
                j.get("location", "")[:200],
                j.get("remote", "Unknown")[:10],
                j.get("visa_sponsorship", "Unknown")[:10],
                j.get("experience_req", "")[:100],
                j.get("tech_stack", ""),               # TEXT — no limit
                j.get("description_raw", ""),          # TEXT — no limit
            ))

        sql = """
            INSERT INTO opportunities (
                job_source, apply_link, job_hash,
                company, role, location,
                remote, visa_sponsorship, experience_req,
                tech_stack, description_raw
            )
            VALUES %s
            ON CONFLICT (job_hash) DO NOTHING
        """

        with self.get_conn() as conn:
            with conn.cursor() as cur:
                psycopg2.extras.execute_values(cur, sql, rows)
                # rowcount = number of rows actually inserted
                # (rows skipped by ON CONFLICT are not counted)
                inserted = cur.rowcount
                return inserted if inserted > 0 else len(rows)

    def update_score(self, job_id: int, score: int,
                    breakdown: dict, outreach_message: str) -> None:
        """
        Writes AI scoring results back to a specific job row.
        Called by ai/scorer.py after Claude API returns results.

        breakdown is a dict like:
        {"remote": 20, "visa": 15, "swift_match": 15, "ios_product": 15,
        "experience": 10, "salary": 10, "startup": 10, "recency": 5}
        """
        sql = """
            UPDATE opportunities
            SET opportunity_score = %s,
                score_breakdown   = %s,
                outreach_message  = %s
            WHERE id = %s
        """
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (
                    score,
                    json.dumps(breakdown),   # dict → JSON string
                    outreach_message,
                    job_id,
                ))

    def update_recruiter(self, job_id: int, recruiter_name: str,
                        recruiter_role: str, linkedin_profile: str,
                        email: str) -> None:
        """
        Writes recruiter enrichment data to a specific job row.
        Called by processors/enricher.py (Phase 6).
        """
        sql = """
            UPDATE opportunities
            SET recruiter_name   = %s,
                recruiter_role   = %s,
                linkedin_profile = %s,
                email            = %s
            WHERE id = %s
        """
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (
                    recruiter_name or "",
                    recruiter_role or "",
                    linkedin_profile or "",
                    email or "",
                    job_id,
                ))

    def update_application(self, job_id: int, applied: bool,
                        response_status: str = "",
                        interview_stage: str = "") -> None:
        """
        Updates application tracking fields.
        Called from the Streamlit dashboard or manually.
        """
        sql = """
            UPDATE opportunities
            SET applied          = %s,
                response_status  = %s,
                interview_stage  = %s
            WHERE id = %s
        """
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (applied, response_status, interview_stage, job_id))

    # ─────────────────────────────────────────────────────────────────────
    # READ METHODS
    # ─────────────────────────────────────────────────────────────────────

    def get_unscored_jobs(self) -> list:
        """
        Returns all jobs that don't have an AI score yet.
        Called by the AI workflow to know what needs scoring.

        RealDictCursor makes rows come back as dicts instead of tuples.
        So you get job["company"] instead of job[3].
        """
        sql = """
            SELECT
                id, company, role, location, remote,
                visa_sponsorship, experience_req, tech_stack,
                description_raw, apply_link, date_found, job_source
            FROM opportunities
            WHERE opportunity_score IS NULL
            ORDER BY date_found DESC
        """
        with self.get_conn() as conn:
            with conn.cursor(
                cursor_factory=psycopg2.extras.RealDictCursor
            ) as cur:
                cur.execute(sql)
                return [dict(row) for row in cur.fetchall()]

    def get_top_opportunities(self, min_score: int = 45,   # was 70
                            limit: int = 5) -> list:
        """
        Returns the top N scoring jobs from the last 12 hours.
        Called by notifications/telegram_bot.py to build the digest.
        """
        sql = """
            SELECT
                id, company, role, location, remote, visa_sponsorship,
                opportunity_score, recruiter_name, linkedin_profile,
                apply_link, outreach_message, date_found, job_source
            FROM opportunities
            WHERE opportunity_score >= %s
            AND date_found >= NOW() - INTERVAL '12 hours'
            ORDER BY opportunity_score DESC
            LIMIT %s
        """
        with self.get_conn() as conn:
            with conn.cursor(
                cursor_factory=psycopg2.extras.RealDictCursor
            ) as cur:
                cur.execute(sql, (min_score, limit))
                return [dict(row) for row in cur.fetchall()]

    def get_all_opportunities(self, min_score: int = 0,
                            remote_only: bool = False,
                            unapplied_only: bool = False) -> list:
        """
        Returns opportunities with optional filters.
        Used by the Streamlit dashboard.
        """
        conditions = []
        params = []

        if min_score > 0:
            conditions.append("opportunity_score >= %s")
            params.append(min_score)

        if remote_only:
            conditions.append("remote = 'Yes'")

        if unapplied_only:
            conditions.append("applied = FALSE")

        where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

        sql = f"""
            SELECT *
            FROM opportunities
            {where}
            ORDER BY date_found DESC
        """
        with self.get_conn() as conn:
            with conn.cursor(
                cursor_factory=psycopg2.extras.RealDictCursor
            ) as cur:
                cur.execute(sql, params)
                return [dict(row) for row in cur.fetchall()]

    def get_stats(self) -> dict:
        """
        Returns aggregate statistics for the dashboard summary cards.
        Runs one SQL query instead of loading all rows into Python —
        the database does the counting, which is far more efficient.
        """
        sql = """
            SELECT
                COUNT(*)                                             AS total_jobs,
                COUNT(*) FILTER (WHERE applied = TRUE)              AS total_applied,
                COUNT(*) FILTER (WHERE response_status = 'Replied') AS total_responses,
                COUNT(*) FILTER (WHERE interview_stage != '')        AS total_interviews,
                ROUND(AVG(opportunity_score)::numeric, 1)           AS avg_score,
                COUNT(*) FILTER (WHERE remote = 'Yes')              AS remote_count,
                COUNT(*) FILTER (WHERE opportunity_score IS NULL)   AS unscored_count
            FROM opportunities
        """
        with self.get_conn() as conn:
            with conn.cursor(
                cursor_factory=psycopg2.extras.RealDictCursor
            ) as cur:
                cur.execute(sql)
                row = cur.fetchone()
                return dict(row) if row else {}

    # ─────────────────────────────────────────────────────────────────────
    # SCRAPE RUN LOGGING
    # ─────────────────────────────────────────────────────────────────────

    def start_scrape_run(self, triggered_by: str = "manual") -> int:
        """
        Inserts a new row into scrape_runs and returns its ID.
        Call this at the very beginning of each pipeline run.
        """
        sql = """
            INSERT INTO scrape_runs (triggered_by)
            VALUES (%s)
            RETURNING id
        """
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (triggered_by,))
                run_id = cur.fetchone()[0]
                print(f"[DB] Scrape run #{run_id} started")
                return run_id

    def finish_scrape_run(self, run_id: int, jobs_found: int,
                          jobs_new: int, jobs_scored: int = 0,
                          errors: str = "") -> None:
        """
        Updates the scrape run log with final counts.
        Call this at the end of each pipeline run.
        """
        sql = """
            UPDATE scrape_runs
            SET finished_at = NOW(),
                jobs_found  = %s,
                jobs_new    = %s,
                jobs_scored = %s,
                errors      = %s
            WHERE id = %s
        """
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (jobs_found, jobs_new, jobs_scored, errors, run_id))
                print(f"[DB] Scrape run #{run_id} finished — "
                      f"{jobs_found} found, {jobs_new} new")

    # ─────────────────────────────────────────────────────────────────────
    # WATCHLIST METHODS
    # ─────────────────────────────────────────────────────────────────────

    def add_to_watchlist(self, company: str, ios_product_desc: str = "",
                         company_url: str = "", linkedin_url: str = "",
                         funding_stage: str = "", notes: str = "") -> None:
        """Adds a company to the watchlist. Silently ignores duplicates."""
        sql = """
            INSERT INTO companies_watchlist
                (company, ios_product_desc, company_url,
                 linkedin_url, funding_stage, notes)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (company) DO NOTHING
        """
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (company, ios_product_desc, company_url,
                                  linkedin_url, funding_stage, notes))

    def get_watchlist(self) -> list:
        """Returns all companies on the watchlist."""
        sql = "SELECT * FROM companies_watchlist ORDER BY added_at DESC"
        with self.get_conn() as conn:
            with conn.cursor(
                cursor_factory=psycopg2.extras.RealDictCursor
            ) as cur:
                cur.execute(sql)
                return [dict(row) for row in cur.fetchall()]

    # ─────────────────────────────────────────────────────────────────────
    # CLEANUP
    # ─────────────────────────────────────────────────────────────────────

    def close(self):
        """Closes all connections in the pool. Call on app shutdown."""
        self._pool.closeall()
        print("[DB] Connection pool closed.")


# ─────────────────────────────────────────────────────────────────────────
# SINGLETON INSTANCE
#
# Create one shared instance at module import time.
# Every file that does `from storage.db_client import db` gets
# the same instance — the pool is only created once.
# ─────────────────────────────────────────────────────────────────────────
db = DBClient()