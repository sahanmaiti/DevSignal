import asyncio
from functools import partial
from storage.db_client import db_client


class AsyncDBClient:
    """
    Thin async wrapper around the synchronous DBClient singleton.

    Every method here is a coroutine that runs the matching synchronous
    DBClient method in a thread pool via asyncio.to_thread().

    Thread safety: psycopg2's ThreadedConnectionPool (used by DBClient)
    is explicitly thread-safe — different threads borrow different
    connections from the pool.
    """

    # ── Read methods ──────────────────────────────────────────────────────

    async def get_jobs_filtered(self, filters: dict,
                                limit: int = 26,
                                offset: int = 0) -> list:
        return await asyncio.to_thread(
            db_client.get_jobs_filtered, filters, limit, offset
        )

    async def count_jobs_filtered(self, filters: dict) -> int:
        return await asyncio.to_thread(
            db_client.count_jobs_filtered, filters
        )

    async def get_job_by_id(self, job_id: int) -> dict | None:
        return await asyncio.to_thread(
            db_client.get_job_by_id, job_id
        )

    async def get_all_applications(self) -> list:
        return await asyncio.to_thread(
            db_client.get_all_applications
        )

    async def get_dashboard_stats(self) -> dict:
        return await asyncio.to_thread(
            db_client.get_dashboard_stats
        )

    async def get_unscored_jobs(self) -> list:
        return await asyncio.to_thread(
            db_client.get_unscored_jobs
        )

    async def get_top_opportunities(self,
                                    min_score: int = 45,
                                    limit: int = 5) -> list:
        return await asyncio.to_thread(
            db_client.get_top_opportunities, min_score, limit
        )

    # ── Write methods ─────────────────────────────────────────────────────

    async def upsert_application(self, job_id: int, stage: str) -> dict:
        return await asyncio.to_thread(
            db_client.upsert_application, job_id, stage
        )

    async def update_application(self, application_id: str,
                                stage: str | None,
                                notes: str | None) -> dict | None:
        return await asyncio.to_thread(
            db_client.update_application, application_id, stage, notes
        )

    async def update_application_status(self,
                                        job_id: int,
                                        status: str) -> None:
        return await asyncio.to_thread(
            db_client.update_application_status, job_id, status
        )

    async def upsert_device_token(self,
                                token: str,
                                platform: str = "ios") -> None:
        return await asyncio.to_thread(
            db_client.upsert_device_token, token, platform
        )

    async def update_score(self, job_id: int, score: int,
                            breakdown: dict,
                            outreach_message: str) -> None:
        return await asyncio.to_thread(
            db_client.update_score, job_id, score,
            breakdown, outreach_message
        )

    async def update_recruiter(self, job_id: int,
                                recruiter_name: str,
                                recruiter_role: str,
                                linkedin_profile: str,
                                email: str) -> None:
        return await asyncio.to_thread(
            db_client.update_recruiter, job_id, recruiter_name,
            recruiter_role, linkedin_profile, email
        )

    async def insert_jobs(self, jobs: list) -> int:
        return await asyncio.to_thread(
            db_client.insert_jobs, jobs
        )

    async def start_scrape_run(self,
                                triggered_by: str = "manual") -> int:
        return await asyncio.to_thread(
            db_client.start_scrape_run, triggered_by
        )

    async def finish_scrape_run(self, run_id: int,
                                jobs_found: int, jobs_new: int,
                                jobs_scored: int = 0,
                                errors: str = "") -> None:
        return await asyncio.to_thread(
            db_client.finish_scrape_run, run_id,
            jobs_found, jobs_new, jobs_scored, errors
        )


# Single shared instance — import this in api/main.py
async_db = AsyncDBClient()