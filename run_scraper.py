# run_scraper.py
#
# PURPOSE:
#   Manual entry point for testing the scraper pipeline.
#   Run this from your terminal during development to see live output.
#
# PHASE 1 BEHAVIOUR:
#   Scrapes RemoteOK → deduplicates → prints a summary table.
#   Does NOT yet save to database (that's Phase 2).
#
# USAGE:
#   cd ~/projects/DevSignal
#   source venv/bin/activate
#   python run_scraper.py
#
# PLACEMENT: project root

import sys
import os

# Add project root to Python path so all imports work
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scrapers.remoteok_scraper import RemoteOKScraper
from processors.deduplicator import deduplicate


def print_separator(char="─", width=65):
    print(char * width)


def print_job_table(jobs: list[dict]):
    """Prints a formatted table of job results."""
    if not jobs:
        print("\n  No iOS jobs found in this run.")
        print("  This is normal — try again in a few hours or check")
        print("  https://remoteok.com/remote-swift-jobs to verify the site is up.\n")
        return

    print()
    # Header row
    print(f"  {'#':<4} {'Company':<22} {'Role':<28} {'Remote':<8} {'Score'}")
    print(f"  {'─'*4} {'─'*22} {'─'*28} {'─'*8} {'─'*5}")

    for i, job in enumerate(jobs, 1):
        company = job['company'][:20]
        role    = job['role'][:26]
        remote  = job['remote']
        score   = job.get('opportunity_score') or "—"
        print(f"  {i:<4} {company:<22} {role:<28} {remote:<8} {score}")

    print()


def main():
    print()
    print_separator("═")
    print("  iOS Opportunity Radar — Phase 1 Test Run")
    print_separator("═")
    print()

    # ── Step 1: Run all scrapers ─────────────────────────────────────────────
    # In Phase 3 we'll add more scrapers to this list.
    # For now, just RemoteOK.
    scrapers = [
        RemoteOKScraper(),
        # HackerNewsScraper(),    ← add in Phase 3
        # YCStartupScraper(),     ← add in Phase 3
        # IndeedScraper(),        ← add in Phase 3
    ]

    all_raw_jobs = []
    for scraper in scrapers:
        jobs = scraper.run()
        all_raw_jobs.extend(jobs)   # extend adds all items from `jobs` to the list

    print()
    print_separator()
    print(f"  Total raw jobs across all sources: {len(all_raw_jobs)}")
    print_separator()

    # ── Step 2: Deduplicate ──────────────────────────────────────────────────
    unique_jobs = deduplicate(all_raw_jobs)

    # ── Step 3: Show results ─────────────────────────────────────────────────
    print()
    print_separator("═")
    print(f"  RESULTS: {len(unique_jobs)} unique iOS opportunities found")
    print_separator("═")
    print_job_table(unique_jobs)

    # ── Step 4: Show details for the first result ────────────────────────────
    if unique_jobs:
        print_separator()
        print("  First result in full detail:")
        print_separator()
        first = unique_jobs[0]
        for key, value in first.items():
            if key == "description_raw":
                # Truncate long descriptions for readability
                display = str(value)[:120] + "..." if len(str(value)) > 120 else value
            else:
                display = value
            print(f"  {key:<22} {display}")
        print()

    # ── Phase 2 preview ──────────────────────────────────────────────────────
    print_separator()
    print("  Phase 1 complete. Jobs are not yet saved to a database.")
    print("  In Phase 2, we'll set up PostgreSQL and these jobs")
    print("  will be written to a real database automatically.")
    print_separator()
    print()

    return unique_jobs


if __name__ == "__main__":
    main()