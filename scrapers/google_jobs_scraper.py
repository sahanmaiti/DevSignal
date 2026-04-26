# Google Jobs via Serper.dev /jobs API
#
# WHY THIS MATTERS:
#   Google indexes job listings from LinkedIn, Glassdoor, Indeed, ZipRecruiter,
#   Monster, and hundreds of ATS systems (Greenhouse, Lever, Ashby) into a
#   unified structured format. One Serper call returns jobs from all of them.
#   This solves LinkedIn/Glassdoor/Indeed geo-blocking in one shot.
#
# QUOTA: Uses SERPER_API_KEY from .env
#   Initial free tier: 2,500 searches
#   Monthly after: 100/month free
#   Strategy: run 4 targeted queries per pipeline run = 4 credits
#
# API: POST https://google.serper.dev/jobs
# DOCS: https://serper.dev/docs (see "Jobs" section)

import sys, os, re, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import requests
from scrapers.base_scraper import BaseScraper
from config.keywords import EXCLUDE_KEYWORDS
from config.settings import SERPER_API_KEY


class GoogleJobsScraper(BaseScraper):
    """
    Scrapes Google's job listing aggregation via Serper.dev's /jobs endpoint.
    Returns structured job data sourced from LinkedIn, Glassdoor, Indeed,
    ZipRecruiter, Greenhouse, Lever, Ashby and many more.

    This is the single most powerful scraper in the system — one call
    returns jobs from platforms that individually block all scraping.
    """

    SOURCE_NAME = "Google Jobs"
    SERPER_URL  = "https://google.serper.dev/jobs"

    # Search queries — each targets a slightly different slice
    # Keep to 4 queries max to be quota-conscious (4 credits per run)
    SEARCH_QUERIES = [
        {"q": "iOS developer intern remote",        "location": "Worldwide"},
        {"q": "Swift SwiftUI intern internship",     "location": "Worldwide"},
        {"q": "junior iOS developer entry level",   "location": "Worldwide"},
        {"q": "iOS intern internship mobile app",   "location": "India"},
    ]

    def fetch_jobs(self) -> list[dict]:
        if not SERPER_API_KEY:
            print("[GoogleJobs] SERPER_API_KEY not set — skipping")
            return []

        ios_jobs  = []
        seen_ids  = set()

        headers = {
            "X-API-KEY":    SERPER_API_KEY,
            "Content-Type": "application/json",
        }

        for query in self.SEARCH_QUERIES:
            try:
                resp = requests.post(
                    self.SERPER_URL,
                    headers=headers,
                    json={
                        "q":          query["q"],
                        "location":   query.get("location", "Worldwide"),
                        "num":        10,      # max per query
                        "gl":         "us",    # Google country
                        "hl":         "en",
                    },
                    timeout=15,
                )
                resp.raise_for_status()
                jobs_data = resp.json().get("jobs", [])

                for job in jobs_data:
                    # Build a dedup key from title + company
                    title   = job.get("title", "")
                    company = job.get("companyName", "")
                    dedup   = f"{title.lower()}|{company.lower()}"

                    if dedup in seen_ids:
                        continue
                    seen_ids.add(dedup)

                    if self._should_exclude(title.lower()):
                        continue

                    # Extract structured fields from Google Jobs data
                    location    = job.get("location", "")
                    posted_date = job.get("detected_extensions", {}).get("posted_at", "")
                    salary      = job.get("detected_extensions", {}).get("salary", "")
                    work_type   = job.get("detected_extensions", {}).get("work_from_home", False)
                    description = job.get("description", "")

                    # Source attribution — Google tells us where the job came from
                    apply_options = job.get("apply_options", [])
                    apply_link    = apply_options[0].get("link", "") if apply_options else ""
                    job_source_site = apply_options[0].get("title", "Google Jobs") if apply_options else "Google Jobs"

                    # Detect remote from location and work_type flag
                    remote = "Yes" if (
                        work_type or
                        "remote" in location.lower() or
                        "remote" in title.lower() or
                        "remote" in description.lower()[:200]
                    ) else "Unknown"

                    ios_jobs.append({
                        "company":    company,
                        "role":       title,
                        "location":   location,
                        "remote":     remote,
                        "visa":       self._detect_visa(description),
                        "experience": self._extract_experience(description),
                        "tags":       self._extract_tags(description + " " + title),
                        "url":        apply_link or f"https://www.google.com/search?q={title}+{company}+jobs",
                        "description": description[:800],
                        "salary":     salary,
                        "via":        job_source_site,   # "via LinkedIn", "via Glassdoor" etc.
                    })

                time.sleep(0.3)   # brief pause between queries

            except requests.exceptions.HTTPError as e:
                if e.response.status_code == 401:
                    print("[GoogleJobs] Invalid Serper API key")
                    break
                elif e.response.status_code == 429:
                    print("[GoogleJobs] Serper rate limit — quota may be exhausted")
                    break
                print(f"[GoogleJobs] Query '{query['q']}' failed: {e}")

            except Exception as e:
                print(f"[GoogleJobs] Query '{query['q']}' error: {e}")

        return ios_jobs

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)

    def _detect_visa(self, text):
        from config.keywords import VISA_POSITIVE_PHRASES
        text_lower = text.lower()
        for phrase in VISA_POSITIVE_PHRASES:
            if phrase in text_lower:
                return "Yes"
        if any(p in text_lower for p in ["no visa", "cannot sponsor", "citizens only"]):
            return "No"
        return "Unknown"

    def _extract_experience(self, text):
        match = re.search(r'(\d+\+?\s*(?:–|-|to)?\s*\d*\+?\s*years?(?:\s+of\s+experience)?)',
                        text, re.IGNORECASE)
        return match.group(1).strip() if match else ""

    def _extract_tags(self, text):
        from config.keywords import IOS_TECH_KEYWORDS
        found = [kw for kw in IOS_TECH_KEYWORDS if kw in text.lower()]
        return ", ".join(found[:8])


if __name__ == "__main__":
    jobs = GoogleJobsScraper().run()
    print(f"\nFound {len(jobs)} iOS jobs via Google Jobs")
    for j in jobs[:5]:
        print(f"  {j['company']} — {j['role']}")
        print(f"    Location: {j['location']} | Remote: {j['remote']}")
        print(f"    Via: {j.get('via', '?')}")
        print(f"    Link: {j['apply_link'][:60]}")
        print()