# run_enricher.py
#
# PURPOSE:
#   Standalone enrichment runner.
#   Fetches jobs from DB and enriches them with recruiter data.
#
# USAGE:
#   python run_enricher.py                 # enrich all unenriched jobs >= min score
#   python run_enricher.py --min-score 70  # only jobs scoring >= 70
#   python run_enricher.py --limit 5       # only 5 jobs (for testing)
#   python run_enricher.py --all           # enrich ALL jobs regardless of score
#
# PLACEMENT: project root

import sys
import os
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from storage.db_client      import db
from processors.enricher    import Enricher
from processors.hunter_client import HunterClient
from config.settings        import ENRICHMENT_MIN_SCORE


def print_line(char="─", width=60):
    print(char * width)


def main(min_score: int = None, limit: int = None, enrich_all: bool = False):
    print()
    print_line("═")
    print("  DevSignal — Recruiter Enricher")
    print_line("═")

    # Check Hunter quota before starting
    hunter = HunterClient()
    if hunter.enabled:
        quota = hunter.get_remaining_quota()
        print(f"\n[Hunter] Remaining quota this month: "
            f"{quota['searches']} searches")
        if quota['searches'] < 5:
            print("[Hunter] WARNING: Low quota — Hunter calls will be skipped")

    # Determine score threshold
    threshold = 0 if enrich_all else (min_score or ENRICHMENT_MIN_SCORE)

    # Fetch jobs to enrich
    print(f"\n[DB] Fetching jobs with score >= {threshold}...")
    all_jobs = db.get_all_opportunities(min_score=threshold)

    # Filter to only unenriched jobs (no recruiter name yet)
    to_enrich = [
        j for j in all_jobs
        if not j.get("recruiter_name") and not j.get("email")
    ]

    if not to_enrich:
        print("[DB] All qualifying jobs are already enriched.")
        return []

    if limit:
        to_enrich = to_enrich[:limit]

    print(f"[DB] Found {len(to_enrich)} jobs to enrich")
    print_line()

    # Run enrichment
    enricher = Enricher()
    print("\n[Enricher] Starting enrichment...\n")
    results = enricher.enrich_batch(to_enrich)

    # Summary
    print()
    print_line("═")
    print("  Enrichment Summary")
    print_line("═")

    enriched = [(j, r) for j, r in results if r.get("recruiter_name") or r.get("email")]
    print(f"\n  Jobs processed: {len(results)}")
    print(f"  Enriched:       {len(enriched)}")
    print(f"  Empty:          {len(results) - len(enriched)}")

    if enriched:
        print(f"\n  Top enriched jobs:")
        print(f"  {'Company':<25} {'Recruiter':<25} {'Source'}")
        print(f"  {'─'*25} {'─'*25} {'─'*15}")
        for job, enrichment in enriched[:5]:
            print(
                f"  {job.get('company','?')[:23]:<25} "
                f"{enrichment.get('recruiter_name','?')[:23]:<25} "
                f"{enrichment.get('enrichment_source','?')}"
            )
    print_line("═")
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="DevSignal Enricher")
    parser.add_argument("--min-score", type=int, default=None)
    parser.add_argument("--limit",     type=int, default=None)
    parser.add_argument("--all",       action="store_true",
                        help="Enrich all jobs regardless of score")
    args = parser.parse_args()
    main(min_score=args.min_score, limit=args.limit, enrich_all=args.all)