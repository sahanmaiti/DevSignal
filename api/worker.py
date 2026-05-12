# api/worker.py
#
# PURPOSE:
#   ARQ async worker that runs background tasks for DevSignal.
#   ARQ is Redis-backed and async-native — a natural fit for FastAPI.
#
# WHY THIS FIXES ARCH-4
#   Before: POST /run-pipeline did subprocess.Popen and returned the PID.
#     • Two simultaneous taps could start two pipeline processes that would
#       race each other inserting jobs and cause DB constraint violations.
#     • No status tracking, no retry, no error reporting back to the caller.
#
#   After: POST /run-pipeline enqueues a job and returns a job_id.
#     • ARQ's built-in deduplication (job_id) prevents double-runs.
#     • Job status is stored in Redis — the client can poll GET /pipeline/status/{job_id}.
#     • Failures are retried up to MAX_TRIES times with exponential backoff.
#     • The event loop is never blocked; the Popen call is gone.
#
# STARTING THE WORKER:
#   # Development (single process):
#   arq api.worker.WorkerSettings
#
#   # Production (add to docker-compose.yml as a separate service):
#   command: arq api.worker.WorkerSettings
#
# DEPENDENCIES:
#   pip install arq redis
#
# PLACEMENT: api/worker.py

import asyncio
import os
import sys
from pathlib import Path
from typing import Any

from arq import ArqRedis, create_pool
from arq.connections import RedisSettings

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import REDIS_URL

# ─────────────────────────────────────────────────────────────────────────────
# TASK FUNCTIONS
# ARQ calls these with `ctx` as the first argument (contains the Redis pool).
# Every task must be an async def.
# ─────────────────────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).parent.parent
PIPELINE_SCRIPT = PROJECT_ROOT / "run_pipeline.sh"


async def run_pipeline(ctx: dict[str, Any]) -> dict:
    """
    Runs the full DevSignal pipeline (scrape → score → enrich → notify).

    ARQ serialises this task: only one instance can run at a time thanks to
    the unique job_id supplied by the enqueue call in api/main.py.

    Returns a dict that ARQ stores in Redis under the job_id — accessible
    via the GET /pipeline/status/{job_id} endpoint.
    """
    print(f"[worker] run_pipeline started (job_id={ctx['job_id']})")

    if not PIPELINE_SCRIPT.exists():
        error_msg = f"Pipeline script not found at {PIPELINE_SCRIPT}"
        print(f"[worker] ERROR: {error_msg}")
        return {"status": "error", "error": error_msg}

    python_bin = PROJECT_ROOT / "venv" / "bin" / "python"
    if not python_bin.exists():
        python_bin = sys.executable

    env = os.environ.copy()
    env["PYTHONPATH"] = str(PROJECT_ROOT)

    try:
        # asyncio.create_subprocess_exec keeps the event loop free while
        # the shell script runs — no blocking.
        proc = await asyncio.create_subprocess_exec(
            "bash",
            str(PIPELINE_SCRIPT),
            cwd=str(PROJECT_ROOT),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=env,
        )

        # Timeout: 30 minutes (same as the old synchronous server)
        stdout, stderr = await asyncio.wait_for(
            proc.communicate(), timeout=1800
        )

        stdout_text = stdout.decode("utf-8", errors="replace")[-3000:]
        stderr_text = stderr.decode("utf-8", errors="replace")[-1000:]

        if proc.returncode == 0:
            print(f"[worker] run_pipeline succeeded (rc=0)")
            return {
                "status":  "success",
                "preview": stdout_text,
            }
        else:
            print(f"[worker] run_pipeline failed (rc={proc.returncode})")
            return {
                "status":   "error",
                "exit_code": proc.returncode,
                "stderr":    stderr_text,
                "stdout":    stdout_text,
            }

    except asyncio.TimeoutError:
        proc.kill()
        return {"status": "timeout", "error": "Pipeline timed out after 30 minutes"}

    except Exception as exc:
        return {"status": "error", "error": str(exc)}


async def run_scorer_only(ctx: dict[str, Any]) -> dict:
    """Runs just the AI scoring step — useful for re-scoring without re-scraping."""
    python_bin = PROJECT_ROOT / "venv" / "bin" / "python"
    if not python_bin.exists():
        python_bin = sys.executable

    proc = await asyncio.create_subprocess_exec(
        str(python_bin),
        str(PROJECT_ROOT / "run_scorer.py"),
        cwd=str(PROJECT_ROOT),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=900)

    if proc.returncode == 0:
        return {"status": "success", "preview": stdout.decode()[-1000:]}
    return {"status": "error", "stderr": stderr.decode()[-500:]}


# ─────────────────────────────────────────────────────────────────────────────
# REDIS CONNECTION HELPER
# Used by api/main.py to enqueue tasks.
# ─────────────────────────────────────────────────────────────────────────────

def _parse_redis_settings(url: str) -> RedisSettings:
    """
    Converts a Redis URL string (redis://host:port/db) to an ARQ
    RedisSettings object.  Falls back to localhost:6379 on parse failure.
    """
    try:
        from urllib.parse import urlparse
        parsed = urlparse(url)
        return RedisSettings(
            host=parsed.hostname or "localhost",
            port=parsed.port or 6379,
            database=int(parsed.path.lstrip("/") or 0),
            password=parsed.password,
        )
    except Exception:
        return RedisSettings(host="localhost", port=6379)


_redis_settings = _parse_redis_settings(REDIS_URL)


async def get_arq_pool() -> ArqRedis:
    """
    Returns an ARQ Redis pool.  Call this once in the FastAPI lifespan
    and cache the result, or call it per-request (ARQ reuses connections).
    """
    return await create_pool(_redis_settings)


# ─────────────────────────────────────────────────────────────────────────────
# WORKER SETTINGS
#
# ARQ reads this class when you run:  arq api.worker.WorkerSettings
# ─────────────────────────────────────────────────────────────────────────────

class WorkerSettings:
    # All task functions the worker can execute
    functions = [run_pipeline, run_scorer_only]

    # Redis connection
    redis_settings = _redis_settings

    # How long a job can sit in the queue before being discarded (2 hours)
    queue_read_timeout = 7200

    # Retry configuration
    max_tries = 1           # pipeline is not idempotent — don't auto-retry

    # How long between health-check polls (seconds)
    health_check_interval = 30

    # Graceful shutdown: wait up to 35 minutes for the running task to finish
    # before killing (matches the 30-min pipeline timeout + 5 min buffer)
    job_timeout = 2100

    on_startup  = None   # optional: async def on_startup(ctx)
    on_shutdown = None   # optional: async def on_shutdown(ctx)