# Product Hunt Jobs — companies launching on PH often hire iOS devs
# Uses Product Hunt's public API (no auth needed for basic access)
# Also scrapes the /jobs page for structured listings

import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import requests
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class ProductHuntScraper(BaseScraper):
    SOURCE_NAME = "Product Hunt"

    # Product Hunt's public GraphQL API
    GRAPHQL_URL = "https://api.producthunt.com/v2/api/graphql"

    # Jobs page (fallback)
    JOBS_URL = "https://www.producthunt.com/jobs"

    def fetch_jobs(self) -> list[dict]:
        jobs = self._fetch_via_graphql()
        if not jobs:
            jobs = self._fetch_via_scrape()
        return jobs

    def _fetch_via_graphql(self) -> list[dict]:
        """
        Uses Product Hunt's public GraphQL API.
        The jobs query is available without authentication.
        """
        query = """
        {
        jobs(first: 50, filters: {roles: ["ios", "mobile"]}) {
            edges {
            node {
                id
                title
                description
                url
                isRemote
                websiteUrl
                company {
                name
                tagline
                }
                tags {
                name
                }
                createdAt
            }
            }
        }
        }
        """

        try:
            resp = requests.post(
                self.GRAPHQL_URL,
                json={"query": query},
                headers={
                    "Content-Type":  "application/json",
                    "Accept":        "application/json",
                    "User-Agent":    self.session.headers["User-Agent"],
                },
                timeout=15,
            )
            resp.raise_for_status()
            data = resp.json()

            if "errors" in data:
                return []

            edges    = data.get("data", {}).get("jobs", {}).get("edges", [])
            ios_jobs = []

            for edge in edges:
                job   = edge.get("node", {})
                title = job.get("title", "")

                searchable = (title + " " + job.get("description", "")).lower()
                if not self._is_ios_relevant(searchable):
                    continue
                if self._should_exclude(title.lower()):
                    continue

                company = job.get("company", {})
                company_name = company.get("name", "") if isinstance(company, dict) else ""

                tags = [t["name"] for t in job.get("tags", [])] if job.get("tags") else []

                ios_jobs.append({
                    "company":    company_name,
                    "role":       title,
                    "location":   "Remote" if job.get("isRemote") else "See post",
                    "remote":     "Yes" if job.get("isRemote") else "Unknown",
                    "visa":       "Unknown",
                    "experience": "",
                    "tags":       ", ".join(tags[:8]),
                    "url":        job.get("url", job.get("websiteUrl", "")),
                    "description": job.get("description", "")[:800],
                })

            return ios_jobs

        except Exception as e:
            print(f"[ProductHunt] GraphQL failed: {e}")
            return []

    def _fetch_via_scrape(self) -> list[dict]:
        """HTML fallback for the Product Hunt jobs page."""
        from bs4 import BeautifulSoup

        try:
            resp = self.session.get(self.JOBS_URL, timeout=15)
            if resp.status_code != 200:
                return []

            soup     = BeautifulSoup(resp.text, "html.parser")
            cards    = soup.find_all("div", attrs={"data-test": "job-listing-item"})
            if not cards:
                cards = soup.find_all("li", class_=re.compile(r"job|listing", re.I))

            ios_jobs  = []
            seen_urls = set()

            for card in cards:
                text = card.get_text(" ", strip=True)
                if not self._is_ios_relevant(text.lower()):
                    continue

                link    = card.find("a", href=True)
                href    = link["href"] if link else ""
                url     = f"https://www.producthunt.com{href}" if href.startswith("/") else href or self.JOBS_URL

                if url in seen_urls:
                    continue
                seen_urls.add(url)

                ios_jobs.append({
                    "company":    "",
                    "role":       text[:100],
                    "location":   "See post",
                    "remote":     "Yes" if "remote" in text.lower() else "Unknown",
                    "visa":       "Unknown",
                    "experience": "",
                    "tags":       "",
                    "url":        url,
                    "description": text[:500],
                })

            return ios_jobs

        except Exception as e:
            print(f"[ProductHunt] Scrape failed: {e}")
            return []

    def _is_ios_relevant(self, text):
        return any(kw in text for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS)

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)


if __name__ == "__main__":
    jobs = ProductHuntScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Product Hunt")
    for j in jobs[:3]:
        print(f"  {j['company'] or '?'} — {j['role'][:60]}")