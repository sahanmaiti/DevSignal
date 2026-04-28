# scrapers/adzuna_scraper.py
#
# Adzuna — free global jobs API, aggregates from thousands of sources
# including many that block direct scraping.
#
# FREE: 1,000 requests/month
# REGISTER: developer.adzuna.com
# API DOCS: https://developer.adzuna.com/docs/search

import sys
import os
import re
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import EXCLUDE_KEYWORDS, VISA_POSITIVE_PHRASES
from config.settings import ADZUNA_APP_ID, ADZUNA_APP_KEY


class AdzunaScraper(BaseScraper):
    SOURCE_NAME = "Adzuna"
    API_BASE = "https://api.adzuna.com/v1/api/jobs"

    SEARCHES = [
        ("us", "iOS developer intern remote"),
        ("us", "Swift SwiftUI intern"),
        ("gb", "iOS developer internship"),
        ("in", "iOS developer fresher intern"),
        ("in", "iOS Swift junior developer"),
        ("au", "iOS developer internship"),
        ("ca", "iOS Swift intern"),
        ("sg", "iOS developer junior"),
    ]

    def fetch_jobs(self) -> list[dict]:
        if not ADZUNA_APP_ID or not ADZUNA_APP_KEY:
            print("[Adzuna] Keys not set — skipping")
            print("[Adzuna] Register free at developer.adzuna.com")
            print("[Adzuna] Add ADZUNA_APP_ID and ADZUNA_APP_KEY to .env")
            return []

        ios_jobs = []
        seen_ids = set()

        for country, query in self.SEARCHES:
            try:
                url = f"{self.API_BASE}/{country}/search/1"

                resp = self.session.get(
                    url,
                    params={
                        "app_id": ADZUNA_APP_ID,
                        "app_key": ADZUNA_APP_KEY,
                        "what": query,
                        "results_per_page": 20,
                        "max_days_old": 14,
                        "sort_by": "date",
                        "content-type": "application/json",
                    },
                    timeout=15,
                )

                resp.raise_for_status()

                raw_count = len(resp.json().get("results", []))
                if raw_count == 0:
                    print(f"  [Adzuna] {country}/{query[:30]} → 0 results from API")
                else:
                    print(f"  [Adzuna] {country}/{query[:30]} → {raw_count} raw results")

                results = resp.json().get("results", [])

                country_labels = {
                    "us": "USA",
                    "gb": "UK",
                    "au": "Australia",
                    "in": "India",
                    "ca": "Canada",
                    "sg": "Singapore",
                }

                for job in results:
                    job_id = str(job.get("id", ""))

                    if job_id in seen_ids:
                        continue

                    seen_ids.add(job_id)

                    title = job.get("title", "")
                    desc = job.get("description", "")
                    title_lower = title.lower()
                    desc_lower = desc.lower()

                    ios_keywords = [
                        "ios",
                        "swift",
                        "swiftui",
                        "iphone",
                        "mobile app",
                        "mobile developer",
                        "mobile engineer",
                        "apple developer",
                        "xcode",
                    ]

                    title_has_signal = any(
                        kw in title_lower for kw in ios_keywords
                    )

                    desc_has_signal = any(
                        kw in desc_lower[:200] for kw in ios_keywords
                    )

                    if not title_has_signal and not desc_has_signal:
                        continue

                    if any(kw in title_lower for kw in EXCLUDE_KEYWORDS):
                        continue

                    company = (
                        job.get("company", {}).get("display_name", "")
                        if isinstance(job.get("company"), dict)
                        else ""
                    )

                    location = (
                        job.get("location", {}).get(
                            "display_name",
                            country_labels.get(country, country)
                        )
                        if isinstance(job.get("location"), dict)
                        else country_labels.get(country, country)
                    )

                    sal_min = job.get("salary_min")
                    sal_max = job.get("salary_max")

                    if sal_min and sal_max:
                        prefix = "₹" if country == "in" else "$"
                        salary = (
                            f"{prefix}{int(sal_min):,}"
                            f"–"
                            f"{prefix}{int(sal_max):,}"
                        )
                    else:
                        salary = ""

                    remote = "Yes" if any(
                        r in desc_lower or r in location.lower()
                        for r in ["remote", "work from home", "wfh"]
                    ) else "Unknown"

                    visa = "Unknown"
                    for phrase in VISA_POSITIVE_PHRASES:
                        if phrase in desc_lower:
                            visa = "Yes"
                            break

                    exp_match = re.search(
                        r'(\d+\+?\s*(?:–|-|to)?\s*\d*\+?\s*years?)',
                        desc,
                        re.I,
                    )

                    ios_jobs.append({
                        "company": company,
                        "role": title,
                        "location": location,
                        "remote": remote,
                        "visa": visa,
                        "experience": (
                            exp_match.group(1).strip()
                            if exp_match else ""
                        ),
                        "tags": self._extract_tags(
                            desc_lower + " " + title_lower
                        ),
                        "url": job.get("redirect_url", ""),
                        "description": self._clean_html(desc),
                        "salary": salary,
                    })

                time.sleep(0.5)

            except Exception as e:
                print(f"[Adzuna] {country}/{query[:30]} failed: {e}")

        return ios_jobs

    def _extract_tags(self, text):
        tech = [
            "swift",
            "swiftui",
            "uikit",
            "xcode",
            "objective-c",
            "combine",
            "core data",
            "arkit",
            "mapkit",
            "ios sdk",
        ]
        return ", ".join(kw for kw in tech if kw in text)[:100]

    def _clean_html(self, html):
        clean = re.sub(r"<[^>]+>", " ", html)
        return re.sub(r"\s+", " ", clean).strip()[:800]


if __name__ == "__main__":
    jobs = AdzunaScraper().run()

    print(f"\nFound {len(jobs)} iOS jobs via Adzuna")

    for j in jobs[:6]:
        print(f"  [{j['location']}] {j['company'] or '?'} — {j['role']}")
        print(
            f"    Remote: {j['remote']} | "
            f"Salary: {j.get('salary') or 'not listed'}"
        )