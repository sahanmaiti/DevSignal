# ai/scorer.py
#
# PURPOSE:
#   Scores each job opportunity 0-100 using an 8-factor model.
#   Uses Groq's free Llama 3.1 API for AI evaluation.
#
# SCORING MODEL:
#   Remote available:          +20 pts
#   Visa sponsorship:          +15 pts
#   Swift/SwiftUI mentioned:   +15 pts
#   iOS product confirmed:     +15 pts
#   Experience 0-1 years:      +10 pts
#   Salary mentioned:          +10 pts
#   Funded startup:            +10 pts
#   Posted < 7 days ago:       +5  pts
#   Total possible:            100 pts
#
# FREE: Uses Groq API free tier.
#
# PLACEMENT: ai/scorer.py

import os
import sys
import json
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from groq import Groq
from config.settings import GROQ_API_KEY, GROQ_MODEL, HIGH_SCORE_ALERT_THRESHOLD


# The scoring prompt — structured to return consistent JSON every time.
# The example output section is critical: it shows the model exactly
# what format we expect. Without it, JSON structure varies between calls.
SCORING_PROMPT = """You are an iOS internship opportunity scorer for a Computer Science student in India with 0 years of experience who knows Swift and SwiftUI.

Score this job opportunity from 0 to 100 using these exact criteria:

SCORING RULES (assign points honestly based only on what is explicitly stated):
- remote_work: 0 or 20 pts — 20 if remote/WFH/distributed is confirmed, 0 if on-site only or unknown
- visa_sponsorship: 0 or 15 pts — 15 if visa sponsorship is explicitly mentioned, 0 otherwise
- swift_match: 0, 8, or 15 pts — 15 if Swift AND SwiftUI mentioned, 8 if only Swift/iOS, 0 if neither
- ios_product: 0 or 15 pts — 15 if company clearly builds a native iOS app, 0 if unclear or web-only
- experience_level: 0, 5, or 10 pts — 10 if 0-1 years or entry/intern/fresh grad, 5 if 1-2 years, 0 if 3+ years required
- salary_mentioned: 0 or 10 pts — 10 if any compensation/salary/stipend amount is stated, 0 if not mentioned
- startup_potential: 0, 5, or 10 pts — 10 if YC/funded/Series A-C startup with iOS product, 5 if small startup unclear stage, 0 if large corp or unknown
- recency: 0 or 5 pts — 5 if role was posted recently (within 7 days), 0 otherwise

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

Respond ONLY with this exact JSON structure, no other text:
{{
"score": <integer 0-100>,
"breakdown": {{
    "remote_work": <0 or 20>,
    "visa_sponsorship": <0 or 15>,
    "swift_match": <0, 8, or 15>,
    "ios_product": <0 or 15>,
    "experience_level": <0, 5, or 10>,
    "salary_mentioned": <0 or 10>,
    "startup_potential": <0, 5, or 10>,
    "recency": <0 or 5>
    }},
"summary": "<one sentence explaining the score>"
}}"""


class OpportunityScorer:
    """
    Scores iOS job opportunities using Groq's free Llama 3.1 API.

    Combines a heuristic pre-check (to avoid wasting API calls on
    obviously bad jobs) with an AI scoring pass for everything else.
    """

    def __init__(self):
        if not GROQ_API_KEY:
            raise ValueError(
                "GROQ_API_KEY not set in .env\n"
                "Get a free key at console.groq.com"
            )
        self.client = Groq(api_key=GROQ_API_KEY)
        self.model  = GROQ_MODEL

    def score(self, job: dict,
            ios_product: bool = None) -> dict:
        """
        Scores a single job dict.

        job:         normalized job dict from the database
        ios_product: result from IOSClassifier.classify() — True/False/None

        Returns:
        {
            "score": 74,
            "breakdown": {"remote_work": 20, "visa_sponsorship": 0, ...},
            "summary": "Strong remote iOS role but no visa info"
        }
        """
        # Build the prompt with all available job data
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
            print(f"[Scorer] Error for '{job.get('company', '?')}': {e}")
            # Return a neutral score so the job isn't lost
            return self._fallback_score(job)

    def _parse_score_response(self, raw: str) -> dict:
        """
        Parses the AI's JSON score response.
        Handles code blocks and minor formatting variations.
        """
        # Strip markdown code blocks
        if "```" in raw:
            parts = raw.split("```")
            raw = parts[1] if len(parts) > 1 else raw
            if raw.startswith("json\n"):
                raw = raw[5:]
        raw = raw.strip()

        try:
            data = json.loads(raw)

            score     = int(data.get("score", 0))
            breakdown = data.get("breakdown", {})
            summary   = str(data.get("summary", ""))[:300]

            # Validate score is in range
            score = max(0, min(100, score))

            # Validate breakdown sums roughly match the score
            # (small discrepancies are fine — the AI rounds)
            expected_keys = [
                "remote_work", "visa_sponsorship", "swift_match",
                "ios_product", "experience_level", "salary_mentioned",
                "startup_potential", "recency"
            ]
            clean_breakdown = {}
            for key in expected_keys:
                clean_breakdown[key] = int(breakdown.get(key, 0))

            calculated_score = sum(clean_breakdown.values())
            if abs(score - calculated_score) > 5:
                    score = calculated_score
            score = max(0, min(100, score))       

            return {
                "score":     score,
                "breakdown": clean_breakdown,
                "summary":   summary,
            }

        except (json.JSONDecodeError, ValueError, TypeError) as e:
            print(f"[Scorer] JSON parse error: {e}")
            print(f"[Scorer] Raw response was: {raw[:200]}")
            return self._fallback_score_from_raw(raw)

    def _fallback_score(self, job: dict) -> dict:
        """
        Rule-based score when the AI call fails completely.
        Ensures every job gets a score even if Groq is down.
        """
        score = 0
        breakdown = {
            "remote_work":       0,
            "visa_sponsorship":  0,
            "swift_match":       0,
            "ios_product":       0,
            "experience_level":  0,
            "salary_mentioned":  0,
            "startup_potential": 0,
            "recency":           0,
        }

        if job.get("remote") == "Yes":
            score += 20
            breakdown["remote_work"] = 20

        if job.get("visa_sponsorship") == "Yes":
            score += 15
            breakdown["visa_sponsorship"] = 15

        tech = (job.get("tech_stack", "") + job.get("description_raw", "")).lower()
        if "swiftui" in tech:
            score += 15
            breakdown["swift_match"] = 15
        elif "swift" in tech or "ios" in tech:
            score += 8
            breakdown["swift_match"] = 8

        exp = job.get("experience_req", "").lower()
        if any(e in exp for e in ["0-1", "entry", "intern", "fresh", "no experience"]):
            score += 10
            breakdown["experience_level"] = 10
        elif "1-2" in exp:
            score += 5
            breakdown["experience_level"] = 5

        return {
            "score":     score,
            "breakdown": breakdown,
            "summary":   "Scored by fallback rules (AI unavailable)",
        }

    def _fallback_score_from_raw(self, raw: str) -> dict:
        """Last resort when JSON parsing completely fails."""
        # Try to extract just the score number
        import re
        match = re.search(r'"score"\s*:\s*(\d+)', raw)
        score = int(match.group(1)) if match else 30  # default middle-low score
        return {
            "score":     score,
            "breakdown": {},
            "summary":   "Partial score — JSON parse failed",
        }

    def score_batch(self, jobs: list,
                    ios_results: dict = None,
                    delay_seconds: float = 2.0) -> list:
        """
        Scores a list of jobs with rate-limit-friendly delays.

        jobs:        list of job dicts
        ios_results: dict of {job_id: bool} from classifier
        delay_seconds: pause between API calls (2s = 30/min safe rate)

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

            score = result["score"]
            print(f"→ {score}/100")

            # Rate limiting — stay well under 30 RPM
            if i < total - 1:
                time.sleep(delay_seconds)

        return results


# ─────────────────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing Opportunity Scorer...")
    print("=" * 55)

    scorer = OpportunityScorer()

    test_jobs = [
        {
            "id": 1,
            "company": "nooro",
            "role": "iOS Developer Intern",
            "location": "Remote",
            "remote": "Yes",
            "visa_sponsorship": "Unknown",
            "experience_req": "0-1 years",
            "tech_stack": "swift, swiftui, xcode",
            "description_raw": (
                "We're building a health and wellness iOS app. "
                "Looking for a Swift intern to join our remote team. "
                "Compensation: $2,500/month stipend. "
                "Entry level, fresh graduates welcome."
            ),
        },
        {
            "id": 2,
            "company": "HN Anonymous Startup",
            "role": "iOS Engineer",
            "location": "San Francisco, CA",
            "remote": "No",
            "visa_sponsorship": "No",
            "experience_req": "3-5 years",
            "tech_stack": "swift, objc",
            "description_raw": (
                "On-site SF role. Must have 3-5 years iOS experience. "
                "No visa sponsorship. "
                "Series B funded startup."
            ),
        },
        {
            "id": 3,
            "company": "YC S24 Mobile Startup",
            "role": "Junior iOS Developer",
            "location": "Remote",
            "remote": "Yes",
            "visa_sponsorship": "Yes",
            "experience_req": "1-2 years",
            "tech_stack": "swift, swiftui, core data",
            "description_raw": (
                "YC S24 company building a B2B iOS productivity app. "
                "Remote first, we sponsor visas. "
                "Equity + $80,000-$100,000 salary. "
                "Looking for junior iOS developer with SwiftUI experience."
            ),
        },
    ]

    print()
    for job in test_jobs:
        print(f"Scoring: {job['company']} — {job['role']}")
        result = scorer.score(job, ios_product=True)
        print(f"  Score:     {result['score']}/100")
        print(f"  Summary:   {result['summary']}")
        print(f"  Breakdown: {result['breakdown']}")
        print()
        time.sleep(2)   # rate limit between test calls