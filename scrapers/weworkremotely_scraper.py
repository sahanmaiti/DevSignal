# WeWorkRemotely — one of the biggest remote job boards
# Uses RSS feeds — no auth, always reliable
# RSS: https://weworkremotely.com/categories/remote-programming-jobs.rss

import sys, os, re, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import feedparser
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class WeWorkRemotelyScraper(BaseScraper):
    SOURCE_NAME = "WeWorkRemotely"

    RSS_FEEDS = [
        "https://weworkremotely.com/categories/remote-programming-jobs.rss",
        "https://weworkremotely.com/categories/remote-full-stack-programming-jobs.rss",
    ]

    def fetch_jobs(self) -> list[dict]:
        ios_jobs = []
        seen_urls = set()

        for feed_url in self.RSS_FEEDS:
            try:
                # feedparser can take a URL directly
                feed = feedparser.parse(feed_url)

                for entry in feed.entries:
                    title   = entry.get("title", "")
                    link    = entry.get("link", "")
                    summary = entry.get("summary", "")

                    searchable = (title + " " + summary).lower()

                    if not self._is_ios_relevant(searchable):
                        continue
                    if self._should_exclude(title.lower()):
                        continue
                    if link in seen_urls:
                        continue
                    seen_urls.add(link)

                    # WWR titles format: "Company: Job Title"
                    company, role = self._parse_title(title)

                    ios_jobs.append({
                        "company":    company,
                        "role":       role,
                        "location":   "Remote",
                        "remote":     "Yes",
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       self._extract_tags(searchable),
                        "url":        link,
                        "description": self._clean_html(summary),
                    })

                time.sleep(0.5)

            except Exception as e:
                print(f"[WeWorkRemotely] Feed failed: {e}")

        return ios_jobs

    def _parse_title(self, title: str) -> tuple:
        """'Acme Corp: iOS Developer' → ('Acme Corp', 'iOS Developer')"""
        if ": " in title:
            parts = title.split(": ", 1)
            return parts[0].strip(), parts[1].strip()
        return "", title.strip()

    def _is_ios_relevant(self, text):
        return any(kw in text for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS)

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)

    def _extract_tags(self, text):
        found = [kw for kw in IOS_TECH_KEYWORDS if kw in text]
        return ", ".join(found[:6])

    def _clean_html(self, html):
        clean = re.sub(r'<[^>]+>', ' ', html)
        return re.sub(r'\s+', ' ', clean).strip()[:800]


if __name__ == "__main__":
    jobs = WeWorkRemotelyScraper().run()
    print(f"Found {len(jobs)} iOS jobs on WeWorkRemotely")
    for j in jobs[:3]:
        print(f"  {j['company']} — {j['role']}")