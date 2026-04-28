# scrapers/google_jobs_scraper.py
#
# Google Jobs via Serper.dev
# Uses /jobs endpoint first (returns structured individual job listings),
# falls back to /search with strict filtering if /jobs returns nothing.

import sys
import os
import re
import time
import requests

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import (
    IOS_ROLE_KEYWORDS,
    IOS_TECH_KEYWORDS,
    EXCLUDE_KEYWORDS,
    VISA_POSITIVE_PHRASES,
)
from config.settings import SERPER_API_KEY


class GoogleJobsScraper(BaseScraper):
    SOURCE_NAME = "Google Jobs"

    SERPER_JOBS = "https://google.serper.dev/jobs"
    SERPER_SEARCH = "https://google.serper.dev/search"

    JOB_QUERIES = [
        "iOS developer intern",
        "Swift SwiftUI intern",
        "junior iOS developer entry level",
        "iOS internship remote",
    ]

    SEARCH_QUERIES = [
        'site:greenhouse.io OR site:lever.co OR site:ashbyhq.com "iOS" intern',
        'site:jobs.ashbyhq.com OR site:boards.greenhouse.io "swift" OR "swiftui" intern',
        '"iOS developer" OR "iOS engineer" internship apply now',
    ]

    def fetch_jobs(self) -> list[dict]:
        if not SERPER_API_KEY:
            print("[GoogleJobs] SERPER_API_KEY not set — skipping")
            return []

        headers = {
            "X-API-KEY": SERPER_API_KEY,
            "Content-Type": "application/json",
        }

        ios_jobs = self._fetch_via_jobs_endpoint(headers)

        if not ios_jobs:
            ios_jobs = self._fetch_via_search_endpoint(headers)

        return ios_jobs

    def _fetch_via_jobs_endpoint(self, headers: dict) -> list[dict]:
        ios_jobs = []
        seen_keys = set()

        for query in self.JOB_QUERIES:
            try:
                resp = requests.post(
                    self.SERPER_JOBS,
                    headers=headers,
                    json={
                        "q": query,
                        "num": 10,
                        "gl": "us",
                        "hl": "en",
                        "location": "Worldwide",
                    },
                    timeout=15,
                )

                if resp.status_code == 403:
                    print("[GoogleJobs] /jobs endpoint unavailable — using /search fallback")
                    return []

                resp.raise_for_status()
                data = resp.json()

                for job in data.get("jobs", []):
                    title = job.get("title", "")
                    link = job.get("link", "")
                    desc = job.get("description", "")
                    company = job.get("companyName", "") or self._extract_company(
                        title, desc, link
                    )

                    if self._is_category_page(title, link):
                        continue

                    if self._should_exclude(title.lower()):
                        continue

                    # Normalise URL for dedup — strip trailing slash
                    link_normalised = (
                        link.lower()
                        .replace("http://", "https://")
                        .rstrip("/")
                    )

                    dedup = (
                        f"{title.lower()[:40]}|"
                        f"{company.lower()[:25]}|"
                        f"{link_normalised[-30:]}"
                    )

                    if dedup in seen_keys:
                        continue

                    seen_keys.add(dedup)

                    ext = job.get("detected_extensions", {})
                    loc = job.get("location", "")

                    ios_jobs.append({
                        "company": company,
                        "role": self._clean_title(title),
                        "location": loc,
                        "remote": "Yes" if (
                            ext.get("work_from_home")
                            or "remote" in loc.lower()
                            or "remote" in desc.lower()[:200]
                        ) else "Unknown",
                        "visa": self._detect_visa(desc),
                        "experience": ext.get("qualifications", "")[:100],
                        "tags": self._extract_tags(title + " " + desc),
                        "url": link,
                        "description": desc[:800],
                        "salary": ext.get("salary", ""),
                    })

                time.sleep(0.3)

            except requests.exceptions.HTTPError as e:
                code = e.response.status_code

                if code == 403:
                    return []

                if code in (401, 429):
                    print(f"[GoogleJobs] /jobs HTTP {code}")
                    break

            except Exception as e:
                print(f"[GoogleJobs] /jobs error: {e}")

        return ios_jobs

    def _fetch_via_search_endpoint(self, headers: dict) -> list[dict]:
        ios_jobs = []
        seen_keys = set()

        for query in self.SEARCH_QUERIES:
            try:
                resp = requests.post(
                    self.SERPER_SEARCH,
                    headers=headers,
                    json={"q": query, "num": 10},
                    timeout=15,
                )

                resp.raise_for_status()
                data = resp.json()

                for result in data.get("organic", []):
                    title = result.get("title", "")
                    snippet = result.get("snippet", "")
                    link = result.get("link", "")

                    if self._is_category_page(title, link):
                        continue

                    if not self._is_individual_posting(link):
                        continue

                    searchable = (title + " " + snippet).lower()

                    if not self._is_ios_relevant(searchable):
                        continue

                    if self._should_exclude(title.lower()):
                        continue

                    dedup = f"{title.lower()[:40]}|{link.rstrip('/')[:50]}"

                    if dedup in seen_keys:
                        continue

                    seen_keys.add(dedup)

                    ios_jobs.append({
                        "company": self._extract_company(title, snippet, link),
                        "role": self._clean_title(title),
                        "location": self._extract_location(snippet),
                        "remote": "Yes" if "remote" in searchable else "Unknown",
                        "visa": self._detect_visa(snippet),
                        "experience": self._extract_experience(snippet),
                        "tags": self._extract_tags(searchable),
                        "url": link,
                        "description": snippet[:800],
                    })

                time.sleep(0.3)

            except Exception as e:
                print(f"[GoogleJobs] /search error: {e}")

        return ios_jobs

    # ---------------------------------------------------
    # Filters
    # ---------------------------------------------------

    def _is_category_page(self, title: str, url: str) -> bool:
        title_lower = title.lower()

        title_patterns = [
            r'^\d+\s+\w+\s+jobs',
            r'\d+\s+jobs?\s+in\b',
            r'jobs?\s+in\s+[a-z]',
            r'now hiring\)',
            r'\$\d+.{0,15}/hr',
            r'^\d+\s+remote',
            r'flexible\s+\w+\s+jobs',
        ]

        for pattern in title_patterns:
            if re.search(pattern, title_lower):
                return True

        url_patterns = [
            r'/jobs/[a-z-]+-jobs/?$',
            r'/jobs/internship-[a-z-]+-jobs',
            r'/Jobs/[A-Z][a-z-]+/?$',
            r'q-[a-z-]+-jobs\.htm',
            r'\?.*q=',
            r'/jobs/search',
            r'/remote-jobs/?$',
            r'/jobs/?$',
        ]

        for pattern in url_patterns:
            if re.search(pattern, url, re.I):
                return True

        return False

    def _is_individual_posting(self, url: str) -> bool:
        patterns = [
            r'greenhouse\.io/.+/jobs/\d+',
            r'lever\.co/[\w-]+/[\w-]+',
            r'ashbyhq\.com/.+',
            r'workable\.com/.+/j/.+',
            r'smartrecruiters\.com/.+/\d+',
            r'jobvite\.com/.+',
            r'/job/\d+',
            r'/jobs/\d+',
            r'/position/[\w-]+',
            r'/apply/',
            r'apply\.',
        ]

        return any(re.search(p, url, re.I) for p in patterns)

    # ---------------------------------------------------
    # Helpers
    # ---------------------------------------------------

    def _is_ios_relevant(self, text: str) -> bool:
        text = text.lower()

        must_have = [
            "ios",
            "swift",
            "swiftui",
            "uikit",
            "iphone",
            "xcode",
        ]

        return any(k in text for k in must_have)

    def _should_exclude(self, text: str) -> bool:
        return any(k in text for k in EXCLUDE_KEYWORDS)

    def _clean_title(self, title: str) -> str:
        title = title.strip()

        if title.endswith(" - Lever"):
            title = title.replace(" - Lever", "")
            parts = title.split(" - ")
            return parts[0].strip()

        if title.startswith("Job Application for "):
            title = title.replace("Job Application for ", "")
            if " at " in title:
                title = title.split(" at ")[0]
            return title.strip()

        if " @ " in title:
            title = title.split(" @ ")[0]

        return title[:180].strip()

    def _extract_company(self, title: str, snippet: str, url: str = "") -> str:
        if " - Lever" in title:
            parts = title.replace(" - Lever", "").split(" - ")
            if len(parts) >= 2:
                return parts[1].strip()

        if "Job Application for " in title and " at " in title:
            return title.split(" at ")[-1].strip()

        if " @ " in title:
            return title.split(" @ ")[-1].strip()

        if "greenhouse.io/" in url:
            m = re.search(r'greenhouse\.io/([^/]+)/jobs', url)
            if m:
                return m.group(1).replace("-", " ").title()

        if "lever.co/" in url:
            m = re.search(r'lever\.co/([^/]+)/', url)
            if m:
                return m.group(1).replace("-", " ").title()

        return ""

    def _extract_location(self, text: str) -> str:
        t = text.lower()

        if "remote" in t:
            return "Remote"

        patterns = [
            r'(new york,\s*ny)',
            r'(san francisco,\s*ca)',
            r'(toronto,\s*on)',
            r'(london)',
            r'(canada)',
            r'(united states)',
            r'(usa)',
        ]

        for p in patterns:
            m = re.search(p, t, re.I)
            if m:
                return m.group(1).title()

        return ""

    def _detect_visa(self, text: str) -> str:
        text = text.lower()

        for phrase in VISA_POSITIVE_PHRASES:
            if phrase in text:
                return "Yes"

        return "Unknown"

    def _extract_experience(self, text: str) -> str:
        m = re.search(
            r'(\d+\+?\s*(?:–|-|to)?\s*\d*\+?\s*years?)',
            text,
            re.I
        )
        return m.group(1).strip() if m else ""

    def _extract_tags(self, text: str) -> str:
        text = text.lower()
        return ", ".join(
            kw for kw in IOS_TECH_KEYWORDS if kw in text
        )[:100]


if __name__ == "__main__":
    jobs = GoogleJobsScraper().run()

    print(f"\nFound {len(jobs)} individual iOS job postings via Google Jobs")

    for j in jobs[:5]:
        print(f"\n  {j['company'] or '?'} — {j['role']}")
        print(f"  Location: {j['location']} | Remote: {j['remote']}")
        print(f"  URL: {j['apply_link'][:80]}")