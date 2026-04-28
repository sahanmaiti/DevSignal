# scrapers/indiehackers_scraper.py — fixed for current page structure

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bs4 import BeautifulSoup
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class IndieHackersScraper(BaseScraper):
    SOURCE_NAME = "IndieHackers"

    # IH Jobs board
    JOBS_URL   = "https://www.indiehackers.com/jobs"
    # IH also has a hiring board in posts
    HIRING_URL = "https://www.indiehackers.com/jobs/mobile"

    def fetch_jobs(self) -> list[dict]:
        ios_jobs  = []
        seen_urls = set()

        for url in [self.JOBS_URL, self.HIRING_URL]:
            try:
                resp = self.session.get(url, timeout=20)
                if resp.status_code != 200:
                    continue

                soup = BeautifulSoup(resp.text, "html.parser")

                # IH renders jobs inside component divs with specific classes
                # Try multiple selector patterns
                job_containers = (
                    soup.find_all("div", class_=re.compile(r"job-post|job_post|JobPost", re.I)) or
                    soup.find_all("a", href=re.compile(r"/jobs/")) or
                    soup.find_all(class_=re.compile(r"hiring|job|position", re.I))
                )

                for el in job_containers[:30]:
                    # Get the link
                    if el.name == "a":
                        link_el = el
                        href    = el.get("href", "")
                    else:
                        link_el = el.find("a", href=True)
                        href    = link_el["href"] if link_el else ""

                    full_url = (f"https://www.indiehackers.com{href}"
                                if href.startswith("/") else href or url)

                    if full_url in seen_urls or full_url == url:
                        continue

                    text = el.get_text(" ", strip=True)
                    if len(text) < 15:
                        continue

                    searchable = text.lower()

                    # Filter for iOS relevance
                    if not any(kw in searchable for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS):
                        continue
                    if any(kw in searchable for kw in EXCLUDE_KEYWORDS):
                        continue

                    seen_urls.add(full_url)

                    lines   = [l.strip() for l in text.split("\n") if l.strip() and len(l.strip()) > 3]
                    title   = lines[0][:150] if lines else text[:100]
                    company = lines[1][:100] if len(lines) > 1 else ""

                    ios_jobs.append({
                        "company":    company,
                        "role":       title,
                        "location":   "Remote" if "remote" in searchable else "See post",
                        "remote":     "Yes" if "remote" in searchable else "Unknown",
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       ", ".join(
                            kw for kw in IOS_TECH_KEYWORDS if kw in searchable
                        )[:100],
                        "url":        full_url,
                        "description": text[:600],
                    })

            except Exception as e:
                print(f"[IndieHackers] {url} failed: {e}")

        return ios_jobs


if __name__ == "__main__":
    jobs = IndieHackersScraper().run()
    print(f"Found {len(jobs)} iOS jobs on IndieHackers")
    for j in jobs[:3]:
        print(f"  {j['company'] or '?'} — {j['role'][:60]}")