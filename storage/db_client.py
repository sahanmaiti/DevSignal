# storage/db_client.py
#
# PURPOSE:
#   The single database interface for all of DevSignal.
#   Every read and write to PostgreSQL goes through this class.
#   No other file in the project imports psycopg2 directly.
#
# TABLE NAME NOTE (ARCH-5):
#   The main jobs table is now called `jobs`.
#   A view named `opportunities` exists for backward compatibility with
#   Streamlit pages, db_sync.py, and other legacy code.  Those files
#   can keep saying FROM opportunities and they will work.  New code
#   written after migration 0001 should say FROM jobs.
#
# PLACEMENT: storage/db_client.py

import psycopg2
import psycopg2.extras
from psycopg2 import pool
from contextlib import contextmanager
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import DATABASE_URL


class DBClient:
    """
    Thread-safe PostgreSQL client for DevSignal.
    Uses a connection pool to avoid the overhead of opening
    a new connection for every query.
    """

    def __init__(self, min_connections: int = 1, max_connections: int = 5):
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
            print(f"  4. Is port 5433 free?  →  lsof -i :5433")
            raise

    # ─────────────────────────────────────────────────────────────────────
    # CONNECTION CONTEXT MANAGER
    # ─────────────────────────────────────────────────────────────────────

    @contextmanager
    def get_conn(self):
        conn = self._pool.getconn()
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            self._pool.putconn(conn)

    # ─────────────────────────────────────────────────────────────────────
    # DEDUPLICATION METHODS
    # ─────────────────────────────────────────────────────────────────────

    def hash_exists(self, job_hash: str) -> bool:
        sql = "SELECT 1 FROM jobs WHERE job_hash = %s LIMIT 1"
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (job_hash,))
                return cur.fetchone() is not None

    def get_all_hashes(self) -> set:
        """
        Returns ALL existing job hashes as a Python set.
        NOTE: this is O(n) in DB size.  Prefer letting ON CONFLICT handle
        deduplication instead (see ARCH audit BUG-7 notes).
        """
        sql = "SELECT job_hash FROM jobs"
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql)
                return {row[0] for row in cur.fetchall()}

    # ─────────────────────────────────────────────────────────────────────
    # WRITE METHODS
    # ─────────────────────────────────────────────────────────────────────

    def insert_jobs(self, jobs: list) -> int:
        """
        Inserts a list of job dicts into the jobs table.
        ON CONFLICT (job_hash) DO NOTHING handles cross-run deduplication.
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
            INSERT INTO jobs (
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
        sql = """
            UPDATE jobs
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
        sql = """
            UPDATE jobs
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
        """Maps iOS tracker stage values to the legacy column schema on jobs."""
        STAGE_TO_INTERVIEW: dict = {
            "interview": "Technical",
            "offer":     "Offer",
            "rejected":  "Rejected",
        }
        interview_stage = STAGE_TO_INTERVIEW.get(status, "")

        if interview_stage:
            sql = """
                UPDATE jobs
                SET applied         = TRUE,
                    interview_stage = %s
                WHERE id = %s
            """
            params = (interview_stage, job_id)
        else:
            sql = "UPDATE jobs SET applied = TRUE WHERE id = %s"
            params = (job_id,)

        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)

    def update_application_legacy(self, job_id: int, applied: bool,
                                response_status: str = "",
                                interview_stage: str = "") -> None:
        """
        Updates application tracking columns on the jobs table directly.
        Used by the Streamlit dashboard.

        NOTE: For the iOS API layer, prefer the applications table via
        upsert_application() — the sync trigger keeps jobs in sync automatically.
        """
        sql = """
            UPDATE jobs
            SET applied          = %s,
                response_status  = %s,
                interview_stage  = %s
            WHERE id = %s
        """
        with self.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (applied, response_status, interview_stage, job_id))

    # ─────────────────────────────────────────────────────────────────────
    # READ METHODS — scraper pipeline + Streamlit
    # ─────────────────────────────────────────────────────────────────────

    def get_unscored_jobs(self) -> list:
        sql = """
            SELECT
                id, company, role, location, remote,
                visa_sponsorship, experience_req, tech_stack,
                description_raw, apply_link, date_found, job_source
            FROM jobs
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
        """Returns top N scoring jobs from the last 12 hours for the Telegram digest."""
        sql = """
            SELECT
                id, company, role, location, remote, visa_sponsorship,
                opportunity_score, recruiter_name, linkedin_profile,
                apply_link, outreach_message, date_found, job_source
            FROM jobs
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
        """Returns jobs with optional filters. Used by the Streamlit dashboard."""
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
            FROM jobs
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
        """Returns aggregate statistics for Streamlit dashboard summary cards."""
        sql = """
            SELECT
                COUNT(*)                                             AS total_jobs,
                COUNT(*) FILTER (WHERE applied = TRUE)              AS total_applied,
                COUNT(*) FILTER (WHERE response_status = 'Replied') AS total_responses,
                COUNT(*) FILTER (WHERE interview_stage != '')        AS total_interviews,
                ROUND(AVG(opportunity_score)::numeric, 1)           AS avg_score,
                COUNT(*) FILTER (WHERE remote = 'Yes')              AS remote_count,
                COUNT(*) FILTER (WHERE opportunity_score IS NULL)   AS unscored_count
            FROM jobs
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
    # WATCHLIST
    # ─────────────────────────────────────────────────────────────────────

    def add_to_watchlist(self, company: str, ios_product_desc: str = "",
                        company_url: str = "", linkedin_url: str = "",
                        funding_stage: str = "", notes: str = "") -> None:
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
        sql = "SELECT * FROM companies_watchlist ORDER BY added_at DESC"
        with self.get_conn() as conn:
            with conn.cursor(
                cursor_factory=psycopg2.extras.RealDictCursor
            ) as cur:
                cur.execute(sql)
                return [dict(row) for row in cur.fetchall()]

    # ─────────────────────────────────────────────────────────────────────
    # iOS API LAYER METHODS  (serve api/main.py endpoints)
    # ─────────────────────────────────────────────────────────────────────

    def get_jobs_filtered(self, filters: dict,
                    limit: int = 26, offset: int = 0) -> list:
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
                FROM jobs
                WHERE {where_clause}
                ORDER BY date_found DESC, opportunity_score DESC
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
                f"SELECT COUNT(*) FROM jobs WHERE {where_clause}",
                params
            )
            return cursor.fetchone()[0]

    def get_job_by_id(self, job_id: int) -> dict | None:
        """Returns a job by its integer primary key."""
        with self.get_conn() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("SELECT * FROM jobs WHERE id = %s", (job_id,))
            row = cursor.fetchone()
            return dict(row) if row else None

    def upsert_application(self, job_id: int, stage: str) -> dict:
        """
        Creates or updates an application row.
        The sync trigger (trg_sync_application_to_opportunity) automatically
        mirrors the stage into jobs.applied / response_status / interview_stage
        — no second write needed in application code.
        """
        with self.get_conn() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                INSERT INTO applications (job_id, stage)
                VALUES (%s, %s)
                ON CONFLICT (job_id)        -- personal-mode partial index
                DO UPDATE SET stage = EXCLUDED.stage, updated_at = NOW()
                RETURNING *
            """, (job_id, stage))
            return dict(cursor.fetchone())

    def get_all_applications(self) -> list:
        """Returns all applications joined with their job's title/company/score."""
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
                    j.role                AS title,
                    j.company,
                    j.opportunity_score,
                    j.job_source,
                    j.apply_link
                FROM applications a
                JOIN jobs j ON a.job_id = j.id
                ORDER BY a.updated_at DESC
            """)
            return [dict(row) for row in cursor.fetchall()]

    def update_application(self, application_id: str,
                        stage: str | None,
                        notes: str | None) -> dict | None:
        """Partial-update an application (stage and/or notes)."""
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
        """Registers an APNs device token. Idempotent."""
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
        Aggregated pipeline and application statistics for the iOS Analytics tab.
        Called by GET /stats.
        """
        with self.get_conn() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # ── Job-level aggregates ──────────────────────────────────────
            cursor.execute("""
                SELECT
                    COUNT(*)                                            AS total_jobs,
                    AVG(opportunity_score)                              AS avg_score,
                    COUNT(CASE WHEN opportunity_score >= 70 THEN 1 END) AS jobs_above_70
                FROM jobs
                WHERE opportunity_score IS NOT NULL
            """)
            agg = dict(cursor.fetchone())

            # ── Application funnel ────────────────────────────────────────
            cursor.execute("""
                SELECT
                    COUNT(*)                                          AS applied_count,
                    COUNT(CASE WHEN stage = 'replied'   THEN 1 END)  AS replied_count,
                    COUNT(CASE WHEN stage = 'interview' THEN 1 END)  AS interview_count
                FROM applications
            """)
            app_stats = dict(cursor.fetchone())

            applied_count = app_stats.get("applied_count") or 1
            reply_rate = (app_stats.get("replied_count") or 0) / applied_count

            # ── Score distribution (buckets of 10) ────────────────────────
            cursor.execute("""
                SELECT
                    CONCAT(FLOOR(opportunity_score/10)*10, '-',
                        FLOOR(opportunity_score/10)*10+9) AS range,
                    COUNT(*) AS count
                FROM jobs
                WHERE opportunity_score IS NOT NULL
                GROUP BY FLOOR(opportunity_score/10)
                ORDER BY FLOOR(opportunity_score/10)
            """)
            score_distribution = [dict(r) for r in cursor.fetchall()]

            # ── Top sources by average score ──────────────────────────────
            cursor.execute("""
                SELECT
                    job_source                          AS source,
                    ROUND(AVG(opportunity_score), 1)    AS avg_score,
                    COUNT(*)                            AS count
                FROM jobs
                WHERE opportunity_score IS NOT NULL
                GROUP BY job_source
                ORDER BY avg_score DESC
                LIMIT 10
            """)
            top_sources = [
                {
                    "source":    r["source"],
                    "avg_score": float(r["avg_score"]) if r["avg_score"] is not None else 0.0,
                    "count":     int(r["count"]),
                }
                for r in cursor.fetchall()
            ]

            # ── Last pipeline run ─────────────────────────────────────────
            cursor.execute("""
                SELECT started_at
                FROM scrape_runs
                ORDER BY started_at DESC
                LIMIT 1
            """)
            last_run_row = cursor.fetchone()
            last_run = last_run_row["started_at"] if last_run_row else None

            return {
                "total_jobs":         agg.get("total_jobs", 0),
                "avg_score":          float(agg.get("avg_score") or 0),
                "jobs_above_70":      agg.get("jobs_above_70", 0),
                "applied_count":      app_stats.get("applied_count", 0),
                "reply_rate":         reply_rate,
                "interview_count":    app_stats.get("interview_count", 0),
                "pipeline_last_run":  last_run,
                "score_distribution": score_distribution,
                "top_sources":        top_sources,
            }

    # ─────────────────────────────────────────────────────────────────────
    # CLEANUP
    # ─────────────────────────────────────────────────────────────────────

    def close(self):
        """Closes all connections in the pool."""
        self._pool.closeall()
        print("[DB] Connection pool closed.")


# ─────────────────────────────────────────────────────────────────────────────
# SINGLETON INSTANCES
#
# db_client  — used by api/main.py (iOS API layer)
# db         — legacy alias — keeps all existing scraper imports working
# ─────────────────────────────────────────────────────────────────────────────
db_client = DBClient()
db = db_client
