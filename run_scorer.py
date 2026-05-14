# ai/scorer.py
#
# PURPOSE:
#   Scores each job opportunity 0-100 using a 6-factor model.
#   Uses Groq's free Llama 3.1 API for AI evaluation.
#
# SCORING MODEL:
#   iOS relevance:          0, 15, or 30 pts  (Swift/SwiftUI + real iOS product)
#   Remote:                 0 or 20 pts       (remote/WFH confirmed)
#   Experience match:       0, 10, or 20 pts  (intern/0-1yr/entry level)
#   Product/company quality:0, 8, or 15 pts   (YC/funded startup, clear iOS product)
#   Salary:                 0 or 10 pts       (any compensation amount stated)
#   Visa:                   0 or 5 pts        (visa sponsorship mentioned)
#   Total possible:         100 pts
#
# RATE LIMIT HANDLING:
#   Groq free tier: 30 RPM. Scorer uses 3s delay between calls.
#   On 429 it backs off exponentially (10s → 30s → 60s) before retrying.
#
# FREE: Uses Groq API free tier.
#
# PLACEMENT: ai/scorer.py

import os
import sys
import json
import re
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from groq import Groq
from config.settings import GROQ_API_KEY, GROQ_MODEL, HIGH_SCORE_ALERT_THRESHOLD


SCORING_PROMPT = """You are an iOS internship opportunity scorer for a Computer Science student in India with 0 years of experience who knows Swift and SwiftUI.

Score this job 0-100 using these exact 6 criteria. Be strict — only award points for what is explicitly stated.

SCORING RULES:
- ios_relevance: 0, 15, or 30 pts
    30 = Swift AND SwiftUI explicitly mentioned AND company clearly builds a native iOS app
    15 = Swift OR iOS mentioned, or iOS product implied but not fully confirmed
    0  = no iOS/Swift signals at all

- remote: 0 or 20 pts
    20 = remote/WFH/distributed/fully remote explicitly confirmed
    0  = on-site only, hybrid, or not mentioned

- experience_match: 0, 10, or 20 pts
    20 = intern/internship/0-1 years/entry level/fresh graduate/no experience required
    10 = 1-2 years required
    0  = 3+ years required or no experience info and role sounds senior

- product_quality: 0, 8, or 15 pts
    15 = YC-backed OR Series A/B/C funded startup with a real iOS product
    8  = small startup or indie company, funding unclear, but has iOS product
    0  = large corporation, staffing agency, or no clear iOS product

- salary: 0 or 10 pts
    10 = any specific compensation/salary/stipend amount is stated (e.g. $50k, ₹8 LPA, $3000/month)
    0  = no salary or compensation amount mentioned

- visa: 0 or 5 pts
    5  = visa sponsorship explicitly mentioned as available
    0  = not mentioned, or explicitly no sponsorship

JOB DATA:
Company: {company}
Role: {role}
Location: {location}
Remote: {remote}
Visa Sponsorship: {visa}
Experience Required: {experience}
Tech Stack: {tech_stack}
Description: {description}
iOS Product Confirmed: {ios_product}

Respond ONLY with this exact JSON, no other text:
{{
"score": <integer 0-100, must equal sum of breakdown values>,
"breakdown": {{
    "ios_relevance": <0, 15, or 30>,
    "remote": <0 or 20>,
    "experience_match": <0, 10, or 20>,
    "product_quality": <0, 8, or 15>,
    "salary": <0 or 10>,
    "visa": <0 or 5>
}},
"summary": "<one sentence explaining the top factors>"
}}"""


# Valid point values per factor — used to clamp any hallucinated values
VALID_VALUES = {
    "ios_relevance":    {0, 15, 30},
    "remote":           {0, 20},
    "experience_match": {0, 10, 20},
    "product_quality":  {0, 8, 15},
    "salary":           {0, 10},
    "visa":             {0, 5},
}

EXPECTED_KEYS = list(VALID_VALUES.keys())


from storage.db_client import DBClient
from ai.scorer import OpportunityScorer


def score_unscored_jobs():
    """
    Fetches all unscored jobs from PostgreSQL,
    scores them with Groq,
    and updates the DB.
    """
    db = DBClient()
    print("\nFetching unscored jobs...")
    jobs = db.get_unscored_jobs()
    if not jobs:
        print("No unscored jobs found.")
        return
    print(f"Found {len(jobs)} unscored jobs.\n")
    scorer = OpportunityScorer()
    for i, job in enumerate(jobs):
        print(f"[{i+1}/{len(jobs)}] Scoring {job.get('company', '?')}...")
        result = scorer.score(job)
        db.update_score(
            job_id=job["id"],
            score=result["score"],
            breakdown=result["breakdown"],
            outreach_message=result.get("summary", "")
        )
    print(f"→ {result['score']}/100")
    time.sleep(3)
    print("\nScoring complete.")

# ─────────────────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    score_unscored_jobs()