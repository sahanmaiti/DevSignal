# run_scorer.py
#
# PURPOSE:
#   Standalone script that scores all unscored jobs in the database.
#
#   Run this:
#   1. Once now to score the 44 existing jobs from Phase 3
#   2. Automatically after each scrape run going forward
#      (wired into run_scraper.py in Step 17)
#
# RATE LIMITING:
#   Groq free tier: 30 RPM.
#   We use 2-second delays between calls = 30/min max.
#   44 jobs × 2 calls each (classifier + scorer) × 2s = ~3 minutes total.
#
# USAGE:
#   python run_scorer.py
#   python run_scorer.py --limit 10   (score only 10 jobs, for testing)
#
# PLACEMENT: project root

import sys
import os
import time
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from storage.db_client           import db
from ai.ios_classifier           import IOSClassifier
from ai.scorer                   import OpportunityScorer
from ai.outreach_generator       import OutreachGenerator
from notifications.telegram_bot  import send_high_score_alert
from config.settings             import HIGH_SCORE_ALERT_THRESHOLD


def print_line(char="─", width=60):
    print(char * width)


def main(limit: int = None):
    print()
    print_line("═")
    print("  DevSignal — AI Scorer")
    print_line("═")

    # ── Fetch unscored jobs from database ─────────────────────────────────
    print("\n[DB] Fetching unscored jobs...")
    unscored = db.get_unscored_jobs()

    if not unscored:
        print("[DB] No unscored jobs found — all jobs already have scores.")
        print("     Run python run_scraper.py first to add new jobs.")
        return []

    if limit:
        unscored = unscored[:limit]
        print(f"[DB] Limiting to {limit} jobs (--limit flag)")

    print(f"[DB] Found {len(unscored)} jobs to score")
    print_line()

    # ── Initialise AI modules ─────────────────────────────────────────────
    try:
        classifier = IOSClassifier()
        scorer     = OpportunityScorer()
        generator  = OutreachGenerator(min_score=65)
    except ValueError as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)

    # ── Step 1: Classify iOS product for each job ─────────────────────────
    print("\n[Classifier] Checking which companies build iOS products...")
    ios_results     = {}   # {job_id: bool}
    ios_descriptions = {}  # {job_id: str reason}

    for i, job in enumerate(unscored):
        job_id  = job["id"]
        company = job.get("company", "?")[:30]

        print(f"  [{i+1}/{len(unscored)}] {company:<30}", end=" ")

        result = classifier.classify(job)
        ios_results[job_id]      = result.get("builds_ios")
        ios_descriptions[job_id] = result.get("reason", "")

        verdict = "iOS" if result.get("builds_ios") else "not iOS"
        print(f"→ {verdict}")

        # Small delay only when we actually made an API call
        # (heuristic results don't need a delay)
        if result.get("reason", "").startswith("Job explicitly") is False:
            time.sleep(1.5)

    print_line()

    # ── Step 2: Score each job ────────────────────────────────────────────
    print("\n[Scorer] Scoring all jobs...")
    scored_jobs = []   # list of (job, score_result)

    for i, job in enumerate(unscored):
        job_id      = job["id"]
        ios_product = ios_results.get(job_id)

        print(f"  [{i+1}/{len(unscored)}] {job.get('company','?')[:30]:<30}", end=" ")

        score_result = scorer.score(job, ios_product=ios_product)
        scored_jobs.append((job, score_result))

        score = score_result["score"]
        print(f"→ {score}/100")

        # Persist score to database immediately
        # (so partial runs aren't lost if something fails)
        db.update_score(
            job_id=job_id,
            score=score,
            breakdown=score_result.get("breakdown", {}),
            outreach_message="",   # filled in next step
        )

        # Send high-score alert if this is exceptional
        if score >= HIGH_SCORE_ALERT_THRESHOLD:
            print(f"  [Alert] Score {score} >= {HIGH_SCORE_ALERT_THRESHOLD} — sending alert!")
            alert_job = {**job, "opportunity_score": score}
            send_high_score_alert(alert_job)

        time.sleep(2)   # respect rate limit

    print_line()

    # ── Step 3: Generate outreach messages for top jobs ───────────────────
    print("\n[Outreach] Generating personalized messages...")

    for i, (job, score_result) in enumerate(scored_jobs):
        job_id  = job["id"]
        score   = score_result["score"]

        if score < 65:
            continue    # skip low-score jobs

        ios_desc = ios_descriptions.get(job_id, "")
        company  = job.get("company", "?")[:30]

        print(f"  {company:<30}", end=" ")

        message = generator.generate(
            job=job,
            ios_product_desc=ios_desc,
            score=score,
        )

        if message:
            # Update the outreach message in the database
            db.update_score(
                job_id=job_id,
                score=score,
                breakdown=score_result.get("breakdown", {}),
                outreach_message=message,
            )
            print(f"✓ ({len(message)} chars)")
        else:
            print("skipped")

        time.sleep(2)

    # ── Summary ───────────────────────────────────────────────────────────
    print()
    print_line("═")
    print("  Scoring Complete")
    print_line("═")

    scores        = [r["score"] for _, r in scored_jobs]
    avg_score     = sum(scores) / len(scores) if scores else 0
    high_scores   = [s for s in scores if s >= 70]
    alert_scores  = [s for s in scores if s >= HIGH_SCORE_ALERT_THRESHOLD]

    print(f"\n  Jobs scored:      {len(scored_jobs)}")
    print(f"  Average score:    {avg_score:.1f}/100")
    print(f"  Score >= 70:      {len(high_scores)} jobs")
    print(f"  Score >= {HIGH_SCORE_ALERT_THRESHOLD}:      {len(alert_scores)} jobs (alerts sent)")
    print()

    # Show top 5
    top_jobs = sorted(scored_jobs, key=lambda x: x[1]["score"], reverse=True)[:5]
    if top_jobs:
        print("  Top 5 opportunities:")
        print(f"  {'Score':<8} {'Company':<25} {'Role'}")
        print(f"  {'─'*8} {'─'*25} {'─'*30}")
        for job, result in top_jobs:
            print(
                f"  {result['score']:<8} "
                f"{job.get('company','?')[:23]:<25} "
                f"{job.get('role','?')[:30]}"
            )
    print_line("═")
    print()

    return scored_jobs


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="DevSignal AI Scorer")
    parser.add_argument(
        "--limit", type=int, default=None,
        help="Score only N jobs (for testing)"
    )
    args = parser.parse_args()
    main(limit=args.limit)