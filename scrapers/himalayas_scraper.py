# Himalayas — remote jobs, free public API
# Correct endpoint: https://himalayas.app/jobs/api?q=iOS

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class HimalayasScraper(BaseScraper):
    SOURCE_NAME = "Himalayas"

    SEARCH_TERMS = [
        ("iOS",     "https://himalayas.app/jobs/api?q=iOS&limit=50"),
        ("Swift",   "https://himalayas.app/jobs/api?q=Swift&limit=50"),
        ("SwiftUI", "https://himalayas.app/jobs/api?q=SwiftUI&limit=50"),
    ]

    def fetch_jobs(self) -> list[dict]:
        ios_jobs = []
        seen_ids = set()

        for term, url in self.SEARCH_TERMS:
            try:
                resp = self.session.get(url, timeout=15)
                resp.raise_for_status()
                data = resp.json()

                # Handle both list response and dict with "jobs" key
                if isinstance(data, list):
                    jobs = data
                elif isinstance(data, dict):
                    jobs = data.get("jobs", data.get("data", []))
                else:
                    continue

                for job in jobs:
                    job_id = str(job.get("id", job.get("slug", "")))
                    if job_id in seen_ids:
                        continue
                    seen_ids.add(job_id)

                    title = job.get("title", "")
                    desc  = job.get("description", "")

                    if self._should_exclude(title.lower()):
                        continue

                    # Salary
                    sal_min = job.get("salaryMin") or job.get("salary_min")
                    sal_max = job.get("salaryMax") or job.get("salary_max")
                    salary  = f"${int(sal_min):,}–${int(sal_max):,}" if sal_min and sal_max else ""

                    # Location from countries array
                    countries = job.get("countries", [])
                    location  = ", ".join(
                        c.get("name", c) if isinstance(c, dict) else str(c)
                        for c in countries[:2]
                    ) or "Remote"

                    # Apply link
                    apply_url = (job.get("applicationUrl")
                                or job.get("applyUrl")
                                or job.get("url")
                                or f"https://himalayas.app/jobs/{job.get('slug','')}")

                    ios_jobs.append({
                        "company":    job.get("companyName", job.get("company", {}).get("name", "") if isinstance(job.get("company"), dict) else ""),
                        "role":       title,
                        "location":   location,
                        "remote":     "Yes",
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       ", ".join(str(c) for c in job.get("categories", [])[:6]),
                        "url":        apply_url,
                        "description": self._clean_html(desc),
                        "salary":     salary,
                    })

            except Exception as e:
                print(f"[Himalayas] '{term}' failed: {e}")

        return ios_jobs

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)

    def _clean_html(self, html):
        clean = re.sub(r'<[^>]+>', ' ', html)
        return re.sub(r'\s+', ' ', clean).strip()[:800]


if __name__ == "__main__":
    jobs = HimalayasScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Himalayas")
    for j in jobs[:3]:
        print(f"  {j['company']} — {j['role']}")