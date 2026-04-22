# scrapers/hackernews_scraper.py
#
# PURPOSE:
#   Scrapes iOS/Swift job postings from HackerNews "Who is Hiring?" threads
#   using the free Algolia HN Search API.
#
# WHY HN IS VALUABLE:
#   HN job posts are written by founders and engineers directly —
#   not HR-sanitized job descriptions. They're more honest about
#   stack, culture, and compensation. Many early-stage startups
#   post here before they have a careers page.
#
# API: https://hn.algolia.com/api/v1/search
# FREE: No auth, no rate limits for reasonable use
#
# PLACEMENT: scrapers/hackernews_scraper.py

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


class HackerNewsScraper(BaseScraper):
    """
    Scraper for HackerNews "Who is Hiring?" monthly threads.

    Searches for iOS/Swift mentions in job comments posted
    in the current and previous month's hiring threads.
    """

    SOURCE_NAME = "HackerNews"
    API_URL     = "https://hn.algolia.com/api/v1/search"

    # Search queries to run — we run multiple to cast a wide net
    SEARCH_QUERIES = [
        "iOS Swift intern",
        "iOS developer intern",
        "SwiftUI intern",
        "junior iOS engineer",
    ]

    def fetch_jobs(self) -> list[dict]:
        """
        Runs multiple searches against the Algolia HN API,
        combines results, and returns iOS-relevant job dicts.
        """
        all_hits = []
        seen_ids = set()   # prevent duplicates across multiple searches

        for query in self.SEARCH_QUERIES:
            params = {
                "query":       query,
                "tags":        "comment",    # job posts are comments on the "Who is Hiring" story
                "hitsPerPage": 100,
            }

            response = self.session.get(self.API_URL, params=params, timeout=15)
            response.raise_for_status()
            data = response.json()

            for hit in data.get("hits", []):
                hit_id = hit.get("objectID", "")

                # Skip if we already collected this post from a previous query
                if hit_id in seen_ids:
                    continue

                # Skip if no actual text content
                comment_text = hit.get("comment_text", "")
                if not comment_text or len(comment_text) < 50:
                    continue

                # Only keep posts from "Who is Hiring?" threads
                story_title = hit.get("story_title", "").lower()
                if "who is hiring" not in story_title and "hiring" not in story_title:
                    continue

                seen_ids.add(hit_id)
                all_hits.append(hit)

        # Now filter for iOS relevance and build job dicts
        ios_jobs = []
        for hit in all_hits:
            comment_text = hit.get("comment_text", "")
            text_lower   = comment_text.lower()

            # Must contain at least one iOS/Swift keyword
            if not self._is_ios_relevant(text_lower):
                continue

            # Skip if seniority exclusions found in the first line
            # (first line of HN job post is usually "Company | Role | Location")
            first_line = comment_text.split("\n")[0].lower()
            if self._should_exclude(first_line):
                continue

            ios_jobs.append(self._build_job_dict(hit, comment_text))

        return ios_jobs

    def _is_ios_relevant(self, text: str) -> bool:
        """Returns True if any iOS role or tech keyword is present."""
        for kw in IOS_ROLE_KEYWORDS:
            if kw in text:
                return True
        for kw in IOS_TECH_KEYWORDS:
            if kw in text:
                return True
        return False

    def _should_exclude(self, text: str) -> bool:
        """Returns True if the post is for a senior role we can't apply to."""
        for kw in EXCLUDE_KEYWORDS:
            if kw in text:
                return True
        return False

    def _build_job_dict(self, hit: dict, text: str) -> dict:
        """
        Converts a raw HN comment into our standard job dict format.

        HN job posts follow a loose convention:
        Line 1: "Company | Role | Location | Salary"
        Rest:    free-form description

        We parse line 1 to extract the key fields.
        """
        lines       = text.strip().split("\n")
        first_line  = lines[0] if lines else ""

        # Parse the pipe-separated first line
        parts = [p.strip() for p in first_line.split("|")]

        company  = self._strip_html(parts[0]) if len(parts) > 0 else "Unknown"
        role     = self._strip_html(parts[1]) if len(parts) > 1 else "iOS Engineer"
        location = self._strip_html(parts[2]) if len(parts) > 2 else ""

        # Detect remote from first line or anywhere in the post
        remote = "Yes" if any(
            r in text.lower() for r in ["remote", "wfh", "work from home", "distributed"]
        ) else "Unknown"

        # HN direct link to the comment
        url = f"https://news.ycombinator.com/item?id={hit.get('objectID', '')}"

        return {
            "company":     company.strip(),
            "role":        role.strip(),
            "location":    location.strip() or "See post",
            "remote":      remote,
            "visa":        self._detect_visa(text),
            "experience":  self._extract_experience(text),
            "tags":        self._extract_tags(text),
            "url":         url,
            "description": self._clean_text(text),
        }

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
        """Extracts experience requirement from free text."""
        pattern = r'(\d+\+?\s*(?:–|-|to)?\s*\d*\+?\s*years?(?:\s+of\s+experience)?)'
        match = re.search(pattern, text, re.IGNORECASE)
        return match.group(1).strip() if match else ""

    def _extract_tags(self, text: str) -> str:
        """Finds which iOS/tech keywords appear in the post."""
        text_lower = text.lower()
        found = []
        for kw in IOS_TECH_KEYWORDS:
            if kw in text_lower:
                found.append(kw)
        return ", ".join(found[:8])  # cap at 8 tags

    def _clean_text(self, text: str) -> str:
        """Strips HTML, collapses whitespace, caps at 800 chars."""
        import re as _re
        clean = _re.sub(r'<[^>]+>', ' ', text)
        clean = _re.sub(r'\s+', ' ', clean).strip()
        return clean[:800]

    def _strip_html(self, text: str) -> str:
        """Removes HTML tags and decodes common HTML entities."""
        import re
        import html
        clean = re.sub(r'<[^>]+>', '', text)
        clean = html.unescape(clean)        # converts &amp; → &, &#x2F; → / etc.
        return clean.strip()

# ─────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing HackerNews scraper...")
    print("=" * 55)

    scraper = HackerNewsScraper()
    jobs = scraper.run()

    if not jobs:
        print("\nNo iOS jobs found right now.")
        print("HN 'Who is Hiring' posts are monthly — try mid-month.")
    else:
        print(f"\nTop {min(3, len(jobs))} results:\n")
        for i, job in enumerate(jobs[:3], 1):
            print(f"  {i}. {job['company']} — {job['role']}")
            print(f"     Location: {job['location']}")
            print(f"     Remote:   {job['remote']}")
            print(f"     Tags:     {job['tech_stack']}")
            print(f"     Link:     {job['apply_link']}")
            print()