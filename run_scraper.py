# run_scraper.py
#
# PURPOSE:
#   Manual entry point for the DevSignal scraping pipeline.
#   Phase 3 version — 4 scrapers + parser + filter.
#
# PIPELINE ORDER:
#   1. Run all scrapers in parallel-ish (one after another)
#   2. Parse descriptions to extract structured fields
#   3. Filter out jobs that don't match the target profile
#   4. Deduplicate against the database
#   5. Insert new jobs into PostgreSQL
#   6. Log the run
#
# USAGE:
#   cd ~/projects/DevSignal
#   source venv/bin/activate
#   python run_scraper.py
#
# PLACEMENT: project root

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scrapers.remoteok_scraper   import RemoteOKScraper
from scrapers.hackernews_scraper import HackerNewsScraper
from scrapers.yc_scraper         import YCScraper
from scrapers.remotive_scraper   import RemotiveScraper
from processors.job_parser       import parse_jobs
from processors.filter_engine    import filter_jobs
from processors.deduplicator     import deduplicate
from storage.db_client           import db


def print_line(char="─", width=62):
    print(char * width)


def main():
    print()
    print_line("═")
    print("  DevSignal — Scraper Pipeline  (Phase 3)")
    print_line("═")

    # ── Log start ────────────────────────────────────────────────────────
    run_id = db.start_scrape_run(triggered_by="manual")
    errors = ""
    all_raw_jobs  = []
    filtered_jobs = []
    new_jobs      = []

    try:
        # ── Step 1: Run all scrapers ──────────────────────────────────────
        scrapers = [
            RemoteOKScraper(),
            HackerNewsScraper(),
            YCScraper(),
            RemotiveScraper(),
        ]

        source_counts = {}
        for scraper in scrapers:
            jobs = scraper.run()
            source_counts[scraper.SOURCE_NAME] = len(jobs)
            all_raw_jobs.extend(jobs)

        print()
        print_line()
        print(f"  Raw jobs by source:")
        for source, count in source_counts.items():
            print(f"    {source:<25} {count} jobs")
        print(f"    {'─'*25}──────")
        print(f"    {'TOTAL':<25} {len(all_raw_jobs)} jobs")
        print_line()

        # ── Step 2: Parse descriptions ────────────────────────────────────
        print()
        parsed_jobs = parse_jobs(all_raw_jobs)

        # ── Step 3: Filter ────────────────────────────────────────────────
        filtered_jobs = filter_jobs(parsed_jobs)

        # ── Step 4: Deduplicate against database ──────────────────────────
        new_jobs = deduplicate(filtered_jobs)

        # ── Step 5: Insert into PostgreSQL ────────────────────────────────
        print()
        if new_jobs:
            inserted = db.insert_jobs(new_jobs)
            print(f"[DB] Inserted {inserted} new jobs into PostgreSQL")
        else:
            print("[DB] No new jobs to insert.")
            inserted = 0

        # ── Step 6: Print results table ────────────────────────────────────
        print()
        print_line("═")
        print(f"  RESULTS: {len(new_jobs)} new jobs saved to DevSignal")
        print_line("═")

        if new_jobs:
            print()
            print(f"  {'#':<4} {'Company':<20} {'Role':<24} {'Source':<14} {'Remote'}")
            print(f"  {'─'*4} {'─'*20} {'─'*24} {'─'*14} {'─'*8}")
            for i, job in enumerate(new_jobs, 1):
                print(
                    f"  {i:<4} "
                    f"{job['company'][:18]:<20} "
                    f"{job['role'][:22]:<24} "
                    f"{job['job_source'][:12]:<14} "
                    f"{job['remote']}"
                )
            print()

        # ── Step 7: Show database totals ───────────────────────────────────
        stats = db.get_stats()
        print_line()
        print(f"  Database totals:")
        print(f"    Total stored:     {stats.get('total_jobs', 0)}")
        print(f"    Unscored:         {stats.get('unscored_count', 0)}  ← ready for Phase 5 AI scoring")
        print(f"    Remote jobs:      {stats.get('remote_count', 0)}")
        print(f"    Applied:          {stats.get('total_applied', 0)}")
        print_line()

    except Exception as e:
        errors = str(e)
        print(f"\n[ERROR] Pipeline failed: {e}")
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

    print()
    print("  Phase 3 complete. Next: Phase 4 — Telegram notifications")
    print()
    return new_jobs


if __name__ == "__main__":
    main()