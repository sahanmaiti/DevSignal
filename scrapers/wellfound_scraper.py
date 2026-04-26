# Wellfound (formerly AngelList) — startup job board
# Uses their public search — no auth required for browsing

import sys, os, re, time, json
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import requests
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class WellfoundScraper(BaseScraper):
    SOURCE_NAME = "Wellfound"

    # Wellfound's internal API (used by their own frontend)
    SEARCH_URL = "https://wellfound.com/api/v1/jobs_search"

    # Fallback: their public talent search page
    TALENT_URL = "https://wellfound.com/role/r/ios-engineer"

    def fetch_jobs(self) -> list[dict]:
        # Try the API approach first
        jobs = self._fetch_via_api()
        if jobs:
            return jobs
        # Fall back to scraping the talent page
        return self._fetch_via_scrape()

    def _fetch_via_api(self) -> list[dict]:
        """Attempts to use Wellfound's internal JSON API."""
        headers = {
            **self.session.headers,
            "Accept": "application/json",
            "X-Requested-With": "XMLHttpRequest",
        }

        search_terms = ["iOS intern", "Swift intern", "SwiftUI developer intern"]
        ios_jobs = []
        seen_urls = set()

        for term in search_terms:
            try:
                resp = self.session.get(
                    self.SEARCH_URL,
                    headers=headers,
                    params={
                        "q":      term,
                        "type":   "jobs",
                        "page":   1,
                    },
                    timeout=10,
                )
                if resp.status_code != 200:
                    return []   # API not available, use scrape

                data = resp.json()
                jobs = data.get("jobs", data.get("startupRoles", []))

                for job in jobs:
                    title   = job.get("title", job.get("role", ""))
                    company = job.get("startup", {}).get("name", job.get("companyName", ""))
                    url     = job.get("jobUrl", job.get("url", ""))

                    if not url or url in seen_urls:
                        continue
                    seen_urls.add(url)

                    searchable = (title + " " + str(job.get("skills", ""))).lower()

                    # Keep only iOS / Swift relevant roles
                    if not any(kw in searchable for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS):
                        continue

                    # Remove unwanted roles
                    if self._should_exclude(title.lower()):
                        continue

                    ios_jobs.append({
                        "company":    company,
                        "role":       title,
                        "location":   job.get("locationNames", [""])[0] if job.get("locationNames") else "",
                        "remote":     "Yes" if job.get("remote") else "Unknown",
                        "visa":       "Yes" if job.get("visaSponsorshipOffered") else "Unknown",
                        "experience": f"{job.get('minExperience', '')}-{job.get('maxExperience', '')} years".strip("-"),
                        "tags":       ", ".join(str(s) for s in job.get("skills", [])[:8]),
                        "url":        f"https://wellfound.com{url}" if url.startswith("/") else url,
                        "description": job.get("description", "")[:800],
                    })

            except Exception as e:
                print(f"[Wellfound API] {term} failed: {e}")
            continue   # silently fall through to scrape method

        return ios_jobs

    def _fetch_via_scrape(self) -> list[dict]:
        """Scrapes the Wellfound talent pages for iOS roles."""
        from bs4 import BeautifulSoup

        ios_jobs  = []
        pages_to_scrape = [
            "https://wellfound.com/role/r/ios-engineer",
            "https://wellfound.com/role/r/mobile-engineer",
        ]

        for url in pages_to_scrape:
            try:
                resp = self.session.get(url, timeout=15)
                if resp.status_code != 200:
                    continue

                soup = BeautifulSoup(resp.text, "html.parser")

                # Find job listing cards — Wellfound uses data-test attributes
                job_cards = soup.find_all("div", attrs={"data-test": "StartupResult"})
                if not job_cards:
                    job_cards = soup.find_all("div", class_=re.compile(r"job|role|startup", re.I))

                for card in job_cards[:20]:
                    text = card.get_text(" ", strip=True)
                    if not any(kw in text.lower() for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS):
                        continue

                    # Extract what we can from the card text
                    link = card.find("a", href=True)
                    href = link["href"] if link else ""
                    full_url = f"https://wellfound.com{href}" if href.startswith("/") else href

                    ios_jobs.append({
                        "company":    "",
                        "role":       text[:100],
                        "location":   "See post",
                        "remote":     "Unknown",
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       "",
                        "url":        full_url or url,
                        "description": text[:500],
                    })

                time.sleep(1)

            except Exception as e:
                print(f"[Wellfound] Scrape failed for {url}: {e}")

        return ios_jobs

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)


if __name__ == "__main__":
    jobs = WellfoundScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Wellfound")
    for j in jobs[:3]:
        print(f"  {j['company'] or '?'} — {j['role'][:60]}")