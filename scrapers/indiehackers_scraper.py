# IndieHackers Jobs — small team / indie startup jobs
# Good source for bootstrapped startups not on mainstream boards

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bs4 import BeautifulSoup
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class IndieHackersScraper(BaseScraper):
    SOURCE_NAME = "IndieHackers"

    JOBS_URL = "https://www.indiehackers.com/jobs"

    def fetch_jobs(self) -> list[dict]:
        ios_jobs = []

        try:
            resp = self.session.get(self.JOBS_URL, timeout=15)
            resp.raise_for_status()

            soup  = BeautifulSoup(resp.text, "html.parser")

            # IH job cards have consistent class patterns
            cards = soup.find_all("div", class_=re.compile(r"job|hiring", re.I))
            if not cards:
                # Try finding any card-like elements with job content
                cards = soup.find_all(["article", "li"], recursive=True)

            seen_urls = set()

            for card in cards:
                text = card.get_text(" ", strip=True)

                if not any(kw in text.lower() for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS):
                    continue

                link   = card.find("a", href=re.compile(r"/jobs/|/job/|/hiring/"))
                if not link:
                    link = card.find("a", href=True)

                href     = link["href"] if link else ""
                full_url = (f"https://www.indiehackers.com{href}"
                            if href.startswith("/") else href)

                if full_url in seen_urls:
                    continue
                seen_urls.add(full_url)

                # Extract title and company from text
                lines = [l.strip() for l in text.split("\n") if l.strip()]
                title   = lines[0] if lines else text[:80]
                company = lines[1] if len(lines) > 1 else ""

                if self._should_exclude(title.lower()):
                    continue

                ios_jobs.append({
                    "company":    company[:100],
                    "role":       title[:200],
                    "location":   "Remote" if "remote" in text.lower() else "See post",
                    "remote":     "Yes" if "remote" in text.lower() else "Unknown",
                    "visa":       "Unknown",
                    "experience": "",
                    "tags":       self._extract_tags(text.lower()),
                    "url":        full_url or self.JOBS_URL,
                    "description": text[:600],
                })

        except Exception as e:
            print(f"[IndieHackers] Scrape failed: {e}")

        return ios_jobs

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)

    def _extract_tags(self, text):
        return ", ".join(kw for kw in IOS_TECH_KEYWORDS if kw in text)[:100]


if __name__ == "__main__":
    jobs = IndieHackersScraper().run()
    print(f"Found {len(jobs)} iOS jobs on IndieHackers")
    for j in jobs[:3]:
        print(f"  {j['company'] or '?'} — {j['role'][:60]}")