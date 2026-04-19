# processors/deduplicator.py
#
# PURPOSE:
#   Removes duplicate jobs from a list of scraped opportunities.
#
# PHASE 1 VERSION:
#   In-memory only — deduplicates within a single scrape batch.
#   If the same job appears on RemoteOK and HackerNews, one is removed.
#
# PHASE 2 UPGRADE:
#   Will also check against the PostgreSQL database so the same job
#   is never inserted twice across separate scrape runs.

def deduplicate(jobs: list[dict]) -> list[dict]:
    """
    Removes duplicate job listings from a list.

    Uses the job_hash field (set by BaseScraper._generate_hash()) to
    identify duplicates. Two jobs with the same hash are identical.

    Returns the list with duplicates removed, preserving the first occurrence.
    """
    seen_hashes = set()    # A set is like a list but has O(1) lookup speed
    unique_jobs = []

    for job in jobs:
        hash_value = job.get("job_hash", "")

        # If we've seen this hash before, it's a duplicate — skip it
        if not hash_value or hash_value in seen_hashes:
            continue

        # First time seeing this hash — keep it
        seen_hashes.add(hash_value)
        unique_jobs.append(job)

    removed_count = len(jobs) - len(unique_jobs)

    if removed_count > 0:
        print(f"[Deduplicator] Removed {removed_count} duplicate(s). "
              f"{len(unique_jobs)} unique jobs remaining.")
    else:
        print(f"[Deduplicator] No duplicates found. {len(unique_jobs)} unique jobs.")

    return unique_jobs