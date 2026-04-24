# api/pipeline_server.py
#
# PURPOSE:
#   A lightweight FastAPI server that exposes HTTP endpoints
#   for triggering the DevSignal pipeline.
#
#   n8n calls these endpoints via HTTP Request nodes.
#   This solves the Execute Command node unavailability in
#   newer n8n versions.
#
# ENDPOINTS:
#   POST /run-pipeline   — runs full pipeline (scrape+score+enrich)
#   POST /run-scraper    — scraper only
#   POST /run-scorer     — scorer only
#   GET  /health         — confirms server is up
#   GET  /status         — shows last run result
#
# SECURITY:
#   Protected by a simple API key in the X-API-Key header.
#   Only accessible from localhost — not exposed to the internet.
#
# START:
#   python api/pipeline_server.py
#   (or: uvicorn api.pipeline_server:app --host 0.0.0.0 --port 8000)
#
# PLACEMENT: api/pipeline_server.py

import subprocess
import threading
import os
import sys
import json
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI, HTTPException, Header
from fastapi.responses import JSONResponse

# ── Config ────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).parent.parent
PIPELINE_SCRIPT = PROJECT_ROOT / "run_pipeline.sh"
PYTHON_BIN      = PROJECT_ROOT / "venv" / "bin" / "python"

# Simple API key — read from .env or use default for local dev
# n8n will send this in the X-API-Key header
from dotenv import load_dotenv
load_dotenv()
API_KEY = os.getenv("PIPELINE_API_KEY", "devsignal-local-key")

# ── State tracking ────────────────────────────────────────────────────────
_last_run = {
    "status":    "never_run",
    "started_at": None,
    "finished_at": None,
    "exit_code":  None,
    "output":     "",
    "error":      "",
}
_pipeline_lock = threading.Lock()   # prevents two runs at the same time


# ── App ───────────────────────────────────────────────────────────────────
app = FastAPI(
    title="DevSignal Pipeline API",
    description="Triggers the DevSignal automation pipeline",
    version="1.0.0",
)


def verify_key(x_api_key: str | None) -> None:
    """Raises 401 if the API key header is missing or wrong."""
    if not x_api_key or x_api_key != API_KEY:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing X-Api-Key header"
        )


def run_script(script_path: str, args: list = None) -> dict:
    """
    Runs a Python or shell script as a subprocess.
    Captures stdout/stderr and returns them with the exit code.

    This runs synchronously — the HTTP response is sent after
    the script completes. For very long runs this is fine because
    n8n waits with a configurable timeout.
    """
    cmd = ["bash", str(script_path)]
    if args:
        cmd.extend(args)

    env = os.environ.copy()
    env["PYTHONPATH"] = str(PROJECT_ROOT)

    result = subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        env=env,
        timeout=1800,   # 30-minute max — full pipeline including AI scoring
    )
    return {
        "exit_code": result.returncode,
        "stdout":    result.stdout[-3000:] if result.stdout else "",
        "stderr":    result.stderr[-1000:] if result.stderr else "",
    }


# ── Endpoints ─────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    """Quick liveness check. n8n can ping this to confirm the server is up."""
    return {
        "status":    "ok",
        "project":   "DevSignal",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/status")
def status(x_api_key: str | None = Header(default=None)):
    """Returns the result of the last pipeline run."""
    verify_key(x_api_key)
    return _last_run


@app.post("/run-pipeline")
def run_pipeline(x_api_key: str | None = Header(default=None)):
    """
    Runs the full DevSignal pipeline:
    scrape → score → enrich → Telegram notify

    Returns when the pipeline completes (or fails).
    n8n should set a request timeout of at least 30 minutes.
    """
    verify_key(x_api_key)

    # Prevent concurrent runs
    if not _pipeline_lock.acquire(blocking=False):
        return JSONResponse(
            status_code=409,
            content={"error": "Pipeline already running. Try again later."}
        )

    started_at = datetime.now(timezone.utc).isoformat()
    _last_run["status"]     = "running"
    _last_run["started_at"] = started_at

    try:
        print(f"\n[API] Pipeline triggered at {started_at}")

        result = run_script(PIPELINE_SCRIPT)

        _last_run["finished_at"] = datetime.now(timezone.utc).isoformat()
        _last_run["exit_code"]   = result["exit_code"]
        _last_run["output"]      = result["stdout"]
        _last_run["error"]       = result["stderr"]

        if result["exit_code"] == 0:
            _last_run["status"] = "success"
            print(f"[API] Pipeline completed successfully")
            return {
                "status":   "success",
                "started":  started_at,
                "finished": _last_run["finished_at"],
                "preview":  result["stdout"][-500:],
            }
        else:
            _last_run["status"] = "failed"
            print(f"[API] Pipeline failed (exit {result['exit_code']})")
            print(f"[API] stderr: {result['stderr'][:300]}")
            raise HTTPException(
                status_code=500,
                detail={
                    "error":     "Pipeline failed",
                    "exit_code": result["exit_code"],
                    "stderr":    result["stderr"][-500:],
                    "stdout":    result["stdout"][-500:],
                }
            )

    except subprocess.TimeoutExpired:
        _last_run["status"] = "timeout"
        raise HTTPException(
            status_code=504,
            detail="Pipeline timed out after 30 minutes"
        )
    except HTTPException:
        raise
    except Exception as e:
        _last_run["status"] = "error"
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        _pipeline_lock.release()


@app.post("/run-scraper")
def run_scraper_only(x_api_key: str | None = Header(default=None)):
    """Runs only the scraper — useful for testing."""
    verify_key(x_api_key)

    result = run_script(
        str(PROJECT_ROOT / "venv" / "bin" / "python"),
        args=["run_scraper.py"]
    )
    if result["exit_code"] == 0:
        return {"status": "success", "preview": result["stdout"][-500:]}
    raise HTTPException(500, detail=result["stderr"][-500:])


@app.post("/run-scorer")
def run_scorer_only(x_api_key: str | None = Header(default=None)):
    """Runs only the AI scorer — useful for testing."""
    verify_key(x_api_key)

    result = run_script(
        str(PROJECT_ROOT / "venv" / "bin" / "python"),
        args=["run_scorer.py"]
    )
    if result["exit_code"] == 0:
        return {"status": "success", "preview": result["stdout"][-500:]}
    raise HTTPException(500, detail=result["stderr"][-500:])


# ── Start ─────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    print("=" * 50)
    print("  DevSignal Pipeline API")
    print("=" * 50)
    print(f"  Project root: {PROJECT_ROOT}")
    print(f"  API Key:      {API_KEY[:8]}...")
    print(f"  Docs:         http://localhost:8000/docs")
    print("=" * 50)
    print()
    uvicorn.run(
        "api.pipeline_server:app",
        host="0.0.0.0",   # listen on all interfaces so Docker can reach it
        port=8000,
        reload=False,
        log_level="info",
    )