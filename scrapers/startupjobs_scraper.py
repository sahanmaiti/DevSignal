# Startup.jobs — startup-focused job board
# RSS: https://startup.jobs/feed?category=mobile&remote=true

import sys, os, re, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import feedparser
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class StartupJobsScraper(BaseScraper):
    SOURCE_NAME = "Startup.jobs"

    RSS_FEEDS = [
    "https://startup.jobs/mobile.rss",     # correct endpoint
    "https://startup.jobs/ios.rss",
    "https://startup.jobs/swift.rss",
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
                    author  = entry.get("author", "")

                    searchable = (title + " " + summary).lower()

                    if not self._is_ios_relevant(searchable):
                        continue
                    if self._should_exclude(title.lower()):
                        continue
                    if link in seen_urls:
                        continue
                    seen_urls.add(link)

                    ios_jobs.append({
                        "company":    author or self._extract_company(title),
                        "role":       title,
                        "location":   self._extract_location(summary),
                        "remote":     self._detect_remote(title + " " + summary),
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       self._extract_tags(searchable),
                        "url":        link,
                        "description": self._clean_html(summary),
                    })

                time.sleep(0.5)

            except Exception as e:
                print(f"[Startup.jobs] Feed failed: {e}")

        return ios_jobs

    def _extract_company(self, title):
        if " at " in title.lower():
            parts = title.split(" at ", 1)
            return parts[-1].strip() if len(parts) > 1 else ""
        return ""

    def _extract_location(self, text):
        if "remote" in text.lower():
            return "Remote"
        match = re.search(r'\b([A-Z][a-z]+(?:,\s*[A-Z]{2})?)\b', text)
        return match.group(1) if match else ""

    def _detect_remote(self, text):
        if any(r in text.lower() for r in ["remote", "anywhere", "distributed"]):
            return "Yes"
        if "hybrid" in text.lower():
            return "Hybrid"
        return "Unknown"

    def _is_ios_relevant(self, text):
        return any(kw in text for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS)

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)

    def _extract_tags(self, text):
        return ", ".join(kw for kw in IOS_TECH_KEYWORDS if kw in text)[:100]

    def _clean_html(self, html):
        clean = re.sub(r'<[^>]+>', ' ', html)
        return re.sub(r'\s+', ' ', clean).strip()[:800]


if __name__ == "__main__":
    jobs = StartupJobsScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Startup.jobs")
    for j in jobs[:3]:
        print(f"  {j['company']} — {j['role']}")