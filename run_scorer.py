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


class OpportunityScorer:
    """
    Scores iOS job opportunities using Groq's free Llama 3.1 API.
    Handles rate limiting with exponential backoff.
    """

    def __init__(self):
        if not GROQ_API_KEY:
            raise ValueError(
                "GROQ_API_KEY not set in .env\n"
                "Get a free key at console.groq.com"
            )
        self.client = Groq(api_key=GROQ_API_KEY)
        self.model  = GROQ_MODEL

    def score(self, job: dict, ios_product: bool = None) -> dict:
        """
        Scores a single job dict with automatic 429 retry.

        Returns:
        {
            "score": 74,
            "breakdown": {"ios_relevance": 30, "remote": 20, ...},
            "summary": "Strong remote iOS role..."
        }
        """
        prompt = SCORING_PROMPT.format(
            company     = job.get("company", "Unknown")[:80],
            role        = job.get("role", "Unknown")[:80],
            location    = job.get("location", "Unknown")[:60],
            remote      = job.get("remote", "Unknown"),
            visa        = job.get("visa_sponsorship", "Unknown"),
            experience  = job.get("experience_req", "Not specified"),
            tech_stack  = job.get("tech_stack", "Not specified")[:100],
            description = job.get("description_raw", "")[:500],
            ios_product = "Yes" if ios_product is True
                        else "No" if ios_product is False
                        else "Unknown",
        )

        # Retry up to 3 times on 429, with increasing backoff
        backoff_seconds = [10, 30, 60]

        for attempt, wait in enumerate(backoff_seconds + [None]):
            try:
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0,
                    max_tokens=300,
                )
                raw = response.choices[0].message.content.strip()
                return self._parse_score_response(raw)

            except Exception as e:
                err = str(e)
                if "429" in err and wait is not None:
                    print(f"\n[Scorer] Rate limited (429). Waiting {wait}s before retry {attempt + 1}/3...")
                    time.sleep(wait)
                    continue
                # Non-429 error or final attempt exhausted
                print(f"[Scorer] Error for '{job.get('company', '?')}': {e}")
                return self._fallback_score(job)

        # Should not reach here, but safety net
        return self._fallback_score(job)

    def _parse_score_response(self, raw: str) -> dict:
        """
        Parses the AI's JSON response.
        - Strips markdown fences
        - Clamps each factor to its valid set of values
        - Recomputes score as breakdown sum (ignores model's self-reported total)
        """
        text = raw.strip()
        text = re.sub(r'^```(?:json)?\s*', '', text, flags=re.IGNORECASE)
        text = re.sub(r'\s*```\s*$', '', text)
        text = text.strip()

        try:
            data = json.loads(text)

            breakdown_raw = data.get("breakdown", {})
            summary       = str(data.get("summary", ""))[:300]

            # Clamp each factor to its valid point values
            # If the model returns an invalid value (e.g. 12 for ios_relevance),
            # round down to the nearest valid value
            clean_breakdown = {}
            for key in EXPECTED_KEYS:
                raw_val   = int(breakdown_raw.get(key, 0))
                valid_set = VALID_VALUES[key]
                # Pick the largest valid value that doesn't exceed raw_val
                clamped   = max((v for v in valid_set if v <= raw_val), default=0)
                clean_breakdown[key] = clamped

            # Score is always the sum — never trust the model's self-reported total
            score = sum(clean_breakdown.values())
            score = max(0, min(100, score))

            return {
                "score":     score,
                "breakdown": clean_breakdown,
                "summary":   summary,
            }

        except (json.JSONDecodeError, ValueError, TypeError) as e:
            print(f"[Scorer] JSON parse error: {e} | Raw: {raw[:150]}")
            return self._fallback_score_from_raw(raw)

    def _fallback_score(self, job: dict) -> dict:
        """
        Rule-based score when the AI call fails completely.
        Uses the same 6-factor model so breakdowns are consistent.
        """
        breakdown = {k: 0 for k in EXPECTED_KEYS}
        score = 0

        # iOS relevance
        tech = (job.get("tech_stack", "") + " " + job.get("description_raw", "")).lower()
        if "swiftui" in tech and ("ios" in tech or "iphone" in tech):
            breakdown["ios_relevance"] = 30
        elif "swift" in tech or "ios" in tech or "uikit" in tech:
            breakdown["ios_relevance"] = 15
        score += breakdown["ios_relevance"]

        # Remote
        if job.get("remote", "").lower() in ("yes", "remote"):
            breakdown["remote"] = 20
            score += 20

        # Experience match
        exp = job.get("experience_req", "").lower()
        if any(e in exp for e in ["0-1", "entry", "intern", "fresh", "no experience"]):
            breakdown["experience_match"] = 20
            score += 20
        elif "1-2" in exp:
            breakdown["experience_match"] = 10
            score += 10

        # Salary
        desc = job.get("description_raw", "")
        if re.search(r'(\$[\d,]+|\d+\s*lpa|₹[\d,]+|stipend\s*:?\s*[\d,]+)', desc, re.I):
            breakdown["salary"] = 10
            score += 10

        # Visa
        if job.get("visa_sponsorship", "").lower() == "yes":
            breakdown["visa"] = 5
            score += 5

        return {
            "score":     min(score, 100),
            "breakdown": breakdown,
            "summary":   "Scored by fallback rules (AI unavailable)",
        }

    def _fallback_score_from_raw(self, raw: str) -> dict:
        """Last resort when JSON parsing completely fails."""
        match = re.search(r'"score"\s*:\s*(\d+)', raw)
        score = int(match.group(1)) if match else 25
        return {
            "score":     min(max(score, 0), 100),
            "breakdown": {k: 0 for k in EXPECTED_KEYS},
            "summary":   "Partial score — JSON parse failed",
        }

    def score_batch(self, jobs: list,
                    ios_results: dict = None,
                    delay_seconds: float = 3.0) -> list:
        """
        Scores a list of jobs with 3s delay between calls (safe under 30 RPM).

        jobs:          list of job dicts
        ios_results:   dict of {job_id: bool} from classifier
        delay_seconds: pause between API calls

        Returns list of (job, score_result) tuples.
        """
        results = []
        total   = len(jobs)

        for i, job in enumerate(jobs):
            job_id      = job.get("id")
            ios_product = ios_results.get(job_id) if ios_results else None

            print(f"  Scoring [{i+1}/{total}] {job.get('company', '?')[:30]}...", end=" ")

            result = self.score(job, ios_product=ios_product)
            results.append((job, result))

            print(f"→ {result['score']}/100")

            if i < total - 1:
                time.sleep(delay_seconds)

        return results


from storage.db_client import DBClient


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