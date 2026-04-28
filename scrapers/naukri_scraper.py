# scrapers/naukri_scraper.py — fixed headers + proper HTML fallback

import sys, os, re, json, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bs4 import BeautifulSoup
from scrapers.base_scraper import BaseScraper
from config.keywords import EXCLUDE_KEYWORDS


class NaukriScraper(BaseScraper):
    SOURCE_NAME = "Naukri"

    SEARCH_QUERIES = [
        ("iOS developer fresher",  "ios-developer-jobs-in-india?experience=0"),
        ("iOS intern swift",       "ios-intern-jobs?experience=0"),
        ("junior iOS developer",   "junior-ios-developer-jobs?experience=0"),
    ]

    def fetch_jobs(self) -> list[dict]:
        all_jobs = []
        for query_text, url_slug in self.SEARCH_QUERIES:
            jobs = self._scrape_search_page(url_slug, query_text)
            all_jobs.extend(jobs)
            time.sleep(2)   # Naukri rate-limits aggressively

        # Deduplicate
        seen, unique = set(), []
        for j in all_jobs:
            if j["url"] not in seen:
                seen.add(j["url"])
                unique.append(j)
        return unique

    def _scrape_search_page(self, url_slug: str, query: str) -> list[dict]:
        """Scrapes Naukri search results page."""
        url = f"https://www.naukri.com/{url_slug}"

        # Naukri needs these headers to return HTML instead of a redirect
        headers = {
            **self.session.headers,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
        }

        try:
            resp = self.session.get(url, headers=headers, timeout=20)
            if resp.status_code != 200:
                return []

            soup  = BeautifulSoup(resp.text, "html.parser")
            cards = (
                soup.find_all("article", class_=re.compile(r"jobTuple|jobCard", re.I)) or
                soup.find_all("div", class_=re.compile(r"jobTuple|job-tuple|srp-jobtuple", re.I)) or
                soup.find_all(attrs={"data-job-id": True})
            )

            jobs = []
            for card in cards[:15]:
                # Title
                title_el = (
                    card.find(class_=re.compile(r"title|jobTitle|designation", re.I)) or
                    card.find(["h2", "h3"])
                )
                title = title_el.get_text(strip=True) if title_el else ""
                if not title or any(kw in title.lower() for kw in EXCLUDE_KEYWORDS):
                    continue

                # Check for iOS relevance in the card text
                card_text = card.get_text(" ", strip=True).lower()
                if not any(kw in card_text for kw in ["ios", "swift", "swiftui", "iphone"]):
                    continue

                # Company
                company_el = card.find(class_=re.compile(r"company|companyInfo|comp-name", re.I))
                company    = company_el.get_text(strip=True) if company_el else ""

                # Location
                loc_el   = card.find(class_=re.compile(r"location|loc|place", re.I))
                location = loc_el.get_text(strip=True) if loc_el else "India"

                # Experience
                exp_el = card.find(class_=re.compile(r"exp|experience", re.I))
                exp    = exp_el.get_text(strip=True) if exp_el else ""

                # Job URL
                link_el = card.find("a", href=re.compile(r"naukri.com/job"))
                job_url = link_el["href"] if link_el else url

                jobs.append({
                    "company":    company[:200],
                    "role":       title,
                    "location":   location[:200],
                    "remote":     "Yes" if "remote" in card_text else "Unknown",
                    "visa":       "Unknown",
                    "experience": exp[:100],
                    "tags":       ", ".join(
                        kw for kw in ["swift", "swiftui", "ios", "uikit", "xcode"]
                        if kw in card_text
                    ),
                    "url":        job_url,
                    "description": card_text[:500],
                })

            return jobs

        except Exception as e:
            print(f"[Naukri] {query} failed: {e}")
            return []


if __name__ == "__main__":
    jobs = NaukriScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Naukri")
    for j in jobs[:3]:
        print(f"  {j['company']} — {j['role']} | {j['location']}")