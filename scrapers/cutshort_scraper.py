# Cutshort — popular in India for tech jobs, has a public API
# API: https://cutshort.io/api/jobs

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class CutshortScraper(BaseScraper):
    SOURCE_NAME = "Cutshort"

    # Cutshort has a public job listing endpoint
    SEARCH_URL = "https://cutshort.io/api/v2/jobs"
    BROWSE_URL = "https://cutshort.io/jobs/ios-developer-jobs"

    def fetch_jobs(self) -> list[dict]:
        jobs = self._fetch_via_api()
        if jobs:
            return jobs
        return self._fetch_via_scrape()

    def _fetch_via_api(self) -> list[dict]:
        """Attempts Cutshort's public API."""
        try:
            resp = self.session.get(
                self.SEARCH_URL,
                params={
                    "role":  "ios-developer",
                    "limit": 50,
                    "offset": 0,
                },
                timeout=12,
            )
            if resp.status_code != 200:
                return []

            data = resp.json()
            jobs_raw = data.get("jobs", data.get("data", []))

            ios_jobs = []
            for job in jobs_raw:
                title = job.get("title", job.get("role", ""))
                if self._should_exclude(title.lower()):
                    continue

                company_data = job.get("company", {})
                company_name = (company_data.get("name", "") if isinstance(company_data, dict)
                               else str(company_data))

                ios_jobs.append({
                    "company":    company_name,
                    "role":       title,
                    "location":   ", ".join(job.get("locations", [])) or "India",
                    "remote":     "Yes" if job.get("isRemote") else "Unknown",
                    "visa":       "Unknown",
                    "experience": f"{job.get('minExp', '')}-{job.get('maxExp', '')} yrs",
                    "tags":       ", ".join(job.get("skills", [])[:8]),
                    "url":        f"https://cutshort.io/job/{job.get('id', '')}",
                    "description": job.get("description", "")[:800],
                    "salary":     f"₹{job.get('minSalary', '')}-{job.get('maxSalary', '')} LPA" if job.get("minSalary") else "",
                })

            return ios_jobs

        except Exception:
            return []

    def _fetch_via_scrape(self) -> list[dict]:
        """Falls back to scraping Cutshort's browse page."""
        from bs4 import BeautifulSoup

        ios_jobs  = []
        urls_to_check = [
            "https://cutshort.io/jobs/ios-developer-jobs",
            "https://cutshort.io/jobs/swift-developer-jobs",
        ]

        for url in urls_to_check:
            try:
                resp = self.session.get(url, timeout=15)
                if resp.status_code != 200:
                    continue

                soup = BeautifulSoup(resp.text, "html.parser")

                # Cutshort renders job cards with consistent structure
                cards = soup.find_all("div", class_=re.compile(r"job-card|JobCard|job_card", re.I))
                if not cards:
                    # Try generic card detection
                    cards = soup.find_all("article") or soup.find_all("li", class_=re.compile(r"job", re.I))

                for card in cards[:20]:
                    text    = card.get_text(" ", strip=True)
                    link    = card.find("a", href=True)
                    href    = link["href"] if link else ""

                    if not any(kw in text.lower() for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS):
                        continue

                    full_url = f"https://cutshort.io{href}" if href.startswith("/") else href or url

                    ios_jobs.append({
                        "company":    "",
                        "role":       text[:100],
                        "location":   "India",
                        "remote":     "Unknown",
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       "",
                        "url":        full_url,
                        "description": text[:500],
                    })

            except Exception as e:
                print(f"[Cutshort] Scrape failed: {e}")

        return ios_jobs

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)


if __name__ == "__main__":
    jobs = CutshortScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Cutshort")
    for j in jobs[:3]:
        print(f"  {j['company'] or '?'} — {j['role'][:60]}")