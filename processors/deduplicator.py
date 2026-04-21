# processors/deduplicator.py
#
# PURPOSE:
#   Removes duplicate jobs from a scraped batch.
#
# PHASE 2 UPGRADE vs PHASE 1:
#   Phase 1 — only deduplicated within the current batch (in-memory).
#   Phase 2 — also checks PostgreSQL so jobs from previous runs are excluded.
#
# HOW IT WORKS:
#   1. Fetch all existing job_hash values from the DB in one query → a Python set
#   2. Walk through the new batch, skipping any hash already in the set
#   3. Also skip duplicates within the batch itself (same job on 2 sources)
#
# PLACEMENT: processors/deduplicator.py

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from storage.db_client import db


def deduplicate(new_jobs: list) -> list:
    """
    Filters a list of new jobs down to only genuinely unseen ones.

    Args:
        new_jobs: list of normalized job dicts from scrapers (all with job_hash set)

    Returns:
        Subset of new_jobs that don't exist in the database and
        aren't duplicated within the batch itself.
    """
    if not new_jobs:
        return []

    print(f"\n[Deduplicator] Checking {len(new_jobs)} jobs against database...")

    # One database query to get all existing hashes as a set
    # This is far more efficient than calling hash_exists() once per job
    try:
        existing_hashes = db.get_all_hashes()
        print(f"[Deduplicator] Found {len(existing_hashes)} existing jobs in database")
    except Exception as e:
        # If DB is unreachable, fall back to in-memory dedup only
        print(f"[Deduplicator] WARNING: Could not reach database ({e})")
        print(f"[Deduplicator] Falling back to in-memory deduplication only")
        existing_hashes = set()

    seen_in_batch = set()   # catches duplicates within this scrape batch
    unique_jobs = []
    skipped_db = 0
    skipped_batch = 0

    for job in new_jobs:
        h = job.get("job_hash", "")

        # Skip jobs with no hash (shouldn't happen, but guard against it)
        if not h:
            continue

        # Already in the database from a previous run?
        if h in existing_hashes:
            skipped_db += 1
            continue

        # Already seen in this batch (same job on multiple platforms)?
        if h in seen_in_batch:
            skipped_batch += 1
            continue

        # New and unique — keep it
        unique_jobs.append(job)
        seen_in_batch.add(h)

    print(f"[Deduplicator] Skipped {skipped_db} already in database")
    print(f"[Deduplicator] Skipped {skipped_batch} duplicates within batch")
    print(f"[Deduplicator] Result: {len(unique_jobs)} genuinely new jobs")

    return unique_jobs