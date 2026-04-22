# processors/job_parser.py
#
# PURPOSE:
#   Extracts structured fields from raw job description text.
#   Runs after scraping, before database insertion.
#
# WHAT IT EXTRACTS:
#   - experience_req  : "1-2 years", "entry level", "fresh graduate"
#   - salary          : "$80k-$120k", "₹8-12 LPA"
#   - visa_sponsorship: "Yes" / "No" / "Unknown"
#   - remote          : "Yes" / "No" / "Hybrid" / "Unknown"
#   - tech_stack      : list of recognised tech keywords found in text
#
# HOW IT WORKS:
#   Regex patterns match common phrasings in job descriptions.
#   Multiple patterns per field because companies write things differently.
#
# PLACEMENT: processors/job_parser.py

import re
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.keywords import IOS_TECH_KEYWORDS, VISA_POSITIVE_PHRASES


# ─────────────────────────────────────────────────────────────
# EXPERIENCE PATTERNS
# Order matters — more specific patterns first
# ─────────────────────────────────────────────────────────────
EXPERIENCE_PATTERNS = [
    # "0-1 years", "1-2 years of experience", "2+ years"
    r'(\d+\s*[-–]\s*\d+\s*years?\s*(?:of\s*)?(?:experience|exp)?)',
    r'(\d+\+\s*years?\s*(?:of\s*)?(?:experience|exp)?)',
    r'(\d+\s*years?\s*(?:of\s*)?(?:experience|exp))',
    # "minimum 2 years", "at least 1 year"
    r'(?:minimum|min\.?|at least)\s*(\d+\s*years?)',
    # "entry level", "junior", "fresh graduate", "no experience"
    r'(entry[- ]level)',
    r'(fresh\s*graduate)',
    r'(no\s*(?:prior\s*)?experience\s*(?:required|needed)?)',
    r'(0[- ]?1\s*years?)',
]

# ─────────────────────────────────────────────────────────────
# SALARY PATTERNS
# ─────────────────────────────────────────────────────────────
SALARY_PATTERNS = [
    # USD: "$80,000 - $120,000", "$80k-$120k/yr"
    r'(\$[\d,]+k?\s*[-–]\s*\$[\d,]+k?(?:\s*(?:per\s*year|/yr|annually))?)',
    r'(\$[\d,]+k?(?:\s*(?:per\s*year|/yr|annually|per\s*hour|/hr))?)',
    # INR: "₹8-12 LPA", "8 LPA", "CTC: 6-8 LPA"
    r'((?:₹|INR|CTC:?\s*)[\d,.]+\s*[-–]\s*[\d,.]+\s*LPA)',
    r'([\d,.]+\s*[-–]\s*[\d,.]+\s*LPA)',
    r'([\d,.]+\s*LPA)',
    # Stipend: "₹30,000/month", "$3000/month stipend"
    r'((?:₹|\$)[\d,]+\s*(?:per\s*month|/month|monthly)(?:\s*stipend)?)',
    r'([\d,]+\s*(?:per\s*month|/month)\s*stipend)',
]

# ─────────────────────────────────────────────────────────────
# REMOTE PATTERNS
# ─────────────────────────────────────────────────────────────
REMOTE_YES_PATTERNS = [
    r'\bremote\b',
    r'\bwork from home\b',
    r'\bwfh\b',
    r'\bfully remote\b',
    r'\b100%\s*remote\b',
    r'\bdistributed\s*team\b',
    r'\banywhere\b',
]

REMOTE_HYBRID_PATTERNS = [
    r'\bhybrid\b',
    r'\bpartially remote\b',
    r'\b\d+\s*days?\s*(?:a week\s*)?(?:in[- ]office|remote)\b',
]

# ─────────────────────────────────────────────────────────────
# INTERNSHIP CONFIRMATION PATTERNS
# ─────────────────────────────────────────────────────────────
INTERNSHIP_PATTERNS = [
    r'\bintern(?:ship)?\b',
    r'\bco[- ]op\b',
    r'\bsummer\s*(?:role|position|opportunity)\b',
    r'\bfull[- ]time\s*(?:role|position)',  # not internship
]


def parse_job(job: dict) -> dict:
    """
    Takes a normalized job dict and enriches it with
    fields extracted from description_raw.

    Returns the same dict with improved field values.
    Existing non-empty values are preserved — the parser
    only fills in blanks or upgrades "Unknown" values.
    """
    text = job.get("description_raw", "")
    if not text:
        return job

    # Work on a copy so we don't mutate the original
    enriched = dict(job)

    # ── Experience requirement ────────────────────────────────────────────
    if not enriched.get("experience_req"):
        enriched["experience_req"] = extract_experience(text)

    # ── Salary ───────────────────────────────────────────────────────────
    # Not in schema yet but useful for scoring — store in tech_stack for now
    # We'll add a proper salary column in Phase 5
    salary = extract_salary(text)
    if salary and "salary" not in enriched.get("tech_stack", "").lower():
        existing_tags = enriched.get("tech_stack", "")
        if existing_tags:
            enriched["tech_stack"] = existing_tags + f", salary:{salary}"
        else:
            enriched["tech_stack"] = f"salary:{salary}"

    # ── Remote detection (upgrade "Unknown" if we find signals) ──────────
    if enriched.get("remote") == "Unknown":
        enriched["remote"] = extract_remote(text)

    # ── Visa sponsorship (upgrade "Unknown" if we find signals) ──────────
    if enriched.get("visa_sponsorship") == "Unknown":
        enriched["visa_sponsorship"] = extract_visa(text)

    # ── Tech stack (add any keywords found in description) ────────────────
    enriched["tech_stack"] = enrich_tech_stack(
        enriched.get("tech_stack", ""), text
    )

    return enriched


def extract_experience(text: str) -> str:
    """
    Returns the first experience requirement found in the text.
    Returns "" if nothing found.
    """
    for pattern in EXPERIENCE_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1).strip()
    return ""


def extract_salary(text: str) -> str:
    """
    Returns the first salary mention found in the text.
    Returns "" if nothing found.
    """
    for pattern in SALARY_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1).strip()
    return ""


def extract_remote(text: str) -> str:
    """
    Determines remote status from text.
    Returns "Yes", "Hybrid", "No", or "Unknown".
    """
    text_lower = text.lower()

    for pattern in REMOTE_HYBRID_PATTERNS:
        if re.search(pattern, text_lower):
            return "Hybrid"

    for pattern in REMOTE_YES_PATTERNS:
        if re.search(pattern, text_lower):
            return "Yes"

    # Explicit office-only signals
    if any(p in text_lower for p in [
        "in-office only", "on-site only", "onsite only",
        "must be located in", "must relocate", "no remote"
    ]):
        return "No"

    return "Unknown"


def extract_visa(text: str) -> str:
    text_lower = text.lower()

    # Check NEGATIVE signals first — they're more specific
    negative_signals = [
        "no visa", "cannot sponsor", "not able to sponsor",
        "unable to sponsor", "us citizens only", "citizens and permanent residents",
        "must be authorized", "no sponsorship", "not sponsor",
    ]
    for signal in negative_signals:
        if signal in text_lower:
            return "No"

    # Then check positive signals
    for phrase in VISA_POSITIVE_PHRASES:
        if phrase in text_lower:
            return "Yes"

    return "Unknown"


def enrich_tech_stack(existing_tags: str, description: str) -> str:
    """
    Adds any iOS/tech keywords found in the description
    to the existing tag list, avoiding duplicates.
    """
    desc_lower = description.lower()
    existing_lower = existing_tags.lower()

    new_tags = []
    for kw in IOS_TECH_KEYWORDS:
        if kw in desc_lower and kw not in existing_lower:
            new_tags.append(kw)

    if new_tags:
        if existing_tags:
            return existing_tags + ", " + ", ".join(new_tags[:5])
        return ", ".join(new_tags[:8])

    return existing_tags


def parse_jobs(jobs: list) -> list:
    """
    Runs parse_job() on an entire list of jobs.
    Called from run_scraper.py after scraping and deduplication.
    """
    parsed = [parse_job(job) for job in jobs]

    # Count improvements made
    exp_filled  = sum(1 for j in parsed if j.get("experience_req"))
    remote_yes  = sum(1 for j in parsed if j.get("remote") == "Yes")
    visa_known  = sum(1 for j in parsed if j.get("visa_sponsorship") != "Unknown")

    print(f"[Parser] Parsed {len(parsed)} jobs:")
    print(f"[Parser]   Experience extracted: {exp_filled}")
    print(f"[Parser]   Remote confirmed:     {remote_yes}")
    print(f"[Parser]   Visa status known:    {visa_known}")

    return parsed


# ─────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing job_parser on sample descriptions...")
    print("=" * 55)

    test_cases = [
        {
            "name": "Clear internship with salary",
            "text": (
                "We are looking for an iOS intern to join our team. "
                "You will work with Swift and SwiftUI. "
                "1-2 years of experience preferred. "
                "This is a fully remote position. "
                "Compensation: $3,000/month stipend. "
                "We offer visa sponsorship for international candidates."
            ),
        },
        {
            "name": "Indian startup internship",
            "text": (
                "iOS Developer Intern at a funded B2B SaaS startup. "
                "Skills: Swift, Xcode, UIKit. "
                "Work from office in Bangalore (hybrid 3 days). "
                "Stipend: ₹25,000/month. "
                "Fresh graduates welcome. "
                "No prior experience required."
            ),
        },
        {
            "name": "Ambiguous senior-ish role",
            "text": (
                "Mobile iOS Developer. "
                "5+ years of experience in Swift and Objective-C. "
                "On-site only, New York. "
                "Cannot sponsor visas at this time."
            ),
        },
    ]

    for tc in test_cases:
        print(f"\n--- {tc['name']} ---")
        job = {
            "description_raw": tc["text"],
            "experience_req":  "",
            "remote":          "Unknown",
            "visa_sponsorship":"Unknown",
            "tech_stack":      "",
        }
        result = parse_job(job)
        print(f"  experience_req:  '{result['experience_req']}'")
        print(f"  remote:          '{result['remote']}'")
        print(f"  visa_sponsorship:'{result['visa_sponsorship']}'")
        print(f"  tech_stack:      '{result['tech_stack'][:60]}'")

    salary = extract_salary("Base salary: $90,000 - $120,000 per year")
    print(f"\nSalary extraction test: '{salary}'")