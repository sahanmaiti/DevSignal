# Naukri.com — India's largest job board
# Important for finding Indian startup internships and entry-level iOS roles
# Uses their public search API (same endpoint the website uses)

import sys, os, re, json
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from config.keywords import EXCLUDE_KEYWORDS


class NaukriScraper(BaseScraper):
    SOURCE_NAME = "Naukri"

    # Naukri's internal search API — same one their website calls
    API_URL = "https://www.naukri.com/jobapi/v3/search"

    SEARCH_QUERIES = [
        "iOS developer fresher",
        "iOS intern swift",
        "junior iOS developer",
    ]

    def fetch_jobs(self) -> list[dict]:
        ios_jobs  = []
        seen_ids  = set()

        # Naukri requires specific headers to appear as the website
        headers = {
            **self.session.headers,
            "appid":       "109",
            "systemid":    "109",
            "Accept":      "application/json",
            "Content-Type": "application/json",
        }

        for query in self.SEARCH_QUERIES:
            try:
                resp = self.session.get(
                    self.API_URL,
                    headers=headers,
                    params={
                        "noOfResults":  20,
                        "urlType":      "search_by_keyword",
                        "searchType":   "adv",
                        "keyword":      query,
                        "location":     "",   # all India
                        "jobAge":       7,    # last 7 days
                        "experience":   0,
                        "salary":       0,
                        "industryId":   "",
                        "functionalAreaId": "",
                    },
                    timeout=15,
                )

                if resp.status_code != 200:
                    # Fallback to HTML scraping
                    jobs = self._scrape_html(query)
                    ios_jobs.extend(jobs)
                    continue

                data = resp.json()
                jobs_list = data.get("jobDetails", [])

                for job in jobs_list:
                    job_id = str(job.get("jobId", ""))
                    if job_id in seen_ids:
                        continue
                    seen_ids.add(job_id)

                    title    = job.get("title", "")
                    company  = job.get("companyName", "")
                    location = job.get("placeholders", [{}])[0].get("label", "India") \
                            if job.get("placeholders") else "India"

                    if self._should_exclude(title.lower()):
                        continue

                    # Naukri experience format: "0-1 Yrs", "Fresher"
                    exp_min = job.get("minimumExperience", 0)
                    exp_max = job.get("maximumExperience", 0)
                    exp_str = f"{exp_min}-{exp_max} years" if exp_max else "Fresher"

                    # Salary from Naukri
                    salary_detail = job.get("placeholders", [])
                    salary = ""
                    for p in salary_detail:
                        if "lakh" in p.get("label", "").lower() or "lpa" in p.get("label", "").lower():
                            salary = p.get("label", "")
                            break

                    ios_jobs.append({
                        "company":    company,
                        "role":       title,
                        "location":   location,
                        "remote":     "Unknown",
                        "visa":       "Unknown",
                        "experience": exp_str,
                        "tags":       ", ".join(job.get("tagsAndSkills", "").split(",")[:6]),
                        "url":        f"https://www.naukri.com{job.get('jdURL', '')}",
                        "description": job.get("jobDescription", "")[:800],
                        "salary":     salary,
                    })

            except Exception as e:
                print(f"[Naukri] Query '{query}' failed: {e}")

        return ios_jobs

    def _scrape_html(self, query: str) -> list[dict]:
        """HTML fallback when the API returns unexpected responses."""
        from bs4 import BeautifulSoup

        try:
            url  = f"https://www.naukri.com/{query.replace(' ', '-')}-jobs"
            resp = self.session.get(url, timeout=15)
            if resp.status_code != 200:
                return []

            soup  = BeautifulSoup(resp.text, "html.parser")
            cards = soup.find_all("article", class_=re.compile(r"jobTuple|job-tuple|jobCard", re.I))

            jobs = []
            for card in cards[:15]:
                title_el   = card.find(["h2", "a"], class_=re.compile(r"title|jobTitle", re.I))
                company_el = card.find(class_=re.compile(r"companyInfo|company", re.I))
                link_el    = card.find("a", href=True)

                title   = title_el.get_text(strip=True) if title_el else ""
                company = company_el.get_text(strip=True) if company_el else ""
                url     = link_el["href"] if link_el else ""

                if not title or self._should_exclude(title.lower()):
                    continue

                jobs.append({
                    "company":    company,
                    "role":       title,
                    "location":   "India",
                    "remote":     "Unknown",
                    "visa":       "Unknown",
                    "experience": "",
                    "tags":       "",
                    "url":        url,
                    "description": card.get_text(" ", strip=True)[:500],
                })

            return jobs

        except Exception:
            return []

    def _should_exclude(self, text):
        return any(kw in text for kw in EXCLUDE_KEYWORDS)


if __name__ == "__main__":
    jobs = NaukriScraper().run()
    print(f"Found {len(jobs)} iOS jobs on Naukri")
    for j in jobs[:3]:
        print(f"  {j['company']} — {j['role']} | {j['location']}")