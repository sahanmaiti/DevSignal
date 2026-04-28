import sys
import os
import time
import random

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

from scrapers.base_scraper import BaseScraper
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS


class WellfoundScraper(BaseScraper):
    SOURCE_NAME = "Wellfound"

    SEARCH_PAGES = [
        "https://wellfound.com/role/r/ios-engineer",
        "https://wellfound.com/role/r/mobile-engineer?q=swift",
        "https://wellfound.com/jobs",
    ]

    def fetch_jobs(self) -> list[dict]:
        jobs = []
        seen_urls = set()

        with sync_playwright() as p:
            browser = p.chromium.launch(
                headless=True,
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--no-sandbox",
                ],
            )

            context = browser.new_context(
                user_agent=(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/124.0.0.0 Safari/537.36"
                ),
                viewport={"width": 1440, "height": 900},
                locale="en-US",
            )

            page = context.new_page()

            # Reduce automation fingerprint
            page.add_init_script("""
                Object.defineProperty(navigator, 'webdriver', {
                    get: () => undefined
                });
            """)

            for url in self.SEARCH_PAGES:
                try:
                    print(f"[Wellfound] Opening {url}")

                    page.goto(url, wait_until="domcontentloaded", timeout=45000)
                    page.wait_for_timeout(random.randint(2500, 4500))

                    self._human_scroll(page)

                    html = page.content()

                    with open("wellfound_debug.html", "w", encoding="utf-8") as f:
                        f.write(html)

                    print("Saved debug HTML")

                    # Try to wait for likely job anchors
                    try:
                        page.wait_for_selector("a[href*='/jobs/']", timeout=8000)
                    except PlaywrightTimeoutError:
                        pass

                    html = page.content()
                    soup = BeautifulSoup(html, "html.parser")

                    page_jobs = self._extract_jobs_from_soup(soup, seen_urls)

                    print(f"[Wellfound] Found {len(page_jobs)} jobs on page")
                    jobs.extend(page_jobs)

                    time.sleep(random.uniform(1.0, 2.5))

                except Exception as e:
                    print(f"[Wellfound] Failed {url}: {e}")

            browser.close()

        return jobs

    def _human_scroll(self, page):
        for _ in range(5):
            page.mouse.wheel(0, random.randint(700, 1400))
            page.wait_for_timeout(random.randint(800, 1600))

    def _extract_jobs_from_soup(self, soup, seen_urls):
        jobs = []

        selectors = [
            "a[href*='/jobs/']",
            "a[href*='/job/']",
            "a[href*='/l/']",
            "[data-test*='job'] a",
            "a",
        ]

        links = []
        for selector in selectors:
            links = soup.select(selector)
            if links:
                break

        for link in links[:150]:
            try:
                href = link.get("href", "").strip()
                text = link.get_text(" ", strip=True)

                if not href or len(text) < 5:
                    continue

                full_url = self._normalize_url(href)

                if not full_url or full_url in seen_urls:
                    continue

                parent = link.find_parent(["div", "li", "article", "section"])
                context = parent.get_text(" ", strip=True) if parent else text

                searchable = f"{text} {context}".lower()

                if not self._is_ios_relevant(searchable):
                    continue

                if any(bad in searchable for bad in EXCLUDE_KEYWORDS):
                    continue

                seen_urls.add(full_url)

                company = self._extract_company(context)
                role = self._extract_role(text, context)

                jobs.append({
                    "company": company,
                    "role": role,
                    "location": self._extract_location(context),
                    "remote": self._extract_remote(context),
                    "visa": "Unknown",
                    "experience": self._extract_experience(context),
                    "tags": self._extract_tags(searchable),
                    "url": full_url,
                    "description": context[:700],
                })

            except Exception:
                continue

        return jobs

    def _normalize_url(self, href):
        if href.startswith("/"):
            return f"https://wellfound.com{href}"
        if href.startswith("http"):
            return href
        return ""

    def _is_ios_relevant(self, text):
        role_hit = any(k in text for k in IOS_ROLE_KEYWORDS)
        tech_hit = any(k in text for k in IOS_TECH_KEYWORDS)
        return role_hit or tech_hit

    def _extract_company(self, text):
        patterns = [
            " · ",
            " at ",
            " is hiring",
            " hiring ",
        ]

        for p in patterns:
            if p in text.lower():
                parts = text.split(p, 1)
                if len(parts) > 1:
                    return parts[-1].strip()[:100]

        words = text.split()
        if len(words) > 2:
            return " ".join(words[:2])[:100]

        return ""

    def _extract_role(self, text, context):
        role_words = [
            "ios", "iphone", "ipad", "swift", "mobile",
            "engineer", "developer", "lead", "senior",
            "staff", "architect"
        ]

        candidate = text if len(text) > 5 else context[:150]
        candidate_lower = candidate.lower()

        if any(w in candidate_lower for w in role_words):
            return candidate[:150]

        return text[:150]

    def _extract_location(self, text):
        lower = text.lower()

        if "remote" in lower:
            return "Remote"

        common = [
            "san francisco", "new york", "london", "berlin",
            "india", "usa", "canada", "singapore"
        ]

        for city in common:
            if city in lower:
                return city.title()

        return "See post"

    def _extract_remote(self, text):
        return "Yes" if "remote" in text.lower() else "Unknown"

    def _extract_experience(self, text):
        lower = text.lower()

        for yr in range(1, 11):
            if f"{yr} year" in lower or f"{yr}+ year" in lower:
                return f"{yr}+ years"

        if "senior" in lower:
            return "Senior"
        if "staff" in lower:
            return "Staff"
        if "lead" in lower:
            return "Lead"

        return ""

    def _extract_tags(self, text):
        tags = [kw for kw in IOS_TECH_KEYWORDS if kw in text]
        return ", ".join(tags[:8])



if __name__ == "__main__":
    jobs = WellfoundScraper().run()

    print(f"Found {len(jobs)} iOS jobs on Wellfound")

    for job in jobs[:10]:
        print(
            f"{job['company'] or '?'} | "
            f"{job['role'][:60]} | "
            f"{job['location']} | "
            f"{job['url']}"
        )