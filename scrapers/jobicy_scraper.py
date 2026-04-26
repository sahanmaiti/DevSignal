# Jobicy — free JSON API, remote jobs, no auth
# API: https://jobicy.com/api/v0/remote-jobs

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class JobicyScraper(BaseScraper):
    SOURCE_NAME = "Jobicy"
    API_URL     = "https://jobicy.com/api/v0/remote-jobs"

    def fetch_jobs(self) -> list[dict]:
        ios_jobs = []

        # Jobicy supports tag filtering — "ios" and "swift" are valid tags
        for tag in ["ios", "swift"]:
            try:
                resp = self.session.get(
                    self.API_URL,
                    params={"count": 50, "tag": tag},
                    headers={
                    "User-Agent": "Mozilla/5.0",
                    "Accept": "application/json",
                    "Referer": "https://jobicy.com/",
                    },
                    timeout=15,
                )
                resp.raise_for_status()
                jobs = resp.json().get("jobs", [])

                for job in jobs:
                    title     = job.get("jobTitle", "")
                    desc      = job.get("jobDescription", "")
                    searchable = (title + " " + desc[:300]).lower()

                    if self._should_exclude(title.lower()):
                        continue

                    # Jobicy jobs are already iOS/Swift tagged so we trust that
                    ios_jobs.append({
                        "company":    job.get("companyName", ""),
                        "role":       title,
                        "location":   job.get("jobGeo", "Remote"),
                        "remote":     "Yes",
                        "visa":       "Unknown",
                        "experience": job.get("jobLevel", ""),
                        "tags":       ", ".join(job.get("jobIndustry", [])[:6]),
                        "url":        job.get("url", ""),
                        "description": self._clean_html(desc),
                        "salary":     job.get("annualSalaryMin", ""),
                    })

            except Exception as e:
                print(f"[Jobicy] Tag '{tag}' failed: {e}")

        # Deduplicate by URL
        seen = set()
        unique = []
        for job in ios_jobs:
            url = job["url"]
            if url not in seen:
                seen.add(url)
                unique.append(job)

        return unique

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)

    def _clean_html(self, html):
        clean = re.sub(r'<[^>]+>', ' ', html)
        return re.sub(r'\s+', ' ', clean).strip()[:800]


if __name__ == "__main__":
    jobs = JobicyScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Jobicy")
    for j in jobs[:3]:
        print(f"  {j['company']} — {j['role']}")