# scrapers/arc_scraper.py
# Fixed Arc.dev data extraction + improved company detection

import sys
import os
import re

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
        ios_jobs = []
        seen_urls = set()

        for url in self.BROWSE_URLS:
            try:
                resp = self.session.get(url, timeout=20)

                if resp.status_code != 200:
                    continue

                soup = BeautifulSoup(resp.text, "html.parser")

                cards = (
                    soup.find_all(
                        "div",
                        class_=re.compile(r"job-card|JobCard|job_card", re.I)
                    )
                    or soup.find_all("article")
                    or soup.find_all(
                        "li",
                        class_=re.compile(r"job|remote-job", re.I)
                    )
                )

                for card in cards[:25]:

                    # -------------------------------------------------
                    # Title
                    # -------------------------------------------------
                    title_el = (
                        card.find(["h2", "h3", "h4"])
                        or card.find(
                            class_=re.compile(
                                r"title|position|role|job-name",
                                re.I
                            )
                        )
                    )

                    title = title_el.get_text(strip=True) if title_el else ""

                    if not title:
                        continue

                    if len(title) > 150:
                        continue

                    title_lower = title.lower()

                    if any(kw in title_lower for kw in EXCLUDE_KEYWORDS):
                        continue

                    # Must have iOS signal in title or card text
                    if not any(
                        kw in title_lower
                        for kw in ["ios", "swift", "mobile", "iphone"]
                    ):
                        card_text = card.get_text(" ", strip=True).lower()

                        if not any(
                            kw in card_text
                            for kw in ["ios", "swift", "swiftui"]
                        ):
                            continue

                    # -------------------------------------------------
                    # Arc.dev company name — try multiple selectors
                    # -------------------------------------------------
                    company = ""

                    # Method 1: data attribute
                    el = card.find(attrs={"data-company": True})
                    if el:
                        company = el["data-company"].strip()

                    # Method 2: specific Arc class pattern
                    if not company:
                        el = card.find(
                            class_=re.compile(
                                r"company|employer|client|organization|hiring",
                                re.I
                            )
                        )

                        if el:
                            t = el.get_text(strip=True)

                            if t and len(t) < 80 and t != title:
                                company = t

                    # Method 3: "at CompanyName" in title
                    if not company and " at " in title:
                        company = title.rsplit(" at ", 1)[-1].strip()[:80]

                    # Method 4: second non-empty short text element in card
                    if not company:
                        ARC_UI_STRINGS = {
                            "arc exclusive",
                            "fast apply",
                            "arc exclusivefast apply",
                            "featured",
                            "new",
                            "hot",
                            "remote",
                            "full-time",
                            "part-time",
                            "contract",
                            "freelance",
                            "internship",
                        }

                        for el in card.find_all(
                            ["span", "p", "div"],
                            limit=10
                        ):
                            t = el.get_text(strip=True)
                            t_lower = t.lower().strip()

                            if (
                                t
                                and t != title
                                and 3 < len(t) < 60
                                and not t.startswith("$")
                                and not re.match(r"^\d", t)
                                and t_lower not in ARC_UI_STRINGS
                                and not any(
                                    ui in t_lower
                                    for ui in [
                                        "arc exclusive",
                                        "fast apply",
                                        "featured",
                                        "ww-pt",
                                        "apply now",
                                    ]
                                )
                            ):
                                company = t
                                break

                    # -------------------------------------------------
                    # URL
                    # -------------------------------------------------
                    link_el = card.find("a", href=True)
                    href = link_el["href"] if link_el else ""

                    if href.startswith("/"):
                        full_url = f"https://arc.dev{href}"
                    else:
                        full_url = href or url

                    if full_url in seen_urls:
                        continue

                    seen_urls.add(full_url)

                    # -------------------------------------------------
                    # Salary
                    # -------------------------------------------------
                    salary_el = card.find(
                        class_=re.compile(
                            r"salary|compensation|pay",
                            re.I
                        )
                    )

                    salary = (
                        salary_el.get_text(strip=True)
                        if salary_el else ""
                    )

                    # -------------------------------------------------
                    # Tags
                    # -------------------------------------------------
                    tag_els = card.find_all(
                        class_=re.compile(
                            r"tag|skill|badge|tech",
                            re.I
                        )
                    )

                    tags = ", ".join(
                        el.get_text(strip=True)
                        for el in tag_els[:8]
                    )

                    if not company:
                        company = "Arc Client"

                    # -------------------------------------------------
                    # Save job
                    # -------------------------------------------------
                    ios_jobs.append({
                        "company": company[:200],
                        "role": title,
                        "location": "Remote",
                        "remote": "Yes",
                        "visa": "Unknown",
                        "experience": "",
                        "tags": tags or "ios, swift",
                        "url": full_url,
                        "description": card.get_text(
                            " ",
                            strip=True
                        )[:600],
                        "salary": salary,
                    })

            except Exception as e:
                print(f"[Arc.dev] {url} failed: {e}")

        return ios_jobs


if __name__ == "__main__":
    jobs = ArcScraper().run()

    print(f"Found {len(jobs)} iOS jobs on Arc.dev")

    for j in jobs[:5]:
        print(f"  {j['company'] or '?'} — {j['role']}")