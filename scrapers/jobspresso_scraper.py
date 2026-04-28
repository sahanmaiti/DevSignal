# Jobspresso — curated remote jobs, free RSS, no auth
# https://jobspresso.co/remote-work/

import sys, os, re, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import feedparser
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class JobspressoScraper(BaseScraper):
    SOURCE_NAME = "Jobspresso"

    RSS_FEEDS = [
        "https://jobspresso.co/remote-work/developer/?feed=rss2",
        "https://jobspresso.co/remote-work/mobile/?feed=rss2",
        "https://jobspresso.co/remote-work/developer/feed/",
        "https://jobspresso.co/remote-work/engineering/feed/",
        "https://jobspresso.co/?feed=rss2&job_category=developer",
    ]

    def fetch_jobs(self) -> list[dict]:
        ios_jobs  = []
        seen_urls = set()

        for feed_url in self.RSS_FEEDS:
            try:
                feed = feedparser.parse(feed_url)

                for entry in feed.entries:
                    title   = entry.get("title", "")
                    link    = entry.get("link", "")
                    summary = entry.get("summary", "")

                    searchable = (title + " " + summary).lower()

                    if not any(kw in searchable for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS):
                        continue
                    if any(kw in title.lower() for kw in EXCLUDE_KEYWORDS):
                        continue
                    if link in seen_urls:
                        continue
                    seen_urls.add(link)

                    # Jobspresso titles: "Job Title at Company"
                    role, company = self._parse_title(title)

                    ios_jobs.append({
                        "company":    company,
                        "role":       role,
                        "location":   "Remote",
                        "remote":     "Yes",
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       ", ".join(
                            kw for kw in IOS_TECH_KEYWORDS if kw in searchable
                        )[:100],
                        "url":        link,
                        "description": re.sub(r'<[^>]+>', ' ', summary)[:800],
                    })

                time.sleep(0.5)

            except Exception as e:
                print(f"[Jobspresso] Feed failed: {e}")

        return ios_jobs

    def _parse_title(self, title: str) -> tuple:
        """'iOS Developer at Acme' → ('iOS Developer', 'Acme')"""
        if " at " in title:
            parts = title.rsplit(" at ", 1)
            return parts[0].strip(), parts[1].strip()
        return title.strip(), ""


if __name__ == "__main__":
    jobs = JobspressoScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Jobspresso")
    for j in jobs[:3]:
        print(f"  {j['company'] or '?'} — {j['role']}")