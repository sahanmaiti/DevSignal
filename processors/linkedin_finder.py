# processors/linkedin_finder.py
#
# PURPOSE:
#   Finds LinkedIn profile URLs for recruiters and iOS team leads
#   at a given company, using Google Search via Serper.dev API.
#
# WHY SERPER AND NOT DIRECT LINKEDIN:
#   LinkedIn blocks all scraping aggressively.
#   Google indexes public LinkedIn profiles and returns them in search results.
#   Serper.dev provides a clean API to query Google — 2,500 free searches to start.
#
# FREE TIER: serper.dev — 2,500 searches free on signup, then 100/month
#
# PLACEMENT: processors/linkedin_finder.py

import os
import sys
import re
import time
import requests

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import SERPER_API_KEY


SERPER_API_URL = "https://google.serper.dev/search"

# LinkedIn URL pattern for personal profiles (not company pages)
LINKEDIN_PROFILE_RE = re.compile(
    r'https?://(?:www\.)?linkedin\.com/in/[a-zA-Z0-9\-_%]+/?'
)


class LinkedInFinder:
    """
    Finds LinkedIn profile URLs for company contacts using Google Search.
    """

    def __init__(self):
        self.api_key = SERPER_API_KEY
        self.enabled = bool(self.api_key)

        if not self.enabled:
            print("[LinkedIn] No SERPER_API_KEY configured.")
            print("[LinkedIn] Get a free key at serper.dev")

    def find_recruiter(self, company: str, role: str = "") -> dict:
        """
        Searches for a recruiter or iOS team lead at a company.

        Returns:
        {
            "name":     "Jane Smith",
            "title":    "iOS Engineering Manager at Stripe",
            "linkedin": "https://linkedin.com/in/janesmith",
        }
        or {} if not found.
        """
        if not self.enabled or not company:
            return {}

        # Clean the company name for search
        company_clean = self._clean_company_name(company)

        # Try multiple search queries from most specific to broadest
        queries = [
            f'site:linkedin.com/in "{company_clean}" "iOS" recruiter',
            f'site:linkedin.com/in "{company_clean}" "engineering manager" "iOS"',
            f'site:linkedin.com/in "{company_clean}" "talent" OR "recruiting"',
            f'site:linkedin.com/in "{company_clean}" iOS engineer',
        ]

        for query in queries:
            results = self._search(query)
            if results:
                parsed = self._parse_best_result(results, company_clean)
                if parsed:
                    return parsed
            time.sleep(0.5)   # be polite between queries

        return {}

    def _search(self, query: str) -> list:
        """
        Executes a Google search via Serper.dev and returns organic results.
        """
        try:
            response = requests.post(
                SERPER_API_URL,
                headers={
                    "X-API-KEY":    self.api_key,
                    "Content-Type": "application/json",
                },
                json={
                    "q":   query,
                    "num": 5,       # top 5 results is enough
                },
                timeout=10,
            )

            if response.status_code == 401:
                print("[LinkedIn] Invalid Serper API key")
                return []

            if response.status_code == 429:
                print("[LinkedIn] Serper rate limit hit")
                return []

            if response.status_code != 200:
                return []

            return response.json().get("organic", [])

        except requests.exceptions.RequestException as e:
            print(f"[LinkedIn] Search request failed: {e}")
            return []

    def _parse_best_result(self, results: list,
                            company: str) -> dict | None:
        """
        Picks the best LinkedIn profile from search results.

        A "good" result:
        - Has a linkedin.com/in/ URL (personal profile, not company page)
        - Title mentions the company name
        - Title suggests a relevant role (recruiter, manager, iOS)
        """
        for result in results:
            link  = result.get("link", "")
            title = result.get("title", "")
            snippet = result.get("snippet", "")

            # Must be a personal LinkedIn profile
            if not LINKEDIN_PROFILE_RE.match(link):
                continue

            # Title should mention the company
            company_lower = company.lower()
            if company_lower not in title.lower() and company_lower not in snippet.lower():
                continue

            # Extract name from title
            # LinkedIn titles are typically: "Name - Title at Company | LinkedIn"
            name = self._extract_name_from_title(title)

            # Extract role/title
            role_title = self._extract_role_from_title(title)

            return {
                "name":     name,
                "title":    role_title,
                "linkedin": self._clean_linkedin_url(link),
            }

        return None

    def _extract_name_from_title(self, title: str) -> str:
        """
        Extracts person's name from a LinkedIn search result title.
        "Jane Smith - iOS Manager at Stripe | LinkedIn" → "Jane Smith"
        """
        # Remove " | LinkedIn" suffix
        title = re.sub(r'\s*\|\s*LinkedIn\s*$', '', title, flags=re.IGNORECASE)

        # Split on " - " and take the first part
        if " - " in title:
            return title.split(" - ")[0].strip()

        # Split on " | " and take the first part
        if " | " in title:
            return title.split(" | ")[0].strip()

        return title[:50].strip()

    def _extract_role_from_title(self, title: str) -> str:
        """
        Extracts the job title from a LinkedIn search result title.
        "Jane Smith - iOS Manager at Stripe | LinkedIn" → "iOS Manager at Stripe"
        """
        title = re.sub(r'\s*\|\s*LinkedIn\s*$', '', title, flags=re.IGNORECASE)
        if " - " in title:
            parts = title.split(" - ", 1)
            return parts[1].strip() if len(parts) > 1 else ""
        return ""

    def _clean_linkedin_url(self, url: str) -> str:
        """Normalises a LinkedIn profile URL."""
        # Remove tracking parameters
        url = url.split("?")[0]
        # Ensure it uses https
        url = url.replace("http://", "https://")
        # Remove trailing slash
        return url.rstrip("/")

    def _clean_company_name(self, company: str) -> str:
        """
        Strips HTML, special chars and suffixes for better search results.
        """
        # Strip HTML tags
        clean = re.sub(r'<[^>]+>', '', company)

        # Decode HTML entities
        import html
        clean = html.unescape(clean)

        # Split on comma or parenthesis, keep first chunk
        clean = re.split(r'[,\(]', clean)[0].strip()

        # Remove trailing Inc/Ltd/LLC
        clean = re.sub(
            r'\s+(inc|ltd|llc|gmbh)\.?$',
            '',
            clean,
            flags=re.IGNORECASE
        ).strip()

        return clean[:50]


# ─────────────────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing LinkedIn Finder...")
    print("=" * 55)

    finder = LinkedInFinder()

    if not finder.enabled:
        print("\nSerper API key not configured.")
        print("Add SERPER_API_KEY to .env to test.")
        print("\nTesting name extraction logic only:")

        # Test without API
        test_titles = [
            "Jane Smith - iOS Engineering Manager at Stripe | LinkedIn",
            "John Doe - Senior Recruiter at Figma | LinkedIn",
            "Sarah Kim | iOS Team Lead | Mercury | LinkedIn",
        ]
        for t in test_titles:
            result = {
                "name":  finder._extract_name_from_title(t),
                "title": finder._extract_role_from_title(t),
            }
            print(f"\n  Title:   {t[:60]}")
            print(f"  Name:    {result['name']}")
            print(f"  Role:    {result['title']}")
    else:
        # Live test
        print("\nSearching for iOS recruiter at Mercury (banking app)...")
        result = finder.find_recruiter("Mercury", "iOS Developer")

        if result:
            print(f"\n  Name:     {result.get('name', 'Not found')}")
            print(f"  Title:    {result.get('title', 'Not found')}")
            print(f"  LinkedIn: {result.get('linkedin', 'Not found')}")
        else:
            print("  No result found (company may not have public LinkedIn profiles indexed)")