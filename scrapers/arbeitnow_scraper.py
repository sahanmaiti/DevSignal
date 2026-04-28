# scrapers/arbeitnow_scraper.py
# Arbeitnow — free public JSON API, no auth, EU-focused + remote
# API: https://arbeitnow.com/api/job-board-api

import sys, os, re, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class ArbeitnowScraper(BaseScraper):
    SOURCE_NAME = "Arbeitnow"
    API_URL = "https://arbeitnow.com/api/job-board-api"

    def fetch_jobs(self) -> list[dict]:
        ios_jobs = []
        page = 1
        max_pages = 5   # API paginates — cap at 5 to avoid quota waste

        while page <= max_pages:
            try:
                resp = self.session.get(
                    self.API_URL,
                    params={"page": page},
                    timeout=15,
                )
                resp.raise_for_status()

                data = resp.json()
                listings = data.get("data", [])

                if not listings:
                    break

                for job in listings:
                    title = job.get("title", "")
                    desc = job.get("description", "")

                    # Check title AND tags for iOS signal
                    title_lower = job.get("title", "").lower()
                    tags_lower = [t.lower() for t in job.get("tags", [])]

                    has_ios_signal = (
                        any(
                            kw in title_lower
                            for kw in [
                                "ios",
                                "swift",
                                "swiftui",
                                "iphone",
                                "mobile",
                            ]
                        )
                        or
                        any(
                            kw in tags_lower
                            for kw in [
                                "ios",
                                "swift",
                                "swiftui",
                                "mobile",
                                "iphone",
                            ]
                        )
                    )

                    if not has_ios_signal:
                        continue

                    searchable = (
                        title + " " +
                        " ".join(job.get("tags", [])) + " " +
                        desc[:300]
                    ).lower()

                    if not self._is_ios_relevant(searchable):
                        continue

                    if self._should_exclude(title_lower):
                        continue

                    ios_jobs.append({
                        "company": job.get("company_name", ""),
                        "role": title,
                        "location": job.get("location", ""),
                        "remote": "Yes" if job.get("remote") else "Unknown",
                        "visa": "Unknown",
                        "experience": "",
                        "tags": ", ".join(job.get("tags", [])[:8]),
                        "url": job.get("url", ""),
                        "description": self._clean_html(desc),
                    })

                # Check if there's a next page
                links = data.get("links", {})
                if not links.get("next"):
                    break

                page += 1
                time.sleep(0.5)

            except Exception as e:
                print(f"[Arbeitnow] Page {page} failed: {e}")
                break

        return ios_jobs

    def _is_ios_relevant(self, text):
        # Require "ios" to be a whole word, not inside another word
        for kw in IOS_ROLE_KEYWORDS:
            if kw in text:
                return True

        # For tech keywords use word boundary check
        for kw in IOS_TECH_KEYWORDS:
            if re.search(r"\b" + re.escape(kw) + r"\b", text):
                return True

        return False

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)

    def _clean_html(self, html):
        clean = re.sub(r"<[^>]+>", " ", html)
        return re.sub(r"\s+", " ", clean).strip()[:800]


if __name__ == "__main__":
    jobs = ArbeitnowScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Arbeitnow")

    for j in jobs[:3]:
        print(f"  {j['company']} — {j['role']} | {j['location']}")