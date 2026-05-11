# PURPOSE:
#   Removes duplicate jobs from a scraped batch.

def deduplicate(new_jobs: list) -> list:
    """
    Filters out duplicate jobs within the current scrape batch.

    Cross-run deduplication (jobs already in the database) is handled
    automatically by the UNIQUE constraint on opportunities.job_hash
    combined with ON CONFLICT (job_hash) DO NOTHING in insert_jobs().
    No full-table hash fetch is required.

    Args:
        new_jobs: list of normalised job dicts, each with a job_hash key.

    Returns:
        Subset of new_jobs with within-batch duplicates removed.
    """
    if not new_jobs:
        return []

    print(f"\n[Deduplicator] Checking {len(new_jobs)} jobs for within-batch duplicates...")

    seen_in_batch: set = set()
    unique_jobs: list  = []
    skipped_batch      = 0

    for job in new_jobs:
        h = job.get("job_hash", "")

        if not h:
            # Malformed job — skip silently rather than insert a bad row
            continue

        if h in seen_in_batch:
            skipped_batch += 1
            continue

        unique_jobs.append(job)
        seen_in_batch.add(h)

    print(f"[Deduplicator] Skipped {skipped_batch} within-batch duplicates")
    print(f"[Deduplicator] Passing {len(unique_jobs)} jobs to insert "
        f"(DB will silently drop any that already exist)")

    return unique_jobs