# tests/test_scrapers.py
#
# Basic unit tests for scrapers.
# Run with: python -m pytest tests/ -v
#
# PLACEMENT: tests/test_scrapers.py

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scrapers.base_scraper import BaseScraper
from scrapers.remoteok_scraper import RemoteOKScraper
from scrapers.hackernews_scraper import HackerNewsScraper


class ConcreteTestScraper(BaseScraper):
    """Minimal concrete implementation for testing BaseScraper."""
    SOURCE_NAME = "Test"

    def fetch_jobs(self):
        return []


def test_hash_is_consistent():
    """Same input should always produce the same hash."""
    scraper = ConcreteTestScraper()
    job = {"company": "Apple", "role": "iOS Intern", "url": "https://apple.com/jobs/1"}
    h1 = scraper._generate_hash(job)
    h2 = scraper._generate_hash(job)
    assert h1 == h2, "Hash should be deterministic"


def test_hash_is_different_for_different_jobs():
    """Different jobs should have different hashes."""
    scraper = ConcreteTestScraper()
    job1 = {"company": "Apple", "role": "iOS Intern", "url": "https://apple.com/1"}
    job2 = {"company": "Google", "role": "iOS Intern", "url": "https://google.com/1"}
    assert scraper._generate_hash(job1) != scraper._generate_hash(job2)


def test_normalize_has_all_required_fields():
    """Normalized job should have all schema fields."""
    scraper = ConcreteTestScraper()
    raw = {"company": "TestCo", "role": "iOS Dev", "url": "https://test.com"}
    normalized = scraper.normalize(raw)

    required_fields = [
        "date_found", "job_source", "apply_link", "job_hash",
        "company", "role", "location", "remote", "visa_sponsorship",
        "experience_req", "tech_stack", "description_raw",
        "recruiter_name", "recruiter_role", "linkedin_profile", "email",
        "opportunity_score", "score_breakdown", "outreach_message",
        "applied", "response_status", "interview_stage",
    ]
    for field in required_fields:
        assert field in normalized, f"Missing field: {field}"


def test_remoteok_is_ios_relevant():
    """iOS keyword detection should work."""
    scraper = RemoteOKScraper()
    assert scraper._is_ios_relevant("ios intern swift developer") is True
    assert scraper._is_ios_relevant("python backend engineer") is False
    assert scraper._is_ios_relevant("swiftui mobile developer") is True


def test_remoteok_salary_format():
    """Salary formatting should handle various inputs."""
    scraper = RemoteOKScraper()
    assert scraper._format_salary({"salary_min": 80000, "salary_max": 120000}) == "$80,000 – $120,000/yr"
    assert scraper._format_salary({}) == ""


def test_hn_first_line_parsing():
    """HN job posts should parse the pipe-separated first line."""
    scraper = HackerNewsScraper()
    hit = {"objectID": "12345", "comment_text": ""}
    text = "Acme Corp | iOS Intern | Remote | $3k/month\n\nWe're a Series A startup..."

    job = scraper._build_job_dict(hit, text)
    assert job["company"] == "Acme Corp"
    assert "iOS Intern" in job["role"]
    assert job["remote"] == "Yes"


if __name__ == "__main__":
    # Run without pytest if needed
    test_hash_is_consistent()
    test_hash_is_different_for_different_jobs()
    test_normalize_has_all_required_fields()
    test_remoteok_is_ios_relevant()
    test_remoteok_salary_format()
    test_hn_first_line_parsing()
    print("All scraper tests passed.")