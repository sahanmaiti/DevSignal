# tests/test_notifications.py
#
# Tests for the Telegram notification formatter.
# These tests do NOT make real API calls — they only test the
# message formatting logic.
#
# Run with: python -m pytest tests/test_notifications.py -v
#
# PLACEMENT: tests/test_notifications.py

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from notifications.telegram_bot import TelegramBot

# Create a bot instance without caring about credentials
# (we're only testing formatters, not sending)
bot = TelegramBot()


# ── HTML escaping ─────────────────────────────────────────────────────────

def test_escape_html_ampersand():
    assert bot._escape_html("A&B Corp") == "A&amp;B Corp"

def test_escape_html_less_than():
    assert bot._escape_html("score < 100") == "score &lt; 100"

def test_escape_html_greater_than():
    assert bot._escape_html("score > 50") == "score &gt; 50"

def test_escape_html_empty():
    assert bot._escape_html("") == ""

def test_escape_html_no_special_chars():
    assert bot._escape_html("Acme Corp") == "Acme Corp"


# ── Message splitting ─────────────────────────────────────────────────────

def test_split_short_message():
    text = "Short message"
    chunks = bot._split_message(text)
    assert len(chunks) == 1
    assert chunks[0] == text

def test_split_long_message():
    # Create a message longer than 4096 chars
    text = "line\n" * 1000   # 5000 chars
    chunks = bot._split_message(text)
    assert len(chunks) > 1
    for chunk in chunks:
        assert len(chunk) <= 4096


# ── Digest formatter ──────────────────────────────────────────────────────

def test_digest_with_jobs():
    jobs = [
        {
            "company": "Acme Corp",
            "role": "iOS Intern",
            "remote": "Yes",
            "location": "Remote",
            "job_source": "RemoteOK",
            "opportunity_score": 88,
            "apply_link": "https://example.com/1",
        },
    ]
    msg = bot._format_digest(jobs)
    assert "Acme Corp" in msg
    assert "iOS Intern" in msg
    assert "88/100" in msg
    assert "https://example.com/1" in msg

def test_digest_caps_at_five():
    jobs = [
        {
            "company": f"Company {i}",
            "role": "iOS Intern",
            "remote": "Yes",
            "location": "",
            "job_source": "Test",
            "opportunity_score": 90 - i,
            "apply_link": f"https://example.com/{i}",
        }
        for i in range(10)
    ]
    msg = bot._format_digest(jobs)
    # Should mention +5 more
    assert "+5 more" in msg

def test_digest_handles_html_in_company_name():
    jobs = [{
        "company": "A&B Corp <Testing>",
        "role": "iOS Intern",
        "remote": "Yes",
        "location": "",
        "job_source": "HackerNews",
        "opportunity_score": None,
        "apply_link": "https://example.com",
    }]
    msg = bot._format_digest(jobs)
    # Raw & and < should be escaped
    assert "&amp;" in msg
    assert "&lt;" in msg
    # Raw & should NOT appear
    assert "A&B" not in msg

def test_digest_handles_unscored_job():
    jobs = [{
        "company": "Startup",
        "role": "iOS Dev",
        "remote": "Yes",
        "location": "",
        "job_source": "Remotive",
        "opportunity_score": None,  # not scored yet
        "apply_link": "https://example.com",
    }]
    msg = bot._format_digest(jobs)
    # Should show source instead of score
    assert "Remotive" in msg

def test_no_jobs_message():
    msg = bot._format_no_jobs_message()
    assert "No new iOS opportunities" in msg


# ── Run summary formatter ─────────────────────────────────────────────────

def test_run_summary_basic():
    msg = bot._format_run_summary(
        jobs_found=70,
        jobs_filtered=51,
        jobs_new=44,
        jobs_stored=44,
        sources=None,
    )
    assert "70" in msg
    assert "44" in msg

def test_run_summary_with_sources():
    msg = bot._format_run_summary(
        jobs_found=55,
        jobs_filtered=51,
        jobs_new=44,
        jobs_stored=44,
        sources={"HackerNews": 54, "Remotive": 1},
    )
    assert "HackerNews" in msg
    assert "54" in msg


if __name__ == "__main__":
    test_escape_html_ampersand()
    test_escape_html_less_than()
    test_escape_html_greater_than()
    test_escape_html_empty()
    test_escape_html_no_special_chars()
    test_split_short_message()
    test_split_long_message()
    test_digest_with_jobs()
    test_digest_caps_at_five()
    test_digest_handles_html_in_company_name()
    test_digest_handles_unscored_job()
    test_no_jobs_message()
    test_run_summary_basic()
    test_run_summary_with_sources()
    print("All notification tests passed.")