# scrapers/cutshort_scraper.py — HTML-based, no auth

import sys, os, re, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bs4 import BeautifulSoup
from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class CutshortScraper(BaseScraper):
    SOURCE_NAME = "Cutshort"

    SEARCH_URLS = [
        "https://cutshort.io/jobs#!?keySkills=iOS",
        "https://cutshort.io/jobs#!?keySkills=Swift",
        "https://cutshort.io/jobs/ios-developer-jobs",
    ]

    # Cutshort also exposes job data via their public sitemap/search
    SITEMAP_API = "https://cutshort.io/api/v1/jobs/search"

    def fetch_jobs(self) -> list[dict]:
        jobs = self._fetch_via_public_api()
        if not jobs:
            jobs = self._fetch_via_html()
        return jobs

    def _fetch_via_public_api(self) -> list[dict]:
        """
        Cutshort has a public search API used by their own search page.
        No auth needed for read-only job browsing.
        """
        try:
            resp = self.session.get(
                "https://cutshort.io/api/v1/jobs/search",
                params={
                    "q":        "iOS Swift",
                    "page":     1,
                    "pageSize": 30,
                },
                headers={**self.session.headers, "Accept": "application/json"},
                timeout=12,
            )
            if resp.status_code != 200:
                return []

            data = resp.json()
            jobs_list = (data.get("data", {}).get("jobs", [])
                        if isinstance(data.get("data"), dict)
                        else data.get("jobs", []))

            ios_jobs = []
            for job in jobs_list:
                title = job.get("title", job.get("role", ""))
                if any(kw in title.lower() for kw in EXCLUDE_KEYWORDS):
                    continue

                company = (job.get("company", {}).get("name", "")
                        if isinstance(job.get("company"), dict)
                        else job.get("companyName", ""))

                skills = job.get("skills", job.get("keySkills", []))
                if isinstance(skills, list):
                    tags = ", ".join(str(s) for s in skills[:8])
                else:
                    tags = str(skills)[:100]

                locs = job.get("locations", job.get("location", []))
                location = (", ".join(locs[:2]) if isinstance(locs, list)
                            else str(locs))

                slug   = job.get("slug", job.get("id", ""))
                url    = f"https://cutshort.io/job/{slug}" if slug else ""

                ios_jobs.append({
                    "company":    company,
                    "role":       title,
                    "location":   location or "India",
                    "remote":     "Yes" if job.get("isRemote") else "Unknown",
                    "visa":       "Unknown",
                    "experience": f"{job.get('minExp', '')}-{job.get('maxExp', '')} yrs",
                    "tags":       tags,
                    "url":        url,
                    "description": job.get("description", "")[:800],
                })
            return ios_jobs

        except Exception:
            return []

    def _fetch_via_html(self) -> list[dict]:
        """HTML fallback — parses Cutshort's job listing page."""
        ios_jobs  = []
        seen_urls = set()

        for url in self.SEARCH_URLS:
            try:
                resp = self.session.get(url, timeout=15)
                if resp.status_code != 200:
                    continue

                soup  = BeautifulSoup(resp.text, "html.parser")

                # Cutshort job cards
                cards = (
                    soup.find_all("div", attrs={"data-test": re.compile(r"job|role", re.I)}) or
                    soup.find_all(class_=re.compile(r"jobCard|job-card|JobCard", re.I)) or
                    soup.find_all("article")
                )

                for card in cards[:20]:
                    text    = card.get_text(" ", strip=True)
                    link_el = card.find("a", href=re.compile(r"/job/|/jobs/"))
                    href    = link_el["href"] if link_el else ""
                    full_url = f"https://cutshort.io{href}" if href.startswith("/") else href

                    if not any(kw in text.lower() for kw in IOS_ROLE_KEYWORDS + IOS_TECH_KEYWORDS):
                        continue
                    if full_url in seen_urls:
                        continue
                    seen_urls.add(full_url)

                    ios_jobs.append({
                        "company":    "",
                        "role":       text[:120],
                        "location":   "India",
                        "remote":     "Unknown",
                        "visa":       "Unknown",
                        "experience": "",
                        "tags":       "",
                        "url":        full_url or url,
                        "description": text[:500],
                    })

                time.sleep(1)

            except Exception as e:
                print(f"[Cutshort] {url} failed: {e}")

        return ios_jobs


if __name__ == "__main__":
    jobs = CutshortScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Cutshort")
    for j in jobs[:3]:
        print(f"  {j['company'] or '?'} — {j['role'][:60]}")