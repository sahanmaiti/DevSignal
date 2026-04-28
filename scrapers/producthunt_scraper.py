# scrapers/producthunt_scraper.py — HTML scrape, no auth needed

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bs4 import BeautifulSoup
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class ProductHuntScraper(BaseScraper):
    SOURCE_NAME = "Product Hunt"

    SEARCH_URLS = [
        "https://www.producthunt.com/jobs?category=engineering",
        "https://www.producthunt.com/jobs?category=mobile",
        "https://www.producthunt.com/jobs?q=iOS",
    ]

    def fetch_jobs(self) -> list[dict]:
        ios_jobs  = []
        seen_urls = set()

        for url in self.SEARCH_URLS:
            try:
                # Product Hunt requires Accept header to avoid redirect
                headers = {
                    **self.session.headers,
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                }
                resp = self.session.get(url, headers=headers, timeout=20)
                if resp.status_code != 200:
                    continue

                soup = BeautifulSoup(resp.text, "html.parser")

                # PH job listings — look for job cards
                cards = (
                    soup.find_all("div", attrs={"data-test": re.compile(r"job", re.I)}) or
                    soup.find_all(class_=re.compile(r"styles_job|job-item|JobItem", re.I)) or
                    soup.find_all("li", class_=re.compile(r"job|position|role", re.I))
                )

                # Also try finding all links to job postings
                if not cards:
                    job_links = soup.find_all("a", href=re.compile(r"/jobs/\d+|/jobs/[a-z]"))
                    for link in job_links[:20]:
                        href     = link.get("href", "")
                        text     = link.get_text(" ", strip=True)
                        full_url = f"https://www.producthunt.com{href}" if href.startswith("/") else href

                        if full_url in seen_urls or len(text) < 10:
                            continue

                        searchable = text.lower()
                        if not any(kw in searchable for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS):
                            continue
                        if any(kw in searchable for kw in EXCLUDE_KEYWORDS):
                            continue

                        seen_urls.add(full_url)
                        ios_jobs.append({
                            "company":    "",
                            "role":       text[:150],
                            "location":   "Remote" if "remote" in searchable else "See post",
                            "remote":     "Yes" if "remote" in searchable else "Unknown",
                            "visa":       "Unknown",
                            "experience": "",
                            "tags":       "",
                            "url":        full_url,
                            "description": text[:500],
                        })
                    continue

                for card in cards[:20]:
                    text     = card.get_text(" ", strip=True)
                    link_el  = card.find("a", href=True)
                    href     = link_el["href"] if link_el else ""
                    full_url = f"https://www.producthunt.com{href}" if href.startswith("/") else href or url

                    if full_url in seen_urls:
                        continue

                    searchable = text.lower()
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
                        "tags":       "",
                        "url":        full_url,
                        "description": text[:500],
                    })

            except Exception as e:
                print(f"[ProductHunt] {url} failed: {e}")

        return ios_jobs


if __name__ == "__main__":
    jobs = ProductHuntScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Product Hunt")
    for j in jobs[:3]:
        print(f"  {j['company'] or '?'} — {j['role'][:60]}")