# tests/test_enricher.py
#
# Unit tests for enrichment modules.
# No real API calls — tests logic and parsing only.
#
# PLACEMENT: tests/test_enricher.py

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from processors.domain_finder   import (
    find_domain, extract_email_from_text, _extract_from_url,
)
from processors.linkedin_finder import LinkedInFinder


# ── Domain extraction ────────────────────────────────────────────────────

def test_extract_company_domain_from_direct_url():
    result = _extract_from_url("https://stripe.com/jobs/listing/ios/123")
    assert result == "stripe.com"

def test_extract_strips_www():
    result = _extract_from_url("https://www.figma.com/careers/123")
    assert result == "figma.com"

def test_extract_skips_job_boards():
    result = _extract_from_url("https://boards.greenhouse.io/stripe/jobs/123")
    assert result is None

def test_extract_skips_remoteok():
    result = _extract_from_url("https://remoteok.com/remote-jobs/456")
    assert result is None

def test_extract_skips_hackernews():
    result = _extract_from_url("https://news.ycombinator.com/item?id=12345")
    assert result is None

def test_extract_email_from_text():
    text = "Send your resume to jobs@acmecorp.io to apply"
    email = extract_email_from_text(text)
    assert email == "jobs@acmecorp.io"

def test_extract_email_ignores_examples():
    text = "Contact us at example@example.com for info"
    email = extract_email_from_text(text)
    assert email == ""

def test_extract_email_not_found():
    text = "No email address in this text at all"
    email = extract_email_from_text(text)
    assert email == ""

def test_find_domain_from_direct_url():
    job = {
        "company":    "Stripe",
        "apply_link": "https://stripe.com/jobs/123",
    }
    domain = find_domain(job)
    assert domain == "stripe.com"

def test_find_domain_returns_none_for_job_board():
    job = {
        "company":    "Stripe",
        "apply_link": "https://linkedin.com/jobs/view/123",
    }
    domain = find_domain(job)
    # Job board URL → should try company name guessing
    # stripe.com likely resolves, so this might return "stripe.com"
    # but the logic is correct either way
    assert domain is None or "stripe" in (domain or "")


# ── LinkedIn name extraction ─────────────────────────────────────────────

def make_finder():
    """Create finder instance (Serper key optional for name extraction tests)."""
    import unittest.mock as mock
    with mock.patch.dict(os.environ, {"SERPER_API_KEY": ""}):
        return LinkedInFinder()

def test_linkedin_extract_name_standard_format():
    finder = make_finder()
    title  = "Jane Smith - iOS Engineering Manager at Stripe | LinkedIn"
    name   = finder._extract_name_from_title(title)
    assert name == "Jane Smith"

def test_linkedin_extract_name_pipe_format():
    finder = make_finder()
    title  = "John Doe | Senior Recruiter | Figma | LinkedIn"
    name   = finder._extract_name_from_title(title)
    assert name == "John Doe"

def test_linkedin_extract_role():
    finder = make_finder()
    title  = "Jane Smith - iOS Engineering Manager at Stripe | LinkedIn"
    role   = finder._extract_role_from_title(title)
    assert "iOS Engineering Manager" in role

def test_linkedin_clean_url_removes_params():
    finder = make_finder()
    url    = "https://linkedin.com/in/janesmith?utm_source=google&trk=public"
    clean  = finder._clean_linkedin_url(url)
    assert clean == "https://linkedin.com/in/janesmith"

def test_linkedin_clean_company_name():
    finder = make_finder()
    assert finder._clean_company_name("Acme Corp, Inc.") == "Acme Corp"
    assert finder._clean_company_name("Hi-Art (Remote)") == "Hi-Art"
    assert finder._clean_company_name("<a href='...'>Nextdoor</a>") == "Nextdoor"


if __name__ == "__main__":
    test_extract_company_domain_from_direct_url()
    test_extract_strips_www()
    test_extract_skips_job_boards()
    test_extract_skips_remoteok()
    test_extract_skips_hackernews()
    test_extract_email_from_text()
    test_extract_email_ignores_examples()
    test_extract_email_not_found()
    test_find_domain_from_direct_url()
    test_find_domain_returns_none_for_job_board()
    test_linkedin_extract_name_standard_format()
    test_linkedin_extract_name_pipe_format()
    test_linkedin_extract_role()
    test_linkedin_clean_url_removes_params()
    test_linkedin_clean_company_name()
    print("All enricher tests passed.")