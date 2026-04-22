# scrapers/yc_scraper.py
#
# PURPOSE:
#   Fetches iOS/Swift job listings from Y Combinator's WorkAtAStartup board.
#
# WHY YC IS VALUABLE:
#   Every company is YC-vetted and funded. Jobs here come with company
#   context: batch (S23, W24), team size, funding stage. YC companies
#   tend to move fast and hire interns who can contribute immediately.
#
# API: https://www.workatastartup.com/jobs (public, no auth)
#
# PLACEMENT: scrapers/yc_scraper.py

import sys
import os
import re

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import (
    IOS_ROLE_KEYWORDS,
    IOS_TECH_KEYWORDS,
    EXCLUDE_KEYWORDS,
    VISA_POSITIVE_PHRASES,
)


class YCScraper(BaseScraper):
    """
    Scraper for Y Combinator's WorkAtAStartup job board.
    Targets iOS/Swift roles at YC-backed startups.
    """

    SOURCE_NAME = "YC WorkAtAStartup"

    # Search endpoint with iOS-relevant query
    SEARCH_URLS = [
        "https://www.workatastartup.com/jobs?q=iOS&role=eng&remote=true",
        "https://www.workatastartup.com/jobs?q=Swift&role=eng",
        "https://www.workatastartup.com/jobs?q=iOS+intern&role=eng",
    ]

    # Fallback: the API endpoint if the HTML approach is blocked
    API_URL = "https://www.workatastartup.com/api/v2/jobs"

    def fetch_jobs(self) -> list[dict]:
        """
        Attempts to fetch YC jobs via the API endpoint.
        Falls back to RSS/HTML parsing if blocked.
        """
        jobs = self._fetch_via_api()
        if not jobs:
            jobs = self._fetch_via_html()
        return jobs

    def _fetch_via_api(self) -> list[dict]:
        """
        Tries the JSON API endpoint first.
        YC sometimes requires a browser session — if blocked returns [].
        """
        try:
            params = {
                "q":      "iOS Swift",
                "role":   "eng",
                "limit":  50,
            }
            resp = self.session.get(self.API_URL, params=params, timeout=15)

            # If we get a non-JSON response or error, fall through
            if resp.status_code != 200:
                return []

            data = resp.json()

            # Handle different response shapes
            jobs_raw = []
            if isinstance(data, list):
                jobs_raw = data
            elif isinstance(data, dict):
                jobs_raw = data.get("jobs", data.get("data", []))

            return self._parse_api_jobs(jobs_raw)

        except Exception:
            return []

    def _fetch_via_html(self) -> list[dict]:
        """
        Falls back to parsing the Algolia-powered search if the API is blocked.
        Uses the public Algolia index that powers workatastartup.com.
        """
        try:
            # YC uses Algolia internally — we can query it directly
            algolia_url = "https://45bwzj1sgc-dsn.algolia.net/1/indexes/*/queries"

            headers = {
                "x-algolia-api-key":    "0b9f487fcb29d0dda421a1bf86c3ae59",
                "x-algolia-application-id": "45BWZJ1SGC",
                "Content-Type": "application/json",
            }

            payload = {
                "requests": [
                    {
                        "indexName": "jobs",
                        "params": "query=iOS Swift&hitsPerPage=50&filters=role:eng",
                    }
                ]
            }

            resp = self.session.post(algolia_url, json=payload,
                                     headers=headers, timeout=15)
            if resp.status_code != 200:
                return []

            results = resp.json().get("results", [{}])[0]
            hits = results.get("hits", [])

            return self._parse_algolia_hits(hits)

        except Exception:
            return []

    def _parse_api_jobs(self, jobs_raw: list) -> list[dict]:
        """Converts raw API job objects to our standard format."""
        ios_jobs = []

        for job in jobs_raw:
            title   = job.get("title", "")
            company = job.get("company", {})
            if isinstance(company, dict):
                company_name = company.get("name", "")
            else:
                company_name = str(company)

            text_to_check = (
                title + " " +
                job.get("description", "") + " " +
                " ".join(job.get("skills", []))
            ).lower()

            if not self._is_ios_relevant(text_to_check):
                continue
            if self._should_exclude(title.lower()):
                continue

            job_id  = job.get("id", "")
            slug    = job.get("slug", "")
            url     = f"https://www.workatastartup.com/jobs/{job_id}" if job_id else ""
            if slug:
                url = f"https://www.workatastartup.com/jobs/{slug}"

            ios_jobs.append({
                "company":     company_name,
                "role":        title,
                "location":    job.get("location", ""),
                "remote":      "Yes" if job.get("remote") else "Unknown",
                "visa":        "Unknown",
                "experience":  job.get("experience", ""),
                "tags":        ", ".join(job.get("skills", [])[:8]),
                "url":         url,
                "description": job.get("description", "")[:800],
            })

        return ios_jobs

    def _parse_algolia_hits(self, hits: list) -> list[dict]:
        """Converts Algolia search hits to our standard format."""
        ios_jobs = []

        for hit in hits:
            title        = hit.get("title", hit.get("job_title", ""))
            company_name = hit.get("company_name", hit.get("company", ""))
            description  = hit.get("description", hit.get("body", ""))

            text_to_check = (title + " " + description).lower()

            if not self._is_ios_relevant(text_to_check):
                continue
            if self._should_exclude(title.lower()):
                continue

            job_id = hit.get("objectID", hit.get("id", ""))
            url    = f"https://www.workatastartup.com/jobs/{job_id}"

            ios_jobs.append({
                "company":     company_name,
                "role":        title,
                "location":    hit.get("locations", [""])[0] if hit.get("locations") else "",
                "remote":      "Yes" if hit.get("remote") else "Unknown",
                "visa":        "Unknown",
                "experience":  "",
                "tags":        ", ".join(hit.get("skills", [])[:8]),
                "url":         url,
                "description": description[:800],
            })

        return ios_jobs

    def _is_ios_relevant(self, text: str) -> bool:
        for kw in IOS_ROLE_KEYWORDS:
            if kw in text:
                return True
        for kw in IOS_TECH_KEYWORDS:
            if kw in text:
                return True
        return False

    def _should_exclude(self, text: str) -> bool:
        for kw in EXCLUDE_KEYWORDS:
            if kw in text:
                return True
        return False


# ─────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing YC WorkAtAStartup scraper...")
    print("=" * 55)

    scraper = YCScraper()
    jobs = scraper.run()

    if not jobs:
        print("\nNo iOS jobs found right now from YC.")
        print("Try: https://www.workatastartup.com/jobs?q=iOS")
    else:
        print(f"\nTop {min(3, len(jobs))} results:\n")
        for i, job in enumerate(jobs[:3], 1):
            print(f"  {i}. {job['company']} — {job['role']}")
            print(f"     Remote: {job['remote']}")
            print(f"     Link:   {job['apply_link']}")
            print()