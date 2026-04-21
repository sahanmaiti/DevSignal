# run_scraper.py
#
# PURPOSE:
#   Manual entry point for the DevSignal scraping pipeline.
#   Run this during development to test the full flow.
#   In Phase 7, n8n will call this automatically every 12 hours.
#
# PHASE 2 BEHAVIOUR:
#   1. Start a scrape run log entry in the database
#   2. Run all scrapers (RemoteOK for now)
#   3. Deduplicate against the database
#   4. Insert new jobs into PostgreSQL
#   5. Finish the scrape run log with final counts
#   6. Print a summary
#
# USAGE:
#   cd ~/projects/devsignal
#   source venv/bin/activate
#   python run_scraper.py
#
# PLACEMENT: project root

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scrapers.remoteok_scraper import RemoteOKScraper
from processors.deduplicator import deduplicate
from storage.db_client import db


def print_line(char="─", width=60):
    print(char * width)


def main():
    print()
    print_line("═")
    print("  DevSignal — Scraper Pipeline")
    print_line("═")

    # ── Log the start of this run ────────────────────────────────────────
    run_id = db.start_scrape_run(triggered_by="manual")

    errors = ""
    all_raw_jobs = []

    try:
        # ── Step 1: Run all scrapers ──────────────────────────────────────
        # Add more scrapers to this list in Phase 3
        scrapers = [
            RemoteOKScraper(),
            # HackerNewsScraper(),
            # YCStartupScraper(),
        ]

        for scraper in scrapers:
            jobs = scraper.run()
            all_raw_jobs.extend(jobs)

        print()
        print_line()
        print(f"  Raw jobs collected: {len(all_raw_jobs)}")
        print_line()

        # ── Step 2: Deduplicate ────────────────────────────────────────────
        new_jobs = deduplicate(all_raw_jobs)

        # ── Step 3: Save to PostgreSQL ─────────────────────────────────────
        print()
        if new_jobs:
            print(f"[DB] Inserting {len(new_jobs)} new jobs...")
            inserted = db.insert_jobs(new_jobs)
            print(f"[DB] Successfully inserted {inserted} rows")
        else:
            print("[DB] No new jobs to insert.")
            inserted = 0

        # ── Step 4: Print results table ────────────────────────────────────
        print()
        print_line("═")
        print(f"  RESULTS: {inserted} new jobs saved to DevSignal database")
        print_line("═")

        if new_jobs:
            print()
            # Table header
            print(f"  {'#':<4} {'Company':<22} {'Role':<26} {'Remote':<8} {'Visa'}")
            print(f"  {'─'*4} {'─'*22} {'─'*26} {'─'*8} {'─'*7}")

            for i, job in enumerate(new_jobs, 1):
                print(
                    f"  {i:<4} "
                    f"{job['company'][:20]:<22} "
                    f"{job['role'][:24]:<26} "
                    f"{job['remote']:<8} "
                    f"{job['visa_sponsorship']}"
                )
            print()

        # ── Step 5: Show database totals ───────────────────────────────────
        stats = db.get_stats()
        print_line()
        print(f"  Database totals:")
        print(f"    Total jobs stored:   {stats.get('total_jobs', 0)}")
        print(f"    Unscored jobs:       {stats.get('unscored_count', 0)}")
        print(f"    Applied:             {stats.get('total_applied', 0)}")
        print(f"    Remote jobs:         {stats.get('remote_count', 0)}")
        print_line()

    except Exception as e:
        errors = str(e)
        print(f"\n[ERROR] Pipeline failed: {e}")
        raise

    finally:
        # Always log the end of the run, even if it crashed
        db.finish_scrape_run(
            run_id=run_id,
            jobs_found=len(all_raw_jobs),
            jobs_new=len(new_jobs) if 'new_jobs' in dir() else 0,
            errors=errors,
        )

    print()
    print("  Next steps:")
    print("  ─ Run again to confirm deduplication works (should insert 0)")
    print("  ─ Phase 3: add more scrapers (HackerNews, YC, Indeed...)")
    print("  ─ Phase 5: add AI scoring to the unscored jobs above")
    print()

    return new_jobs if 'new_jobs' in dir() else []


if __name__ == "__main__":
    main()