# run_scorer.py
#
# Scores unscored jobs AND generates outreach messages.
#
# MODES:
#   python run_scorer.py                  # score all unscored jobs
#   python run_scorer.py --limit 5        # score only 5 (testing)
#   python run_scorer.py --outreach-only  # regenerate outreach for scored jobs missing it
#   python run_scorer.py --all            # re-score everything from scratch

import sys, os, time, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from storage.db_client          import db
from ai.ios_classifier          import IOSClassifier
from ai.scorer                  import OpportunityScorer
from ai.outreach_generator      import OutreachGenerator
from notifications.telegram_bot import send_high_score_alert
from config.settings            import HIGH_SCORE_ALERT_THRESHOLD, GROQ_API_KEY
from sqlalchemy                 import create_engine, text
from config.settings            import DATABASE_URL


def print_line(char="─", width=60):
    print(char * width)


def get_jobs_missing_outreach() -> list:
    """
    Returns scored jobs that have no outreach message.
    Used by --outreach-only mode.
    """
    sql = text("""
        SELECT id, company, role, location, remote,
               visa_sponsorship, experience_req, tech_stack,
               description_raw, apply_link, date_found,
               job_source, opportunity_score
        FROM opportunities
        WHERE opportunity_score IS NOT NULL
          AND (outreach_message IS NULL OR TRIM(outreach_message) = '')
        ORDER BY opportunity_score DESC
    """)
    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        rows = conn.execute(sql).fetchall()
        cols = conn.execute(sql).keys() if False else [
            "id", "company", "role", "location", "remote",
            "visa_sponsorship", "experience_req", "tech_stack",
            "description_raw", "apply_link", "date_found",
            "job_source", "opportunity_score"
        ]
    return [dict(zip(cols, row)) for row in rows]


def get_all_jobs_for_rescore() -> list:
    """Returns ALL jobs for full rescore."""
    sql = text("""
        SELECT id, company, role, location, remote,
               visa_sponsorship, experience_req, tech_stack,
               description_raw, apply_link, date_found, job_source
        FROM opportunities
        ORDER BY date_found DESC
    """)
    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        rows = conn.execute(sql).fetchall()
    return [dict(row._mapping) for row in rows]


def update_outreach_only(job_id: int, outreach_message: str):
    """Updates only the outreach_message field — doesn't touch the score."""
    sql = text("""
        UPDATE opportunities
        SET outreach_message = :msg
        WHERE id = :job_id
    """)
    engine = create_engine(DATABASE_URL)
    with engine.begin() as conn:
        conn.execute(sql, {"msg": outreach_message, "job_id": job_id})


def score_jobs(jobs: list, rescore: bool = False):
    """Core scoring loop — runs classifier + scorer + outreach per job."""
    if not jobs:
        print("[Scorer] No jobs to process.")
        return []

    print(f"\n[Scorer] Processing {len(jobs)} jobs...")
    print_line()

    try:
        classifier = IOSClassifier()
        scorer     = OpportunityScorer()
        generator  = OutreachGenerator(min_score=65)
    except ValueError as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)

    scored_jobs = []
    total       = len(jobs)

    for i, job in enumerate(jobs):
        job_id  = job["id"]
        company = job.get("company", "?")[:30]

        print(f"\n  [{i+1}/{total}] {company}")

        # Classifier
        try:
            cls     = classifier.classify(job)
            ios_p   = cls.get("builds_ios")
            ios_r   = cls.get("reason", "")
        except Exception as e:
            print(f"    Classifier: {e}")
            ios_p, ios_r = None, ""

        # Scorer
        try:
            result    = scorer.score(job, ios_product=ios_p)
            score     = result["score"]
            breakdown = result.get("breakdown", {})
            summary   = result.get("summary", "")
            print(f"    Score: {score}/100 — {summary[:55]}")
        except Exception as e:
            print(f"    Scorer: {e}")
            score, breakdown, summary = 0, {}, "failed"

        # Outreach
        outreach = ""
        if score >= 65 and GROQ_API_KEY:
            try:
                outreach = generator.generate(
                    job=job,
                    ios_product_desc=ios_r,
                    score=score,
                )
                if outreach:
                    print(f"    Outreach: {len(outreach)} chars ✓")
                else:
                    print(f"    Outreach: skipped (below threshold or generation failed)")
            except Exception as e:
                print(f"    Outreach: {e}")

        # Write to DB — always write score + outreach together
        try:
            db.update_score(
                job_id=job_id,
                score=score,
                breakdown=breakdown,
                outreach_message=outreach,
            )
        except Exception as e:
            print(f"    DB write failed: {e}")

        # High score alert
        if score >= HIGH_SCORE_ALERT_THRESHOLD:
            print(f"    ★ HIGH SCORE ({score}) — sending alert")
            try:
                send_high_score_alert({
                    **job,
                    "opportunity_score": score,
                    "outreach_message": outreach,
                })
            except Exception:
                pass

        scored_jobs.append((job, result))

        if i < total - 1:
            time.sleep(2)

    return scored_jobs


def outreach_only_mode(jobs: list):
    """
    Generates outreach for already-scored jobs that have no message.
    Does NOT re-run the scorer — just fills in the missing outreach.
    """
    if not jobs:
        print("[Outreach] All scored jobs already have outreach messages.")
        return

    print(f"\n[Outreach] Generating messages for {len(jobs)} jobs missing outreach...")
    print_line()

    if not GROQ_API_KEY:
        print("[Outreach] GROQ_API_KEY not set — cannot generate messages")
        return

    try:
        generator = OutreachGenerator(min_score=0)   # min_score=0 to process all
    except ValueError as e:
        print(f"[ERROR] {e}")
        return

    done = 0
    for i, job in enumerate(jobs):
        job_id  = job["id"]
        score   = job.get("opportunity_score", 0) or 0
        company = job.get("company", "?")[:30]

        print(f"  [{i+1}/{len(jobs)}] {company} (score: {score})", end=" ")

        if score < 65:
            print("→ skipped (score < 65)")
            continue

        try:
            message = generator.generate(
                job=job,
                ios_product_desc="",
                score=score,
            )
            if message:
                update_outreach_only(job_id, message)
                print(f"→ ✓ {len(message)} chars")
                done += 1
            else:
                print("→ generation returned empty")
        except Exception as e:
            print(f"→ failed: {e}")

        time.sleep(2)

    print(f"\n[Outreach] Done. {done} messages written to database.")


def verify_outreach_count():
    """Prints how many jobs have outreach messages."""
    try:
        engine = create_engine(DATABASE_URL)
        with engine.connect() as conn:
            total = conn.execute(text("SELECT COUNT(*) FROM opportunities")).scalar()
            scored = conn.execute(text(
                "SELECT COUNT(*) FROM opportunities WHERE opportunity_score IS NOT NULL"
            )).scalar()
            with_outreach = conn.execute(text(
                "SELECT COUNT(*) FROM opportunities "
                "WHERE outreach_message IS NOT NULL AND TRIM(outreach_message) != ''"
            )).scalar()
        print(f"\n[DB] Verification:")
        print(f"     Total jobs:         {total}")
        print(f"     Scored:             {scored}")
        print(f"     With outreach:      {with_outreach}")
        missing = scored - with_outreach
        if missing > 0:
            print(f"     Missing outreach:   {missing} → run with --outreach-only to fix")
    except Exception as e:
        print(f"[DB] Verification failed: {e}")


def main(limit=None, outreach_only=False, rescore_all=False):
    print()
    print_line("═")
    print("  DevSignal — AI Scorer")
    print_line("═")

    if outreach_only:
        # Mode: fill in missing outreach for already-scored jobs
        print("\n[Mode] Outreach-only — generating messages for scored jobs")
        jobs = get_jobs_missing_outreach()
        if limit:
            jobs = jobs[:limit]
        print(f"[DB] Found {len(jobs)} scored jobs missing outreach")
        outreach_only_mode(jobs)

    elif rescore_all:
        # Mode: re-score everything from scratch
        print("\n[Mode] Rescore ALL jobs from scratch")
        jobs = get_all_jobs_for_rescore()
        if limit:
            jobs = jobs[:limit]
        score_jobs(jobs, rescore=True)

    else:
        # Default mode: score unscored jobs only
        jobs = db.get_unscored_jobs()
        if not jobs:
            print("\n[DB] All jobs already scored.")
            verify_outreach_count()
            print("\nTo generate missing outreach messages run:")
            print("  python run_scorer.py --outreach-only")
            return []
        if limit:
            jobs = jobs[:limit]
        score_jobs(jobs)

    verify_outreach_count()
    return []


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="DevSignal AI Scorer")
    parser.add_argument("--limit",          type=int,  default=None,
                        help="Process only N jobs")
    parser.add_argument("--outreach-only",  action="store_true",
                        help="Generate outreach for scored jobs missing messages")
    parser.add_argument("--all",            action="store_true",
                        help="Re-score ALL jobs from scratch")
    args = parser.parse_args()

    main(
        limit=args.limit,
        outreach_only=args.outreach_only,
        rescore_all=args.all,
    )