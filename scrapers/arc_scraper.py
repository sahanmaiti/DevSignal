# scrapers/arc_scraper.py — fixed data extraction

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bs4 import BeautifulSoup
from scrapers.base_scraper import BaseScraper
from config.keywords import EXCLUDE_KEYWORDS


class ArcScraper(BaseScraper):
    SOURCE_NAME = "Arc.dev"

    BROWSE_URLS = [
        "https://arc.dev/remote-jobs/ios",
        "https://arc.dev/remote-jobs/swift",
    ]

    def fetch_jobs(self) -> list[dict]:
        ios_jobs  = []
        seen_urls = set()

        for url in self.BROWSE_URLS:
            try:
                resp = self.session.get(url, timeout=20)
                if resp.status_code != 200:
                    continue

                soup = BeautifulSoup(resp.text, "html.parser")

                # Arc uses specific card classes
                cards = (
                    soup.find_all("div", class_=re.compile(r"job-card|JobCard|job_card", re.I)) or
                    soup.find_all("article") or
                    soup.find_all("li", class_=re.compile(r"job|remote-job", re.I))
                )

                for card in cards[:25]:
                    # Find the job title — look for heading elements inside the card
                    title_el = (
                        card.find(["h2", "h3", "h4"]) or
                        card.find(class_=re.compile(r"title|position|role|job-name", re.I))
                    )
                    title = title_el.get_text(strip=True) if title_el else ""

                    # Skip cards without a clear title
                    if not title or len(title) > 150:
                        continue
                    if any(kw in title.lower() for kw in EXCLUDE_KEYWORDS):
                        continue
                    # Must mention iOS or Swift
                    if not any(kw in title.lower() for kw in ["ios", "swift", "mobile", "iphone"]):
                        # Check tags/description for iOS relevance
                        card_text = card.get_text(" ", strip=True).lower()
                        if not any(kw in card_text for kw in ["ios", "swift", "swiftui"]):
                            continue

                    # Company name
                    company_el = card.find(class_=re.compile(r"company|employer|org", re.I))
                    company    = company_el.get_text(strip=True) if company_el else ""

                    # Job URL
                    link_el  = card.find("a", href=True)
                    href     = link_el["href"] if link_el else ""
                    full_url = f"https://arc.dev{href}" if href.startswith("/") else href or url

                    if full_url in seen_urls:
                        continue
                    seen_urls.add(full_url)

                    # Salary if present
                    salary_el = card.find(class_=re.compile(r"salary|compensation|pay", re.I))
                    salary    = salary_el.get_text(strip=True) if salary_el else ""

                    # Tags
                    tag_els = card.find_all(class_=re.compile(r"tag|skill|badge|tech", re.I))
                    tags    = ", ".join(el.get_text(strip=True) for el in tag_els[:8])

                    company = company.strip() if company else "Arc Client"
                    
                    ios_jobs.append({
                        "company":    company[:200],
                        "role":       title,
                        "location":   "Remote",
                        "remote":     "Yes",
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       tags or "ios, swift",
                        "url":        full_url,
                        "description": card.get_text(" ", strip=True)[:600],
                        "salary":     salary,
                    })

            except Exception as e:
                print(f"[Arc.dev] {url} failed: {e}")

        return ios_jobs


if __name__ == "__main__":
    jobs = ArcScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Arc.dev")
    for j in jobs[:5]:
        print(f"  {j['company'] or '?'} — {j['role']}")