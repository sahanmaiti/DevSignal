# Main pipeline entry point — Phase 4+ version
# Runs all 15 scrapers across 3 tiers, then processes and stores results.
#
# SCRAPER TIERS:
#   Tier 1 — Free public APIs    (always run, no quota)
#   Tier 2 — Google Jobs/Serper  (run if SERPER_API_KEY set)
#   Tier 3 — Direct scraping     (run with rate-limit delays)

import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# ── Tier 1: Free public APIs ──────────────────────────────────────────────
from scrapers.remoteok_scraper      import RemoteOKScraper
from scrapers.hackernews_scraper    import HackerNewsScraper
from scrapers.yc_scraper            import YCScraper
from scrapers.remotive_scraper      import RemotiveScraper
from scrapers.arbeitnow_scraper     import ArbeitnowScraper
from scrapers.himalayas_scraper     import HimalayasScraper
from scrapers.jobspresso_scraper    import JobspressoScraper
from scrapers.weworkremotely_scraper import WeWorkRemotelyScraper
from scrapers.startupjobs_scraper   import StartupJobsScraper

# ── Tier 2: Google Jobs via Serper (covers LinkedIn, Glassdoor, Indeed) ───
from scrapers.google_jobs_scraper   import GoogleJobsScraper

# ── Tier 3: Direct scraping ───────────────────────────────────────────────
from scrapers.wellfound_scraper     import WellfoundScraper
from scrapers.cutshort_scraper      import CutshortScraper
from scrapers.naukri_scraper        import NaukriScraper
from scrapers.indiehackers_scraper  import IndieHackersScraper
from scrapers.producthunt_scraper   import ProductHuntScraper
from scrapers.arc_scraper           import ArcScraper

from processors.job_parser          import parse_jobs
from processors.filter_engine       import filter_jobs
from processors.deduplicator        import deduplicate
from storage.db_client              import db
from notifications.telegram_bot     import send_digest, send_run_summary, send_error_alert
from config.settings                import SERPER_API_KEY


def print_line(char="─", width=65):
    print(char * width)


def run_tier(scrapers: list, tier_name: str,
            delay: float = 0) -> list:
    """Runs a group of scrapers, returns combined raw jobs."""
    print(f"\n{'─'*65}")
    print(f"  {tier_name}")
    print(f"{'─'*65}")

    all_jobs    = []
    tier_counts = {}

    for scraper in scrapers:
        try:
            jobs = scraper.run()
            tier_counts[scraper.SOURCE_NAME] = len(jobs)
            all_jobs.extend(jobs)
            if delay > 0:
                time.sleep(delay)
        except Exception as e:
            print(f"  [{scraper.SOURCE_NAME}] FATAL error: {e}")
            tier_counts[scraper.SOURCE_NAME] = 0

    return all_jobs, tier_counts


def main():
    print()
    print_line("═")
    print("  DevSignal — Full Pipeline  (19 sources)")
    print_line("═")

    run_id       = db.start_scrape_run(triggered_by="manual")
    errors       = ""
    all_raw_jobs = []
    source_counts = {}
    new_jobs     = []
    inserted     = 0

    try:
        # ── TIER 1: Free public APIs ──────────────────────────────────────
        t1_scrapers = [
            RemoteOKScraper(),
            HackerNewsScraper(),
            YCScraper(),
            RemotiveScraper(),
            ArbeitnowScraper(),
            HimalayasScraper(),
            JobspressoScraper(),
            WeWorkRemotelyScraper(),
            StartupJobsScraper(),
        ]
        t1_jobs, t1_counts = run_tier(t1_scrapers, "TIER 1 — Free Public APIs")
        all_raw_jobs.extend(t1_jobs)
        source_counts.update(t1_counts)

        # ── TIER 2: Google Jobs via Serper ────────────────────────────────
        if SERPER_API_KEY:
            t2_scrapers = [GoogleJobsScraper()]
            t2_jobs, t2_counts = run_tier(
                t2_scrapers,
                "TIER 2 — Google Jobs (LinkedIn · Glassdoor · Indeed · more)"
            )
            all_raw_jobs.extend(t2_jobs)
            source_counts.update(t2_counts)
        else:
            print("\n  [Tier 2] Skipped — SERPER_API_KEY not set")
            print("  Get a free key at serper.dev to enable LinkedIn/Glassdoor/Indeed")

        # ── TIER 3: Direct scraping (with delays) ─────────────────────────
        t3_scrapers = [
            WellfoundScraper(),
            CutshortScraper(),
            NaukriScraper(),
            IndieHackersScraper(),
            ProductHuntScraper(),
            ArcScraper(),
        ]
        t3_jobs, t3_counts = run_tier(
            t3_scrapers,
            "TIER 3 — Direct Scraping",
            delay=1.5,
        )
        all_raw_jobs.extend(t3_jobs)
        source_counts.update(t3_counts)

        # ── Summary table ─────────────────────────────────────────────────
        print()
        print_line("═")
        print("  Source breakdown:")
        print_line()
        total_raw = 0
        for source, count in sorted(source_counts.items(),
                                    key=lambda x: x[1], reverse=True):
            bar   = "█" * min(count, 30)
            total_raw += count
            print(f"  {source:<25} {bar} {count}")
        print_line()
        print(f"  {'TOTAL':<25} {total_raw} raw jobs")
        print_line("═")

        # ── Processing ────────────────────────────────────────────────────
        print()
        parsed_jobs   = parse_jobs(all_raw_jobs)
        filtered_jobs = filter_jobs(parsed_jobs)
        new_jobs      = deduplicate(filtered_jobs)

        # ── Database insert ───────────────────────────────────────────────
        print()
        if new_jobs:
            inserted = db.insert_jobs(new_jobs)
            print(f"[DB] Inserted {inserted} new jobs")
        else:
            print("[DB] No new jobs to insert")

        # ── Telegram digest ───────────────────────────────────────────────
        print()
        sent = send_digest(new_jobs if new_jobs else [])
        print(f"[Telegram] Digest {'sent' if sent else 'skipped'}")

        # ── Results table ─────────────────────────────────────────────────
        print()
        print_line("═")
        print(f"  RESULTS: {len(new_jobs)} new jobs saved to DevSignal")
        print_line("═")

        if new_jobs:
            print()
            print(f"  {'#':<4} {'Company':<22} {'Role':<24} {'Source':<15} {'Remote'}")
            print(f"  {'─'*4} {'─'*22} {'─'*24} {'─'*15} {'─'*8}")
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

        # ── DB stats ──────────────────────────────────────────────────────
        stats = db.get_stats()
        print_line()
        print(f"  Database totals:")
        print(f"    Total stored:  {stats.get('total_jobs', 0)}")
        print(f"    Unscored:      {stats.get('unscored_count', 0)}")
        print(f"    Remote jobs:   {stats.get('remote_count', 0)}")
        print(f"    Applied:       {stats.get('total_applied', 0)}")
        print_line()

        # ── Run summary ───────────────────────────────────────────────────
        send_run_summary(
            jobs_found=len(all_raw_jobs),
            jobs_filtered=len(filtered_jobs),
            jobs_new=len(new_jobs),
            jobs_stored=inserted,
            sources=source_counts,
        )

    except Exception as e:
        errors = str(e)
        print(f"\n[ERROR] Pipeline failed: {e}")
        send_error_alert(str(e))
        import traceback; traceback.print_exc()
        raise

    finally:
        db.finish_scrape_run(
            run_id=run_id,
            jobs_found=len(all_raw_jobs),
            jobs_new=len(new_jobs),
            errors=errors,
        )

    print()
    print("  Done. Next: python run_scorer.py")
    print()
    return new_jobs


if __name__ == "__main__":
    main()