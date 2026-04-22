# scrapers/remotive_scraper.py
#
# PURPOSE:
#   Fetches iOS/Swift job listings from Remotive.io's free public API.
#
# WHY REMOTIVE:
#   Replaces Indeed (which blocks non-US IPs via RSS).
#   Remotive is a remote-jobs-focused board with a clean public API —
#   no authentication, no rate limits for reasonable use, returns JSON.
#   Every job here is remote-friendly by definition.
#
# API: https://remotive.com/api/remote-jobs
# DOCS: https://remotive.com/api/remote-jobs (open in browser to explore)
# FREE: Yes — completely open, no key needed
#
# PLACEMENT: scrapers/remotive_scraper.py

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


class RemotiveScraper(BaseScraper):
    """
    Scraper for Remotive.io — a curated remote job board.

    The API accepts a 'category' parameter and a 'search' parameter.
    We search the 'software-dev' category for iOS/Swift roles.

    API response shape:
    {
      "jobs": [
        {
          "id": 12345,
          "url": "https://remotive.com/remote-jobs/...",
          "title": "iOS Developer",
          "company_name": "Acme Corp",
          "category": "Software Development",
          "tags": ["swift", "ios", "mobile"],
          "job_type": "full_time",
          "publication_date": "2026-04-20T10:00:00",
          "candidate_required_location": "Worldwide",
          "salary": "$80k - $120k",
          "description": "<p>We are looking for...</p>"
        }
      ]
    }
    """

    SOURCE_NAME = "Remotive"
    API_URL     = "https://remotive.com/api/remote-jobs"

    # Search terms to run — Remotive's 'search' param checks title + description
    SEARCH_TERMS = [
        "iOS",
        "Swift",
        "SwiftUI",
    ]

    def fetch_jobs(self) -> list[dict]:
        """
        Runs multiple searches, combines results, filters for iOS relevance.
        """
        all_jobs = []
        seen_ids = set()

        for term in self.SEARCH_TERMS:
            params = {
                "category": "software-dev",
                "search":   term,
                "limit":    50,
            }

            try:
                response = self.session.get(self.API_URL, params=params, timeout=15)
                response.raise_for_status()
                data = response.json()

                for job in data.get("jobs", []):
                    job_id = job.get("id")

                    # Skip already-seen jobs (overlap between search terms)
                    if job_id in seen_ids:
                        continue
                    seen_ids.add(job_id)

                    title = job.get("title", "")
                    tags  = [t.lower() for t in job.get("tags", [])]
                    desc  = job.get("description", "")

                    searchable = (title + " " + " ".join(tags) + " " + desc[:300]).lower()

                    # Must be iOS-relevant
                    if not self._is_ios_relevant(searchable):
                        continue

                    # Skip senior roles
                    if self._should_exclude(title.lower()):
                        continue

                    all_jobs.append(self._build_job(job))

            except Exception as e:
                print(f"[Remotive] Search '{term}' failed: {e}")
                continue

        return all_jobs

    def _build_job(self, job: dict) -> dict:
        """Converts a Remotive API job object to our standard dict format."""

        # Remotive always has remote jobs, but the location field
        # tells us which countries/regions are accepted
        candidate_location = job.get("candidate_required_location", "Worldwide")
        location = candidate_location if candidate_location else "Remote"

        # Tags come as a list — join into comma-separated string
        tags = ", ".join(job.get("tags", [])[:10])

        description_html = job.get("description", "")
        description_text = self._clean_html(description_html)

        return {
            "company":    job.get("company_name", ""),
            "role":       job.get("title", ""),
            "location":   location,
            "remote":     "Yes",              # Remotive is 100% remote jobs
            "visa":       self._detect_visa(description_text),
            "experience": self._extract_experience(description_text),
            "tags":       tags,
            "url":        job.get("url", ""),
            "description": description_text,
            "salary":     job.get("salary", ""),
        }

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

    def _detect_visa(self, text: str) -> str:
        """Scans text for visa sponsorship signals."""
        text_lower = text.lower()
        negative_signals = [
        "no visa", "cannot sponsor", "not able to sponsor",
        "unable to sponsor", "us citizens only", "citizens and permanent residents",
        "must be authorized", "no sponsorship", "not sponsor",
    ]
        for signal in negative_signals:
            if signal in text_lower:
                return "No"
        for phrase in VISA_POSITIVE_PHRASES:
            if phrase in text_lower:
                return "Yes"
        return "Unknown"

    def _extract_experience(self, text: str) -> str:
        pattern = r'(\d+\+?\s*(?:–|-|to)?\s*\d*\+?\s*years?(?:\s+of\s+experience)?)'
        match = re.search(pattern, text, re.IGNORECASE)
        return match.group(1).strip() if match else ""

    def _clean_html(self, html: str) -> str:
        """Strip HTML tags and collapse whitespace."""
        clean = re.sub(r'<[^>]+>', ' ', html)
        clean = re.sub(r'\s+', ' ', clean).strip()
        return clean[:800]


# ─────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing Remotive scraper...")
    print("=" * 55)

    scraper = RemotiveScraper()
    jobs = scraper.run()

    if not jobs:
        print("\nNo iOS jobs found on Remotive right now.")
        print("Check: https://remotive.com/remote-jobs/software-dev?search=iOS")
    else:
        print(f"\nTop {min(5, len(jobs))} results:\n")
        for i, job in enumerate(jobs[:5], 1):
            print(f"  {i}. {job['company']} — {job['role']}")
            print(f"     Location: {job['location']}")
            print(f"     Tags:     {job['tech_stack'][:50]}")
            print(f"     Salary:   {job.get('salary') or 'not listed'}")
            print(f"     Link:     {job['apply_link']}")
            print()