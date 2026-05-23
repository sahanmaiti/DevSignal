# Runs the full DevSignal pipeline every 12 hours automatically.
# Managed by systemd in production — do not run manually alongside systemd.
#
# To test manually: python scheduler.py

import subprocess
import sys
import os
import time
from datetime import datetime, timezone


def log(msg: str):
    """Print with UTC timestamp — shows up clearly in journalctl."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"[{ts}] {msg}", flush=True)


def run_step(name: str, *cmd_args) -> bool:
    """
    Run one pipeline step as a subprocess.
    Returns True on success, False on failure or timeout.
    """
    log(f"Starting: {name}")
    cmd = [sys.executable] + list(cmd_args)

    try:
        result = subprocess.run(
            cmd,
            cwd=os.path.dirname(os.path.abspath(__file__)),
            timeout=900,  # 15 minutes max per step
        )
        if result.returncode == 0:
            log(f"Completed: {name}")
            return True
        else:
            log(f"Failed: {name} (exit code {result.returncode})")
            return False

    except subprocess.TimeoutExpired:
        log(f"Timeout: {name} took more than 15 minutes — skipping")
        return False

    except Exception as e:
        log(f"Error in {name}: {e}")
        return False


def run_full_pipeline():
    log("=" * 55)
    log("DevSignal Pipeline Starting")
    log("=" * 55)

    # Step 1: Scrape all sources
    ok = run_step("Scraper", "run_scraper.py")
    if not ok:
        log("Scraper failed — stopping pipeline early")
        return

    # Step 2: AI scoring (non-fatal if it fails)
    run_step("Scorer", "run_scorer.py")

    # Step 3: Recruiter enrichment (non-fatal if it fails)
    run_step("Enricher", "run_enricher.py", "--min-score", "50")

    log("=" * 55)
    log("DevSignal Pipeline Complete")
    log("=" * 55)


def main():
    log("DevSignal Scheduler started")
    log("Pipeline will run every 12 hours")
    log("First run starting immediately...")

    # Always run once right away when the scheduler starts
    run_full_pipeline()

    INTERVAL_SECONDS = 12 * 60 * 60  # 12 hours

    while True:
        log("Next run in 12 hours. Sleeping...")
        time.sleep(INTERVAL_SECONDS)
        run_full_pipeline()


if __name__ == "__main__":
    main()