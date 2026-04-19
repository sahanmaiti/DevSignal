# scrapers/base_scraper.py
#
# PURPOSE:
#   The abstract blueprint that every scraper inherits from.
#   Provides shared utilities: HTTP session, normalize(), hash generation, run().
#
#   You never use BaseScraper directly — you always use a subclass like
#   RemoteOKScraper or HackerNewsScraper, which inherit from it.
#
# CONCEPT — Inheritance:
#   class RemoteOKScraper(BaseScraper):  ← this means "RemoteOKScraper IS A BaseScraper"
#   It automatically gets all methods defined here, plus any it defines itself.

import hashlib
import requests
import re
from abc import ABC, abstractmethod
from datetime import datetime, timezone


class BaseScraper(ABC):
    """
    Abstract base class for all iOS job scrapers.

    Subclass this and implement fetch_jobs() to create a new scraper.
    Call .run() to get a normalized list of job dicts ready for the database.
    """

    # Subclasses must set this. It becomes the "job_source" field in the DB.
    # Example: SOURCE_NAME = "RemoteOK"
    SOURCE_NAME: str = ""

    def __init__(self):
        """
        Creates a reusable HTTP session.

        Why a session instead of plain requests.get()?
        A session keeps connections open between requests (connection pooling),
        maintains headers across all requests, and handles cookies automatically.
        Much more efficient than opening a fresh connection every time.
        """
        self.session = requests.Session()

        # Set headers that make requests look like they come from a real browser.
        # Some websites block requests without a User-Agent header,
        # returning 403 Forbidden or 429 Too Many Requests.
        self.session.headers.update({
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
            "Accept": "application/json, text/html, */*",
            "Accept-Language": "en-US,en;q=0.9",
        })

    # ─────────────────────────────────────────────────────────────────────────
    # ABSTRACT METHOD — every subclass MUST implement this
    # ─────────────────────────────────────────────────────────────────────────

    @abstractmethod
    def fetch_jobs(self) -> list[dict]:
        """
        Fetch raw job data from this scraper's source.

        Must return a list of dicts. Each dict can have any keys —
        normalize() will convert them to the standard schema.

        Example return:
        [
            {
                "company": "Stripe",
                "role": "iOS Engineer Intern",
                "url": "https://stripe.com/jobs/...",
                "location": "Remote",
                "tags": "swift, swiftui, ios",
                "description": "We're looking for..."
            },
            ...
        ]
        """
        pass  # Subclasses replace this with real code

    # ─────────────────────────────────────────────────────────────────────────
    # NORMALIZE — converts any raw job dict into our standard 21-field schema
    # ─────────────────────────────────────────────────────────────────────────

    def normalize(self, raw_job: dict) -> dict:
        """
        Converts a source-specific raw job dict into our standard schema.

        This is called automatically by run() for every job fetched.
        The output matches exactly the columns in our PostgreSQL table.

        raw_job keys vary per source (RemoteOK uses "position",
        LinkedIn uses "title", etc.) — normalize() handles all of that.
        """
        return {
            # ── Discovery metadata ────────────────────────────────────────────
            # When we found it — always UTC time
            "date_found":       datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
            # Which platform it came from
            "job_source":       self.SOURCE_NAME,
            # Link to the job posting
            "apply_link":       raw_job.get("url", ""),
            # MD5 fingerprint of company+role+url — used for deduplication
            "job_hash":         self._generate_hash(raw_job),

            # ── Job details ──────────────────────────────────────────────────
            "company":          raw_job.get("company", "").strip(),
            "role":             raw_job.get("role", "").strip(),
            "location":         raw_job.get("location", "").strip(),
            "remote":           raw_job.get("remote", "Unknown"),
            "visa_sponsorship": raw_job.get("visa", "Unknown"),
            "experience_req":   raw_job.get("experience", ""),
            "tech_stack":       raw_job.get("tags", ""),
            "description_raw":  raw_job.get("description", "")[:1000],  # cap at 1000 chars

            # ── Recruiter info (filled later by processors/enricher.py) ──────
            "recruiter_name":   "",
            "recruiter_role":   "",
            "linkedin_profile": "",
            "email":            "",

            # ── AI fields (filled later by ai/scorer.py) ─────────────────────
            "opportunity_score":  None,   # None = not scored yet
            "score_breakdown":    None,
            "outreach_message":   "",

            # ── Application tracking (you fill these manually) ────────────────
            "applied":            False,
            "response_status":    "",
            "interview_stage":    "",
        }

    # ─────────────────────────────────────────────────────────────────────────
    # HELPER — generates a unique fingerprint for deduplication
    # ─────────────────────────────────────────────────────────────────────────

    def _generate_hash(self, job: dict) -> str:
        """
        Creates a unique 32-character fingerprint for a job.

        Why MD5? It's fast and produces a fixed-length string.
        We're not using it for security — just for deduplication.

        We combine company + role + URL because:
        - Same company + different role = different job (keep both)
        - Same company + same role + same URL = exact duplicate (skip)
        - Same company + same role + different URL = same job on 2 platforms (skip)
          Actually this is debatable — we'll keep both for now since apply links differ.
        """
        # Normalize the key components: lowercase, strip whitespace
        company = job.get("company", "").lower().strip()
        role    = job.get("role", "").lower().strip()
        url     = job.get("url", "").lower().strip()

        # Remove common URL query parameters that change without the job changing
        # e.g., "?ref=remoteok&source=linkedin" → just the base URL
        url = re.sub(r'\?.*$', '', url)  # remove everything after ?

        raw_string = f"{company}|{role}|{url}"

        # md5() creates a hash object, hexdigest() converts it to a hex string
        return hashlib.md5(raw_string.encode("utf-8")).hexdigest()

    # ─────────────────────────────────────────────────────────────────────────
    # RUN — the main public entry point
    # ─────────────────────────────────────────────────────────────────────────

    def run(self) -> list[dict]:
        """
        Runs this scraper and returns a list of normalized job dicts.

        This is the only method you ever call from outside the scraper:
            scraper = RemoteOKScraper()
            jobs = scraper.run()

        It handles:
        1. Calling fetch_jobs() to get raw data
        2. Normalizing each raw job into the standard schema
        3. Catching errors so one broken scraper doesn't crash everything
        """
        print(f"\n[{self.SOURCE_NAME}] Starting...")

        try:
            raw_jobs = self.fetch_jobs()
            normalized = [self.normalize(job) for job in raw_jobs]
            print(f"[{self.SOURCE_NAME}] Found {len(normalized)} iOS-relevant jobs")
            return normalized

        except requests.exceptions.ConnectionError:
            print(f"[{self.SOURCE_NAME}] ERROR: Could not connect. Check your internet.")
            return []

        except requests.exceptions.Timeout:
            print(f"[{self.SOURCE_NAME}] ERROR: Request timed out after 15 seconds.")
            return []

        except requests.exceptions.HTTPError as e:
            print(f"[{self.SOURCE_NAME}] ERROR: HTTP {e.response.status_code} — {e}")
            return []

        except Exception as e:
            # Catch-all: log the error but don't crash the whole pipeline
            print(f"[{self.SOURCE_NAME}] ERROR: Unexpected error — {type(e).__name__}: {e}")
            return []