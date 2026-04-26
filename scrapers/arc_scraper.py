# Arc.dev — senior remote developer platform, but has internship/junior listings
# Good quality signal: companies here are serious about hiring remote engineers

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import requests
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class ArcScraper(BaseScraper):
    SOURCE_NAME = "Arc.dev"

    SEARCH_URL = "https://arc.dev/api/v1/jobs"
    BROWSE_URLS = [
        "https://arc.dev/remote-jobs/ios",
        "https://arc.dev/remote-jobs/swift",
    ]

    def fetch_jobs(self) -> list[dict]:
        jobs = self._fetch_via_api()
        if not jobs:
            jobs = self._fetch_via_scrape()
        return jobs

    def _fetch_via_api(self) -> list[dict]:
        try:
            resp = requests.get(
                self.SEARCH_URL,
                params={"q": "iOS Swift", "per_page": 30},
                headers={"Accept": "application/json"},
                timeout=12,
            )
            if resp.status_code != 200:
                return []

            data = resp.json()
            jobs_raw = data.get("jobs", data.get("data", []))
            if not jobs_raw:
                return []

            ios_jobs = []
            for job in jobs_raw:
                title = job.get("title", "")
                if self._should_exclude(title.lower()):
                    continue

                ios_jobs.append({
                    "company":    job.get("company", {}).get("name", "") if isinstance(job.get("company"), dict) else "",
                    "role":       title,
                    "location":   "Remote",
                    "remote":     "Yes",
                    "visa":       "Unknown",
                    "experience": job.get("experience_level", ""),
                    "tags":       ", ".join(job.get("tech_stack", [])[:8]),
                    "url":        job.get("apply_url", job.get("url", "")),
                    "description": job.get("description", "")[:800],
                })
            return ios_jobs

        except Exception:
            return []

    def _fetch_via_scrape(self) -> list[dict]:
        from bs4 import BeautifulSoup
        ios_jobs  = []
        seen_urls = set()

        for url in self.BROWSE_URLS:
            try:
                resp = self.session.get(url, timeout=15)
                if resp.status_code != 200:
                    continue

                soup  = BeautifulSoup(resp.text, "html.parser")
                cards = soup.find_all(["article", "div"],
                                    class_=re.compile(r"job|listing|card", re.I))

                for card in cards[:15]:
                    text    = card.get_text(" ", strip=True)
                    link_el = card.find("a", href=True)
                    href    = link_el["href"] if link_el else ""
                    full_url = f"https://arc.dev{href}" if href.startswith("/") else href or url

                    if full_url in seen_urls:
                        continue
                    seen_urls.add(full_url)

                    ios_jobs.append({
                        "company":    "",
                        "role":       text[:100],
                        "location":   "Remote",
                        "remote":     "Yes",
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       "",
                        "url":        full_url,
                        "description": text[:500],
                    })

            except Exception as e:
                print(f"[Arc.dev] Scrape failed: {e}")

        return ios_jobs

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)


if __name__ == "__main__":
    jobs = ArcScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Arc.dev")
    for j in jobs[:3]:
        print(f"  {j['company'] or '?'} — {j['role'][:60]}")