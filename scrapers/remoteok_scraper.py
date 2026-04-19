# scrapers/remoteok_scraper.py
#
# PURPOSE:
#   Fetches iOS/Swift job listings from RemoteOK's free public JSON API.
#   This is our simplest scraper — no auth, no pagination, clean JSON response.
#
# API ENDPOINT: https://remoteok.com/api
# DOCS: https://remoteok.com/api (see the page for rate limit guidance)
# RATE LIMIT: Be respectful — max 1 request per 30 seconds in production.
#             During development/testing it's fine to call it occasionally.

import sys
import os
import re

# Add the project root to Python's module search path.
# This lets us do `from config.keywords import ...` from anywhere.
# Without this line, Python wouldn't know where "config" is.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import (
    IOS_ROLE_KEYWORDS,
    IOS_TECH_KEYWORDS,
    EXCLUDE_KEYWORDS,
    VISA_POSITIVE_PHRASES,
)


class RemoteOKScraper(BaseScraper):
    """
    Scraper for RemoteOK.com — a popular remote-only job board.

    The API returns a JSON array where:
    - Index 0 is metadata about the API (we skip it)
    - Index 1+ are job listings

    Each job has these useful fields:
    - position: job title
    - company:  company name
    - tags:     list of tech tags like ["swift", "ios", "mobile"]
    - url:      link to the job post
    - date:     ISO 8601 date string
    - salary_min / salary_max: optional salary range
    - description: HTML job description
    - logo:     URL to company logo
    """

    SOURCE_NAME = "RemoteOK"
    API_URL     = "https://remoteok.com/api"

    def fetch_jobs(self) -> list[dict]:
        """
        Calls the RemoteOK API, filters for iOS-relevant jobs,
        and returns them as a list of normalized-ready dicts.
        """
        # Make the HTTP GET request
        # timeout=15 means: if the server doesn't respond in 15 seconds, raise an error
        response = self.session.get(self.API_URL, timeout=15)

        # raise_for_status() checks the HTTP status code.
        # If it's 4xx or 5xx (error), it raises an HTTPError exception.
        # If it's 200 (success), it does nothing and we continue.
        response.raise_for_status()

        # Parse the JSON response body into a Python list
        # response.json() is equivalent to json.loads(response.text)
        all_listings = response.json()

        # The first element is API metadata — skip it with [1:]
        # This is RemoteOK's quirk — check their API docs for explanation
        job_listings = all_listings[1:]

        ios_jobs = []

        for listing in job_listings:
            # Extract the fields we care about
            title       = listing.get("position", "")
            company     = listing.get("company", "")
            tags        = listing.get("tags", [])         # this is a Python list
            description = listing.get("description", "")
            url         = listing.get("url", "")

            # Build a single searchable string from title + tags
            # We lowercase everything for case-insensitive matching
            searchable = (title + " " + " ".join(tags)).lower()

            # Check 1: Is this an iOS-relevant job?
            if not self._is_ios_relevant(searchable):
                continue   # skip this listing, move to the next

            # Check 2: Does it have exclusion keywords?
            if self._should_exclude(title.lower()):
                continue

            # If we passed both checks, this is a good opportunity — keep it
            ios_jobs.append({
                "company":     company,
                "role":        title,
                "location":    "Remote",     # RemoteOK is 100% remote jobs
                "remote":      "Yes",
                "visa":        self._detect_visa(description),
                "experience":  self._extract_experience(description + " " + title),
                "tags":        ", ".join(tags),
                "url":         url,
                "description": self._clean_html(description),
                "salary":      self._format_salary(listing),
            })

        return ios_jobs

    # ─────────────────────────────────────────────────────────────────────────
    # PRIVATE HELPER METHODS
    # These are prefixed with _ by convention, meaning "internal use only"
    # ─────────────────────────────────────────────────────────────────────────

    def _is_ios_relevant(self, text: str) -> bool:
        """
        Returns True if the text contains at least one iOS keyword.
        Checks both role keywords (e.g. "ios intern") and
        tech keywords (e.g. "swiftui").
        """
        for keyword in IOS_ROLE_KEYWORDS:
            if keyword in text:
                return True

        for keyword in IOS_TECH_KEYWORDS:
            if keyword in text:
                return True

        return False

    def _should_exclude(self, title: str) -> bool:
        """
        Returns True if the job title contains a seniority keyword
        that means it's beyond our target level.
        """
        for keyword in EXCLUDE_KEYWORDS:
            if keyword in title:
                return True
        return False

    def _detect_visa(self, description: str) -> str:
        """
        Scans the description for visa sponsorship signals.
        Returns "Yes", "No", or "Unknown".
        """
        text = description.lower()

        for phrase in VISA_POSITIVE_PHRASES:
            if phrase in text:
                return "Yes"

        # Negative signals
        if "no visa" in text or "not able to sponsor" in text or "citizens only" in text:
            return "No"

        return "Unknown"

    def _extract_experience(self, text: str) -> str:
        """
        Tries to find an experience requirement like "1-2 years" or "0+ years".
        Returns a clean string like "1-2 years" or "" if not found.
        """
        # Pattern: look for digits followed by optional dash+digits followed by "year"
        pattern = r'(\d+\+?\s*(?:–|-|to)?\s*\d*\+?\s*years?)'
        match = re.search(pattern, text, re.IGNORECASE)
        return match.group(1).strip() if match else ""

    def _clean_html(self, html: str) -> str:
        """
        Strips HTML tags from a description to get plain text.
        RemoteOK descriptions are HTML — we want readable text for storage.

        Example:
            "<p>We need a <strong>Swift</strong> developer</p>"
            → "We need a Swift developer"
        """
        # Remove all HTML tags: <anything> → space
        clean = re.sub(r'<[^>]+>', ' ', html)
        # Collapse multiple spaces/newlines into a single space
        clean = re.sub(r'\s+', ' ', clean).strip()
        # Limit to 800 characters — enough context without being bloated
        return clean[:800]

    def _format_salary(self, listing: dict) -> str:
        """
        Formats salary_min and salary_max into a readable range.
        Returns "" if no salary data is available.
        """
        salary_min = listing.get("salary_min")
        salary_max = listing.get("salary_max")

        if salary_min and salary_max:
            return f"${int(salary_min):,} – ${int(salary_max):,}/yr"
        elif salary_min:
            return f"${int(salary_min):,}+/yr"
        elif salary_max:
            return f"Up to ${int(salary_max):,}/yr"

        return ""


# ─────────────────────────────────────────────────────────────────────────────
# SELF-TEST
# When you run `python scrapers/remoteok_scraper.py` directly,
# this block executes. When you import this file in another module, it doesn't.
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("Testing RemoteOK scraper directly...")
    print("=" * 55)

    scraper = RemoteOKScraper()
    jobs = scraper.run()

    if not jobs:
        print("\nNo iOS jobs found right now — try again later,")
        print("or check https://remoteok.com/remote-swift-jobs manually.")
    else:
        print(f"\nTop {min(3, len(jobs))} results:\n")
        for i, job in enumerate(jobs[:3], 1):
            print(f"  {i}. {job['company']} — {job['role']}")
            print(f"     Tags:   {job['tech_stack']}")
            print(f"     Salary: {job.get('salary', 'not listed')}")
            print(f"     Visa:   {job['visa_sponsorship']}")
            print(f"     Hash:   {job['job_hash']}")
            print(f"     Link:   {job['apply_link']}")
            print()