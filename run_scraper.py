# run_scraper.py
# Full pipeline — all working scrapers, retired blocked ones

import sys
import os
import time
import subprocess

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# ── Tier 1: Free public APIs ─────────────────────────────────────────────
from scrapers.remoteok_scraper import RemoteOKScraper
from scrapers.hackernews_scraper import HackerNewsScraper
from scrapers.yc_scraper import YCScraper
from scrapers.remotive_scraper import RemotiveScraper
from scrapers.arbeitnow_scraper import ArbeitnowScraper
from scrapers.himalayas_scraper import HimalayasScraper
from scrapers.jobspresso_scraper import JobspressoScraper
from scrapers.weworkremotely_scraper import WeWorkRemotelyScraper
from scrapers.startupjobs_scraper import StartupJobsScraper

# ── Tier 2: API-keyed scrapers ───────────────────────────────────────────
from scrapers.google_jobs_scraper import GoogleJobsScraper
from scrapers.adzuna_scraper import AdzunaScraper

# ── Tier 3: Best-effort scraping ─────────────────────────────────────────
from scrapers.arc_scraper import ArcScraper
from scrapers.cutshort_scraper import CutshortScraper

from processors.job_parser import parse_jobs
from processors.filter_engine import filter_jobs
from processors.deduplicator import deduplicate

from storage.db_client import db

from notifications.telegram_bot import (
    send_digest,
    send_run_summary,
    send_error_alert,
)

from config.settings import (
    SERPER_API_KEY,
    ADZUNA_APP_ID,
    NEON_DATABASE_URL,
)


def print_line(char="─", width=65):
    print(char * width)


def run_tier(scrapers, label, delay=0):
    print(f"\n{'─' * 65}")
    print(f"  {label}")
    print(f"{'─' * 65}")

    all_jobs = []
    counts = {}

    for scraper in scrapers:
        try:
            jobs = scraper.run()
            counts[scraper.SOURCE_NAME] = len(jobs)
            all_jobs.extend(jobs)

            if delay:
                time.sleep(delay)

        except Exception as e:
            print(f"  [{scraper.SOURCE_NAME}] FATAL: {e}")
            counts[scraper.SOURCE_NAME] = 0

    return all_jobs, counts


def main():
    print()
    print_line("═")
    print("  DevSignal — Full Pipeline")
    print_line("═")

    run_id = db.start_scrape_run(triggered_by="manual")

    errors = ""
    all_raw_jobs = []
    source_counts = {}
    filtered_jobs = []
    new_jobs = []
    inserted = 0

    try:
        # ── Tier 1 ──────────────────────────────────────────────────────
        t1_jobs, t1_counts = run_tier(
            [
                RemoteOKScraper(),
                HackerNewsScraper(),
                YCScraper(),
                RemotiveScraper(),
                ArbeitnowScraper(),
                HimalayasScraper(),
                JobspressoScraper(),
                WeWorkRemotelyScraper(),
                StartupJobsScraper(),
            ],
            "TIER 1 — Free public APIs"
        )

        all_raw_jobs.extend(t1_jobs)
        source_counts.update(t1_counts)

        # ── Tier 2 ──────────────────────────────────────────────────────
        t2_scrapers = []

        if SERPER_API_KEY:
            t2_scrapers.append(GoogleJobsScraper())
        else:
            print("\n  [Tier 2] Google Jobs skipped — add SERPER_API_KEY")

        if ADZUNA_APP_ID:
            t2_scrapers.append(AdzunaScraper())
        else:
            print("  [Tier 2] Adzuna skipped — add ADZUNA_APP_ID")

        if t2_scrapers:
            t2_jobs, t2_counts = run_tier(
                t2_scrapers,
                "TIER 2 — API-keyed scrapers"
            )

            all_raw_jobs.extend(t2_jobs)
            source_counts.update(t2_counts)

        # ── Tier 3 ──────────────────────────────────────────────────────
        t3_jobs, t3_counts = run_tier(
            [
                ArcScraper(),
                CutshortScraper(),
            ],
            "TIER 3 — Best-effort scraping",
            delay=1.5
        )

        all_raw_jobs.extend(t3_jobs)
        source_counts.update(t3_counts)

        # ── Source Summary ──────────────────────────────────────────────
        print()
        print_line("═")
        print("  Source breakdown:")
        print_line()

        for source, count in sorted(
            source_counts.items(),
            key=lambda x: x[1],
            reverse=True
        ):
            bar = "█" * min(count, 30)
            print(f"  {source:<25} {bar} {count}")

        print_line()
        print(f"  {'TOTAL':<25} {len(all_raw_jobs)}")
        print_line("═")

        # ── Processing ──────────────────────────────────────────────────
        print()

        parsed_jobs = parse_jobs(all_raw_jobs)
        filtered_jobs = filter_jobs(parsed_jobs)
        new_jobs = deduplicate(filtered_jobs)

        # ── Insert ──────────────────────────────────────────────────────
        print()

        if new_jobs:
            inserted = db.insert_jobs(new_jobs)
            print(f"[DB] Inserted {inserted} new jobs")
        else:
            print("[DB] No new jobs to insert")

        # ── Telegram ────────────────────────────────────────────────────
        send_digest(new_jobs if new_jobs else [])

        send_run_summary(
            jobs_found=len(all_raw_jobs),
            jobs_filtered=len(filtered_jobs),
            jobs_new=len(new_jobs),
            jobs_stored=inserted,
            sources=source_counts,
        )

        # ── Results Table ───────────────────────────────────────────────
        print()
        print_line("═")
        print(f"  RESULTS: {len(new_jobs)} new jobs saved")
        print_line("═")

        if new_jobs:
            print()
            print(
                f"  {'#':<4} {'Company':<22} "
                f"{'Role':<24} {'Source':<15} {'Remote'}"
            )
            print(
                f"  {'─'*4} {'─'*22} "
                f"{'─'*24} {'─'*15} {'─'*8}"
            )

            for i, job in enumerate(new_jobs[:20], 1):
                print(
                    f"  {i:<4} "
                    f"{job['company'][:20]:<22} "
                    f"{job['role'][:22]:<24} "
                    f"{job['job_source'][:13]:<15} "
                    f"{job['remote']}"
                )

            if len(new_jobs) > 20:
                print(f"  ... and {len(new_jobs) - 20} more")

            print()

        # ── Sync to Neon for public dashboard ───────────────────────────
        if NEON_DATABASE_URL and new_jobs:
            print("\n[Sync] Pushing new jobs to Neon cloud dashboard...")

            try:
                result = subprocess.run(
                    [sys.executable, "db_sync.py", "--limit", "100"],
                    cwd=os.path.dirname(os.path.abspath(__file__)),
                    capture_output=True,
                    text=True,
                    timeout=120,
                )

                if result.returncode == 0:
                    print("[Sync] Neon sync complete")
                else:
                    print(
                        f"[Sync] Sync warning: "
                        f"{result.stderr[:200]}"
                    )

            except Exception as e:
                print(f"[Sync] Sync failed (non-fatal): {e}")

        # ── DB Totals ───────────────────────────────────────────────────
        stats = db.get_stats()

        print_line()
        print(
            f"  DB totals: "
            f"{stats.get('total_jobs', 0)} stored · "
            f"{stats.get('unscored_count', 0)} unscored · "
            f"{stats.get('remote_count', 0)} remote"
        )
        print_line()

    except Exception as e:
        errors = str(e)

        print(f"\n[ERROR] {e}")

        send_error_alert(str(e))

        import traceback
        traceback.print_exc()

        raise

    finally:
        db.finish_scrape_run(
            run_id=run_id,
            jobs_found=len(all_raw_jobs),
            jobs_new=len(new_jobs),
            errors=errors,
        )

    return new_jobs


if __name__ == "__main__":
    main()