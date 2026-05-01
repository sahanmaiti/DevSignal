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
#   from storage.db_client import db_client   ← primary import for API layer
#   from storage.db_client import db          ← legacy alias (still works)
#
#   db_client.insert_jobs(list_of_dicts)
#   db_client.get_unscored_jobs()
#   db_client.hash_exists("abc123")
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
            with self.get_conn() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) FROM jobs")
                print(cursor.fetchone())

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
                return {row[0] for row in cur.fetchall()}

    # ─────────────────────────────────────────────────────────────────────
    # WRITE METHODS (original — used by scraper pipeline)
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

        rows = []
        for j in jobs:
            rows.append((
                j.get("job_source", "")[:50],
                j.get("apply_link", ""),
                j.get("job_hash", "")[:32],
                j.get("company", "")[:200],
                j.get("role", "")[:300],
                j.get("location", "")[:200],
                j.get("remote", "Unknown")[:10],
                j.get("visa_sponsorship", "Unknown")[:10],
                j.get("experience_req", "")[:100],
                j.get("tech_stack", ""),
                j.get("description_raw", ""),
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
                inserted = cur.rowcount
                return inserted if inserted > 0 else len(rows)

    def update_score(self, job_id: int, score: int,
                    breakdown: dict, outreach_message: str) -> None:
        """
        Writes AI scoring results back to a specific job row.
        Called by ai/scorer.py after Groq API returns results.
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
                    json.dumps(breakdown),
                    outreach_message,
                    job_id,
                ))

    def update_recruiter(self, job_id: int, recruiter_name: str,
                        recruiter_role: str, linkedin_profile: str,
                        email: str) -> None:
        """
        Writes recruiter enrichment data to a specific job row.
        Called by processors/enricher.py.
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

    def update_application_status(self, job_id: int, status: str) -> None:
        """
        Updates the denormalized application_status column on a job row
        in the `jobs` table.

        Called by POST /jobs/{job_id}/apply in the API layer to keep
        the Streamlit dashboard in sync when the iOS app marks a job
        as applied.

        NOTE: This is separate from upsert_application() which writes to
        the dedicated `applications` table (source of truth for iOS tracker).
        This method keeps the legacy `jobs.application_status` column current
        so the existing Streamlit dashboard requires zero changes.
        """
        with self.get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute(
            "UPDATE opportunities SET response_status = %s WHERE id = %s",
            (status, job_id)
        )

    def update_application_legacy(self, job_id: int, applied: bool,
                                response_status: str = "",
                                interview_stage: str = "") -> None:
        """
        Updates application tracking fields on the opportunities table.
        Used by the Streamlit dashboard directly.

        Renamed from update_application() to avoid a name collision with the
        new update_application() method used by the iOS API layer
        (PATCH /applications/{id}).

        ⚠️  If any of your existing code calls db.update_application(job_id, ...),
        update those call sites to db.update_application_legacy(job_id, ...).
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
    # READ METHODS (original — used by scraper pipeline + Streamlit)
    # ─────────────────────────────────────────────────────────────────────

    def get_unscored_jobs(self) -> list:
        """
        Returns all jobs that don't have an AI score yet.
        Called by the AI workflow to know what needs scoring.
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

    def get_top_opportunities(self, min_score: int = 45,
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
        Returns aggregate statistics for the Streamlit dashboard summary cards.
        Runs one SQL query — the database does the counting.
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
    # NEW — iOS API LAYER METHODS (Phase 1)
    # These methods serve the FastAPI endpoints in api/main.py.
    # They query the `jobs` table (your production table synced to Neon)
    # as opposed to the `opportunities` table used by the scraper pipeline.
    # ─────────────────────────────────────────────────────────────────────


    def get_jobs_filtered(self, filters: dict, limit: int = 26, offset: int = 0) -> list:
        with self.get_conn() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            conditions = ["opportunity_score IS NOT NULL"]
            params = []

            if filters.get("min_score") is not None:
                conditions.append("opportunity_score >= %s")
                params.append(filters["min_score"])

            if filters.get("days_fresh") is not None:
                conditions.append("date_found >= NOW() - (%s * INTERVAL '1 day')")
                params.append(filters["days_fresh"])

            if filters.get("is_remote") is not None:
                conditions.append("remote = %s")
                params.append(filters["is_remote"])

            if filters.get("visa_sponsorship") is not None:
                conditions.append("visa_sponsorship = %s")
                params.append(filters["visa_sponsorship"])

            if filters.get("source") is not None:
                conditions.append("job_source = %s")
                params.append(filters["source"])

            if filters.get("exclude_applied"):
                conditions.append("applied = FALSE")

            where_clause = " AND ".join(conditions)

            query = f"""
                SELECT *
                FROM opportunities
                WHERE {where_clause}
                ORDER BY opportunity_score DESC, date_found DESC
                LIMIT %s OFFSET %s
            """

            params.extend([limit, offset])
            cursor.execute(query, params)

            rows = cursor.fetchall()

        return [dict(row) for row in rows]
    
    def count_jobs_filtered(self, filters: dict) -> int:
        with self.get_conn() as conn:
            cursor = conn.cursor()

            conditions = ["opportunity_score IS NOT NULL"]
            params = []

            if filters.get("min_score") is not None:
                conditions.append("opportunity_score >= %s")
                params.append(filters["min_score"])

            if filters.get("days_fresh") is not None:
                conditions.append("date_found >= NOW() - (%s * INTERVAL '1 day')")
                params.append(filters["days_fresh"])

            if filters.get("is_remote") is not None:
                conditions.append("remote = %s")
                params.append(filters["is_remote"])

            if filters.get("visa_sponsorship") is not None:
                conditions.append("visa_sponsorship = %s")
                params.append(filters["visa_sponsorship"])

            if filters.get("source") is not None:
                conditions.append("job_source = %s")
                params.append(filters["source"])

            if filters.get("exclude_applied"):
                conditions.append("applied = FALSE")

            where_clause = " AND ".join(conditions)

            cursor.execute(
                f"SELECT COUNT(*) FROM opportunities WHERE {where_clause}",
                params
            )
            return cursor.fetchone()[0]
        
    def get_job_by_id(self, job_id: int) -> dict | None:
        """
        Returns a job by its integer primary key (opportunities.id).

        Called by:
        - GET /jobs/{job_id}
        - GET /jobs/{job_id}/outreach
        """
        with self.get_conn() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("SELECT * FROM opportunities WHERE id = %s", (job_id,))
            row = cursor.fetchone()
            return dict(row) if row else None

    def upsert_application(self, job_id: int, stage: str) -> dict:
        """
        Creates a new application row in the `applications` table, or updates
        the stage if one already exists for this job_id.

        Returns the final row as a dict.

        "ON CONFLICT (job_id) DO UPDATE" is Postgres upsert syntax:
        - No existing row for this job_id → INSERT a new row
        - Row already exists → UPDATE the stage and updated_at

        This means tapping "Apply" twice won't create duplicate rows.
        The applications table has a UNIQUE constraint on job_id
        (added in migrate_v2.py).
        """
        with self.get_conn() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                INSERT INTO applications (job_id, stage)
                VALUES (%s, %s)
                ON CONFLICT (job_id)
                DO UPDATE SET stage = EXCLUDED.stage, updated_at = NOW()
                RETURNING *
            """, (job_id, stage))
            return dict(cursor.fetchone())

    def get_all_applications(self) -> list:
        """
        Returns all applications joined with their job's title/company/score.
        Called by GET /applications to populate the iOS Tracker tab.

        JOIN: we need job details (title, company) alongside the application
        stage — so we join the applications table with the jobs table.
        """
        with self.get_conn() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                SELECT
                    a.id,
                    a.job_id,
                    a.stage,
                    a.applied_at,
                    a.notes,
                    a.updated_at,
                    j.role AS title,
                    j.company,
                    j.opportunity_score,
                    j.job_source,
                    j.apply_link
                FROM applications a
                JOIN opportunities j ON a.job_id = j.id
                ORDER BY a.updated_at DESC
            """)
            return [dict(row) for row in cursor.fetchall()]

    def update_application(self, application_id: str,
                        stage: str | None,
                        notes: str | None) -> dict | None:
        """
        Updates stage and/or notes for an application identified by its UUID.
        Called by PATCH /applications/{application_id}.

        Only updates the fields that were actually provided (not None).
        This is the "partial update" pattern — you can change just the stage
        without touching notes, or vice versa.

        Returns the updated row, or None if the application_id wasn't found.
        """
        with self.get_conn() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            set_parts = ["updated_at = NOW()"]
            params = []

            if stage is not None:
                set_parts.append("stage = %s")
                params.append(stage)

            if notes is not None:
                set_parts.append("notes = %s")
                params.append(notes)

            # The UUID must be cast with ::uuid so Postgres accepts the string
            params.append(application_id)

            cursor.execute(f"""
                UPDATE applications
                SET {', '.join(set_parts)}
                WHERE id = %s::uuid
                RETURNING *
            """, params)

            row = cursor.fetchone()
            return dict(row) if row else None

    def upsert_device_token(self, token: str, platform: str = "ios") -> None:
        """
        Registers an iOS APNs device token in the device_tokens table.
        Called by POST /devices when the app launches or token refreshes.

        ON CONFLICT (token) DO UPDATE just touches updated_at — we don't
        need to change anything else if the token already exists.
        """
        with self.get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO device_tokens (token, platform)
                VALUES (%s, %s)
                ON CONFLICT (token)
                DO UPDATE SET updated_at = NOW()
            """, (token, platform))

    def get_dashboard_stats(self) -> dict:
        """
        Aggregates pipeline and application statistics for the iOS Analytics tab.
        Called by GET /stats.

        Runs several focused queries and combines their results into one dict.
        Each query does its aggregation in SQL (not Python) — far more efficient
        than loading thousands of rows and summing them in application code.
        """
        with self.get_conn() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # ── Query 1: job-level aggregates ─────────────────────────────
            cursor.execute("""
                SELECT
                    COUNT(*)                                    AS total_opportunities,
                    AVG(opportunity_score)                                  AS avg_opportunity_score,
                    COUNT(CASE WHEN opportunity_score >= 70 THEN 1 END)     AS opportunities_above_70
                FROM opportunities
                WHERE opportunity_score IS NOT NULL
            """)
            agg = dict(cursor.fetchone())

            # ── Query 2: application funnel ───────────────────────────────
            cursor.execute("""
                SELECT
                    COUNT(*)                                          AS applied_count,
                    COUNT(CASE WHEN stage = 'replied' THEN 1 END)    AS replied_count,
                    COUNT(CASE WHEN stage = 'interview' THEN 1 END)  AS interview_count
                FROM applications
            """)
            app_stats = dict(cursor.fetchone())

            # Reply rate = replied ÷ applied  (guard against division by zero)
            applied_count = app_stats.get("applied_count") or 1
            reply_rate = (app_stats.get("replied_count") or 0) / applied_count

            # ── Query 3: score distribution (buckets of 10) ───────────────
            cursor.execute("""
                SELECT
                    CONCAT(FLOOR(opportunity_score/10)*10, '-', FLOOR(opportunity_score/10)*10+9) AS range,
                    COUNT(*) AS count
                FROM opportunities
                WHERE opportunity_score IS NOT NULL
                GROUP BY FLOOR(opportunity_score/10)
                ORDER BY FLOOR(opportunity_score/10)
            """)
            score_distribution = [dict(r) for r in cursor.fetchall()]

            # ── Query 4: top sources by average score ─────────────────────
            cursor.execute("""
                SELECT
                    job_source,
                    ROUND(AVG(opportunity_score), 1) AS avg_opportunity_score,
                    COUNT(*) AS count
                FROM opportunities
                WHERE opportunity_score IS NOT NULL
                GROUP BY job_source
                ORDER BY avg_opportunity_score DESC
                LIMIT 10
            """)
            top_sources = [dict(r) for r in cursor.fetchall()]

            # ── Query 5: last pipeline run timestamp ──────────────────────
            cursor.execute("""
                SELECT started_at
                FROM scrape_runs
                ORDER BY started_at DESC
                LIMIT 1
            """)
            last_run_row = cursor.fetchone()
            last_run = last_run_row["started_at"] if last_run_row else None

            return {
                "total_jobs":           agg.get("total_opportunities", 0),
                "avg_score":            float(agg.get("avg_opportunity_score") or 0),
                "jobs_above_70":        agg.get("opportunities_above_70", 0),
                "applied_count":        app_stats.get("applied_count", 0),
                "reply_rate":           reply_rate,
                "interview_count":      app_stats.get("interview_count", 0),
                "pipeline_last_run":    last_run,
                "score_distribution":   score_distribution,
                "top_sources":          top_sources,
            }

    # ─────────────────────────────────────────────────────────────────────
    # CLEANUP
    # ─────────────────────────────────────────────────────────────────────

    def close(self):
        """Closes all connections in the pool. Call on app shutdown."""
        self._pool.closeall()
        print("[DB] Connection pool closed.")


# ─────────────────────────────────────────────────────────────────────────────
# SINGLETON INSTANCES
#
# One shared DBClient created at module import time.
# Two names point to the same object:
#   db_client  — used by api/main.py (new iOS API layer)
#   db         — used by existing scraper pipeline, Streamlit, tests
#
# Both are identical. The dual naming avoids a breaking change in any
# existing file that already does `from storage.db_client import db`.
# ─────────────────────────────────────────────────────────────────────────────
db_client = DBClient()
db = db_client          # legacy alias — keeps all existing imports working