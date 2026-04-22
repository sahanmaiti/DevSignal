# processors/filter_engine.py
#
# PURPOSE:
#   Quality gate that drops jobs not matching your target profile
#   before they reach the database.
#
# PHILOSOPHY:
#   When in doubt, KEEP the job. It's better to store a borderline
#   job and let the AI scorer give it a low score than to silently
#   drop something you might have wanted.
#
#   Only drop when we're confident it doesn't match:
#   - Clearly too senior (5+ years required)
#   - Explicitly not iOS (no iOS/Swift signals anywhere)
#   - Seniority keywords in the title (Senior, Staff, Principal)
#
# PLACEMENT: processors/filter_engine.py

import re
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.keywords import IOS_ROLE_KEYWORDS, IOS_TECH_KEYWORDS, EXCLUDE_KEYWORDS
from config.settings import MAX_EXPERIENCE_YEARS


def filter_jobs(jobs: list) -> list:
    """
    Filters a list of jobs down to those matching your target profile.

    Returns the filtered list and prints a summary of what was dropped and why.
    """
    if not jobs:
        return []

    results        = []
    dropped_senior = 0
    dropped_exp    = 0
    dropped_ios    = 0
    kept           = 0

    for job in jobs:
        reason = _should_drop(job)
        if reason == "senior_title":
            dropped_senior += 1
        elif reason == "too_much_experience":
            dropped_exp += 1
        elif reason == "not_ios":
            dropped_ios += 1
        else:
            results.append(job)
            kept += 1

    total = len(jobs)
    print(f"\n[Filter] {total} jobs in → {kept} jobs out")
    print(f"[Filter]   Dropped {dropped_senior} senior title roles")
    print(f"[Filter]   Dropped {dropped_exp} over-experience roles")
    print(f"[Filter]   Dropped {dropped_ios} non-iOS roles")

    return results


def _should_drop(job: dict) -> str:
    """
    Returns a drop reason string if the job should be filtered out,
    or "" if the job should be kept.

    Drop reasons:
      "senior_title"        — title contains senior/staff/principal/etc.
      "too_much_experience" — explicitly requires 3+ years
      "not_ios"             — no iOS/Swift signals anywhere in the job
      ""                    — keep this job
    """
    title       = job.get("role", "").lower()
    description = job.get("description_raw", "").lower()
    tech_stack  = job.get("tech_stack", "").lower()
    experience  = job.get("experience_req", "").lower()

    # ── Check 1: Senior title exclusions ──────────────────────────────────
    for kw in EXCLUDE_KEYWORDS:
        if kw in title:
            return "senior_title"

    # ── Check 2: Experience requirement too high ───────────────────────────
    # Only drop if we can CONFIRM it requires more than MAX_EXPERIENCE_YEARS.
    # If experience_req is empty, we give benefit of the doubt.
    if experience:
        years = _extract_max_years(experience)
        if years is not None and years > MAX_EXPERIENCE_YEARS:
            return "too_much_experience"

    # Also check the raw description for explicit high experience requirements
    desc_years = _extract_max_years_from_text(description)
    if desc_years is not None and desc_years > MAX_EXPERIENCE_YEARS:
        return "too_much_experience"

    # ── Check 3: Not iOS at all ────────────────────────────────────────────
    # Combined text: title + description + tech_stack
    combined = title + " " + description + " " + tech_stack

    has_ios_signal = False
    for kw in IOS_ROLE_KEYWORDS:
        if kw in combined:
            has_ios_signal = True
            break

    if not has_ios_signal:
        for kw in IOS_TECH_KEYWORDS:
            if kw in combined:
                has_ios_signal = True
                break

    if not has_ios_signal:
        return "not_ios"

    # ── Job passed all filters ─────────────────────────────────────────────
    return ""


def _extract_max_years(experience_text: str) -> int | None:
    """
    Extracts the maximum years figure from an experience string.
    Returns None if no number found.

    Examples:
        "1-2 years"     → 2
        "2+ years"      → 2
        "3 years"       → 3
        "entry level"   → 0
        ""              → None
    """
    if not experience_text:
        return None

    text = experience_text.lower()

    # "entry level", "fresh graduate", "no experience" → 0 years
    if any(p in text for p in [
        "entry level", "entry-level", "fresh graduate",
        "no experience", "no prior", "0 years", "0-1"
    ]):
        return 0

    # "X-Y years" → return Y (the maximum)
    range_match = re.search(r'(\d+)\s*[-–]\s*(\d+)\s*years?', text)
    if range_match:
        return int(range_match.group(2))

    # "X+ years" or "X years" → return X
    single_match = re.search(r'(\d+)\+?\s*years?', text)
    if single_match:
        return int(single_match.group(1))

    return None


def _extract_max_years_from_text(text: str) -> int | None:
    """
    Scans free-form description text for experience requirements.
    Only returns a value when we're confident it's a hard requirement.
    Returns None if unclear (to avoid false drops).
    """
    # Only check explicit requirement phrases — not casual mentions
    requirement_patterns = [
        r'(?:requires?|minimum|must have|at least)\s+(\d+)\+?\s*years?',
        r'(\d+)\+\s*years?\s+(?:of\s+)?(?:experience|exp)\s+(?:required|needed|preferred)',
    ]

    for pattern in requirement_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return int(match.group(1))

    return None


# ─────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing filter_engine...")
    print("=" * 55)

    test_jobs = [
        {
            "role": "iOS Developer Intern",
            "description_raw": "We need a Swift developer intern. 0-1 years experience.",
            "experience_req": "0-1 years",
            "tech_stack": "swift, swiftui",
            "expected": "KEEP",
        },
        {
            "role": "Senior iOS Engineer",
            "description_raw": "Senior Swift developer, 5+ years required.",
            "experience_req": "5+ years",
            "tech_stack": "swift",
            "expected": "DROP (senior title)",
        },
        {
            "role": "iOS Developer",
            "description_raw": "Requires minimum 4 years of experience in iOS development.",
            "experience_req": "4 years",
            "tech_stack": "swift, objc",
            "expected": "DROP (too much exp)",
        },
        {
            "role": "Backend Engineer Intern",
            "description_raw": "Python, Django, PostgreSQL. REST APIs. Entry level.",
            "experience_req": "",
            "tech_stack": "python, django",
            "expected": "DROP (not iOS)",
        },
        {
            "role": "Mobile Developer",
            "description_raw": "Looking for a mobile developer with SwiftUI experience.",
            "experience_req": "",
            "tech_stack": "swiftui",
            "expected": "KEEP (has iOS signal)",
        },
    ]

    print()
    for job in test_jobs:
        reason = _should_drop(job)
        verdict = "KEEP" if not reason else f"DROP ({reason})"
        match   = "✓" if job["expected"].startswith(verdict.split()[0]) else "✗"
        print(f"  {match} {job['role'][:35]:<35} → {verdict}")
        print(f"      Expected: {job['expected']}")
        print()