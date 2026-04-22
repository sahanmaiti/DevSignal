# tests/test_processors.py
#
# Unit tests for job_parser and filter_engine.
# Run with: python -m pytest tests/ -v
#
# PLACEMENT: tests/test_processors.py

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from processors.job_parser import (
    extract_experience, extract_salary,
    extract_remote, extract_visa, parse_job,
)
from processors.filter_engine import filter_jobs, _should_drop


# ── job_parser tests ─────────────────────────────────────────

def test_extract_experience_range():
    assert extract_experience("We need 1-2 years of experience") == "1-2 years of experience"

def test_extract_experience_plus():
    assert extract_experience("Minimum 2+ years required") == "2+ years"

def test_extract_experience_entry():
    assert extract_experience("Entry level position, no experience needed") == "Entry level"
    assert extract_experience("Entry-level role, fresh grads welcome") == "Entry-level"

def test_extract_experience_empty():
    assert extract_experience("Join our team today") == ""

def test_extract_salary_usd():
    result = extract_salary("Salary range: $80,000 - $120,000 per year")
    assert "$80,000" in result

def test_extract_salary_inr():
    result = extract_salary("CTC: 8-12 LPA for this role")
    assert "LPA" in result

def test_extract_remote_yes():
    assert extract_remote("This is a fully remote position") == "Yes"

def test_extract_remote_hybrid():
    assert extract_remote("Hybrid role, 3 days in office") == "Hybrid"

def test_extract_remote_no():
    assert extract_remote("Must be in-office only, New York") == "No"

def test_extract_visa_yes():
    assert extract_visa("We offer visa sponsorship for this role") == "Yes"

def test_extract_visa_no():
    assert extract_visa("We cannot sponsor visas at this time") == "No"

def test_extract_visa_unknown():
    assert extract_visa("Great opportunity for developers") == "Unknown"

def test_parse_job_enriches_blanks():
    job = {
        "description_raw": "Remote iOS intern role. Swift and SwiftUI. Visa sponsorship available.",
        "experience_req": "",
        "remote": "Unknown",
        "visa_sponsorship": "Unknown",
        "tech_stack": "",
    }
    result = parse_job(job)
    assert result["remote"] == "Yes"
    assert result["visa_sponsorship"] == "Yes"
    assert "swift" in result["tech_stack"].lower()


# ── filter_engine tests ──────────────────────────────────────

def make_job(role, description, experience="", tech_stack=""):
    return {
        "role": role,
        "description_raw": description,
        "experience_req": experience,
        "tech_stack": tech_stack,
    }

def test_filter_keeps_good_job():
    job = make_job("iOS Developer Intern", "Swift and SwiftUI intern role", "0-1 years", "swift")
    assert _should_drop(job) == ""

def test_filter_drops_senior_title():
    job = make_job("Senior iOS Engineer", "Swift developer", "5 years", "swift")
    assert _should_drop(job) == "senior_title"

def test_filter_drops_too_much_exp():
    job = make_job("iOS Developer", "Requires minimum 4 years of Swift experience", "4 years", "swift")
    assert _should_drop(job) == "too_much_experience"

def test_filter_drops_non_ios():
    job = make_job("Backend Engineer", "Python, Django, Postgres. No mobile work.", "", "python")
    assert _should_drop(job) == "not_ios"

def test_filter_keeps_when_exp_unknown():
    """If experience is unknown, give benefit of the doubt."""
    job = make_job("iOS Developer", "Join our iOS team using Swift", "", "swift")
    assert _should_drop(job) == ""

def test_filter_jobs_list():
    jobs = [
        make_job("iOS Intern", "Swift internship", "0-1 years", "swift"),
        make_job("Senior iOS Lead", "Lead iOS team, 7 years exp", "7 years", "swift"),
        make_job("Data Engineer", "Spark, Hadoop, Python", "", "python"),
    ]
    result = filter_jobs(jobs)
    assert len(result) == 1
    assert result[0]["role"] == "iOS Intern"


if __name__ == "__main__":
    test_extract_experience_range()
    test_extract_experience_plus()
    test_extract_experience_entry()
    test_extract_experience_empty()
    test_extract_salary_usd()
    test_extract_salary_inr()
    test_extract_remote_yes()
    test_extract_remote_hybrid()
    test_extract_remote_no()
    test_extract_visa_yes()
    test_extract_visa_no()
    test_extract_visa_unknown()
    test_parse_job_enriches_blanks()
    test_filter_keeps_good_job()
    test_filter_drops_senior_title()
    test_filter_drops_too_much_exp()
    test_filter_drops_non_ios()
    test_filter_keeps_when_exp_unknown()
    test_filter_jobs_list()
    print("All processor tests passed.")