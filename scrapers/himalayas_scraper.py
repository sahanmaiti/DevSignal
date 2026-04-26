# Himalayas.app — free JSON API, remote-focused, great iOS coverage
# API: https://himalayas.app/jobs/api

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class HimalayasScraper(BaseScraper):
    SOURCE_NAME = "Himalayas"
    API_URL     = "https://himalayas.app/jobs/api"

    # Himalayas supports ?q= search param
    SEARCH_TERMS = ["iOS", "Swift", "SwiftUI"]

    def fetch_jobs(self) -> list[dict]:
        ios_jobs = []
        seen_ids  = set()

        for term in self.SEARCH_TERMS:
            try:
                resp = self.session.get(
                    self.API_URL,
                    params={"q": term, "limit": 50},
                    timeout=15,
                )
                resp.raise_for_status()
                jobs = resp.json().get("jobs", [])

                for job in jobs:
                    job_id = job.get("id", "")
                    if job_id in seen_ids:
                        continue
                    seen_ids.add(job_id)

                    title = job.get("title", "")
                    desc  = job.get("description", "")
                    searchable = (title + " " + desc[:300]).lower()

                    if not self._is_ios_relevant(searchable):
                        continue
                    if self._should_exclude(title.lower()):
                        continue

                    # Himalayas provides structured salary data
                    salary = ""
                    sal_min = job.get("salaryMin")
                    sal_max = job.get("salaryMax")
                    if sal_min and sal_max:
                        salary = f"${int(sal_min):,}–${int(sal_max):,}"

                    # Location: some have countries list
                    countries = job.get("countries", [])
                    location  = ", ".join(c.get("name", "") for c in countries[:3]) or "Remote"

                    ios_jobs.append({
                        "company":     job.get("companyName", ""),
                        "role":        title,
                        "location":    location,
                        "remote":      "Yes",   # Himalayas is remote-only
                        "visa":        "Unknown",
                        "experience":  "",
                        "tags":        ", ".join(job.get("categories", [])[:6]),
                        "url":         job.get("applicationUrl", job.get("url", "")),
                        "description": self._clean_html(desc),
                        "salary":      salary,
                    })

            except Exception as e:
                print(f"[Himalayas] Search '{term}' failed: {e}")

        return ios_jobs

    def _is_ios_relevant(self, text):
        return any(kw in text for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS)

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