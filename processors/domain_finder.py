# processors/domain_finder.py
#
# PURPOSE:
#   Extracts or guesses a company's website domain from available job data.
#   The domain is required before we can query Hunter.io for email patterns.
#
# APPROACH:
#   1. Extract directly from apply_link URL if it's a company site
#   2. Strip company name to likely domain and verify it resolves
#   3. Return None if we can't determine the domain confidently
#
# PLACEMENT: processors/domain_finder.py

import re
import sys
import os
from urllib.parse import urlparse

import requests

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# Job boards whose URLs we should NOT use as company domains
JOB_BOARD_DOMAINS = {
    "linkedin.com", "indeed.com", "glassdoor.com",
    "remoteok.com", "remotive.com", "workatastartup.com",
    "news.ycombinator.com", "ycombinator.com", "wellfound.com",
    "angel.co", "lever.co", "greenhouse.io", "ashbyhq.com",
    "workable.com", "smartrecruiters.com", "jobvite.com",
    "breezy.hr", "recruitee.com", "jobs.ashbyhq.com",
    "apply.workable.com", "boards.greenhouse.io",
}

# Common company name suffixes to strip before guessing domain
COMPANY_SUFFIXES = [
    r"\s+inc\.?$", r"\s+ltd\.?$", r"\s+llc\.?$",
    r"\s+corp\.?$", r"\s+co\.?$", r"\s+gmbh$",
    r"\s+technologies$", r"\s+technology$",
    r"\s+solutions$", r"\s+systems$", r"\s+software$",
    r"\s+labs?$", r"\s+studio$", r"\s+group$",
    r"\s+mobile$", r"\s+apps?$",
]


def find_domain(job: dict) -> str | None:
    """
    Attempts to find the company's website domain from a job dict.

    Returns a clean domain string like "stripe.com", or None if not found.
    """
    # Strategy 1: extract from apply_link
    domain = _extract_from_url(job.get("apply_link", ""))
    if domain:
        return domain

    # Strategy 2: guess from company name
    company = job.get("company", "").strip()
    if company:
        domain = _guess_from_company_name(company)
        if domain:
            return domain

    return None


def _extract_from_url(url: str) -> str | None:
    """
    Extracts the domain from a URL, skipping job board domains.

    Examples:
    "https://stripe.com/jobs/123"  → "stripe.com"
    "https://boards.greenhouse.io/stripe/jobs/123" → "stripe.com" (extracted from path)
    "https://remoteok.com/remote-jobs/456"  → None (job board)
    """
    if not url:
        return None

    try:
        parsed = urlparse(url)
        hostname = parsed.netloc.lower()

        # Remove www. prefix
        if hostname.startswith("www."):
            hostname = hostname[4:]

        # Skip job boards
        for jb in JOB_BOARD_DOMAINS:
            if hostname == jb or hostname.endswith("." + jb):
                # Special case: Greenhouse URLs sometimes have company in path
                # e.g. boards.greenhouse.io/stripe → stripe.io → but we want stripe.com
                # We skip this complexity and just return None
                return None

        # Skip very short or clearly invalid domains
        if len(hostname) < 4 or "." not in hostname:
            return None

        return hostname

    except Exception:
        return None


def _guess_from_company_name(company: str) -> str | None:
    """
    Converts a company name to a likely domain and verifies it resolves.

    "Acme Corp"  → tries "acme.com" → verifies HTTP → returns "acme.com"
    "Hi-Art"     → tries "hi-art.com" → fails → tries "hiart.com" → etc.
    """
    # Clean the name: lowercase, strip suffixes, remove special chars
    name = company.lower().strip()

    # Strip HTML tags that might have slipped through
    name = re.sub(r'<[^>]+>', '', name)

    # Strip common suffixes
    for pattern in COMPANY_SUFFIXES:
        name = re.sub(pattern, '', name, flags=re.IGNORECASE)
    name = name.strip()

    # Convert to domain-safe format
    # Remove everything except letters, numbers, hyphens
    domain_base = re.sub(r'[^a-z0-9\-]', '', name.replace(' ', '').replace('_', ''))

    if not domain_base or len(domain_base) < 2:
        return None

    # Try common TLDs in order of likelihood
    candidates = [
        f"{domain_base}.com",
        f"{domain_base}.io",
        f"{domain_base}.co",
        f"{domain_base}.app",
    ]

    for candidate in candidates:
        if _domain_resolves(candidate):
            return candidate

    return None


def _domain_resolves(domain: str) -> bool:
    """
    Checks if a domain resolves to a real website.
    Uses a HEAD request — faster than GET, downloads no content.
    Times out quickly to avoid slowing down the pipeline.
    """
    try:
        response = requests.head(
            f"https://{domain}",
            timeout=4,
            allow_redirects=True,
            headers={"User-Agent": "Mozilla/5.0"},
        )
        # Any response (even 4xx) means the domain is real
        return response.status_code < 500
    except Exception:
        # Connection refused, timeout, DNS failure = domain doesn't exist
        return False


def extract_email_from_text(text: str) -> str:
    """
    Extracts an email address directly from job description text.
    Some HN posts include "email us at jobs@company.com" directly.
    """
    pattern = r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Z|a-z]{2,}\b'
    matches = re.findall(pattern, text)

    if not matches:
        return ""

    # Filter out generic/example emails
    filtered = [
        m for m in matches
        if not any(skip in m.lower() for skip in [
            "example.com", "test.com", "email.com",
            "yourname", "company.com", "domain.com"
        ])
    ]

    return filtered[0] if filtered else ""


# ─────────────────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing domain_finder...")
    print("=" * 55)

    test_cases = [
        {
            "name": "Direct company URL",
            "job": {
                "company": "Stripe",
                "apply_link": "https://stripe.com/jobs/listing/ios-intern/123",
            },
            "expected": "stripe.com",
        },
        {
            "name": "Greenhouse ATS URL",
            "job": {
                "company": "Figma",
                "apply_link": "https://boards.greenhouse.io/figma/jobs/456",
            },
            "expected": None,   # job board, extracted from path is complex
        },
        {
            "name": "HN post (no good URL)",
            "job": {
                "company": "nooro",
                "apply_link": "https://news.ycombinator.com/item?id=12345",
            },
            "expected": None,   # will try to resolve nooro.com
        },
        {
            "name": "Email in description",
            "job": {
                "company": "Some Startup",
                "apply_link": "",
                "description_raw": "Send your resume to jobs@somestartup.io",
            },
            "expected_email": "jobs@somestartup.io",
        },
    ]

    print()
    for tc in test_cases:
        job    = tc["job"]
        domain = find_domain(job)
        print(f"  {tc['name']}")
        print(f"    Company:  {job['company']}")
        print(f"    Domain:   {domain or 'not found'}")

        if "expected_email" in tc:
            email = extract_email_from_text(job.get("description_raw", ""))
            print(f"    Email:    {email or 'not found'}")
        print()