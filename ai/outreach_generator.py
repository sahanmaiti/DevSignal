# ai/outreach_generator.py
#
# PURPOSE:
#   Generates a personalized recruiter outreach message for each
#   high-scoring job opportunity.
#
# DESIGN:
#   - Only generates for jobs scoring >= 65 (no wasted API calls)
#   - Message is < 300 chars — fits in a LinkedIn connection request
#   - References the specific company's iOS product
#   - Mentions your real projects (expense tracker, weather app)
#   - Casual tone — doesn't sound like a template
#
# FREE: Uses Groq API free tier.
#
# PLACEMENT: ai/outreach_generator.py

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from groq import Groq
from config.settings import GROQ_API_KEY, GROQ_MODEL


OUTREACH_PROMPT = """Write a short LinkedIn connection request message (under 280 characters) from a CS student seeking an iOS internship.

About the student:
- CS student, 0 years experience
- Skills: Swift, SwiftUI, REST APIs
- Built: expense tracker app, weather app (both SwiftUI)
- Seeking iOS internship, open to remote

About the opportunity:
- Company: {company}
- Role: {role}
- iOS Product: {ios_product_desc}
- Remote: {remote}
- Recruiter name: {recruiter_name}

Requirements:
- If recruiter name is provided, start with "Hi [FirstName],"
- Sound like a real human, not a template
- Mention ONE specific thing about their iOS product or tech stack
- End with a soft ask (not "Can I have a job?")
- Under 280 characters total
- No subject line unless it's a LinkedIn message

Return ONLY the message text, nothing else."""


class OutreachGenerator:
    """
    Generates personalized recruiter outreach messages.
    Only runs for jobs above the score threshold to save API quota.
    """

    def __init__(self, min_score: int = 65):
        if not GROQ_API_KEY:
            raise ValueError("GROQ_API_KEY not set in .env")
        self.client    = Groq(api_key=GROQ_API_KEY)
        self.model     = GROQ_MODEL
        self.min_score = min_score

    def generate(self, job: dict,
                ios_product_desc: str = "",
                score: int = 0) -> str:
        """
        Generates an outreach message for a single job.

        Returns the message string, or "" if below score threshold
        or if generation fails.
        """
        if score < self.min_score:
            return ""

        prompt = OUTREACH_PROMPT.format(
            company          = job.get("company", "the company")[:60],
            role             = job.get("role", "iOS role")[:60],
            ios_product_desc = ios_product_desc[:150] if ios_product_desc
                            else "their iOS application",
            remote           = job.get("remote", "Unknown"),
            recruiter_name   = job.get("recruiter_name", "") or "Not known",
        )

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7,     # slight creativity — messages shouldn't be identical
                max_tokens=150,
            )
            message = response.choices[0].message.content.strip()

            # Remove any quotes the model may have added
            message = message.strip('"').strip("'")

            # Enforce length limit
            if len(message) > 197:
                message = message[:297] + "..."

            return message

        except Exception as e:
            print(f"[Outreach] Error for '{job.get('company', '?')}': {e}")
            return ""

    def generate_batch(self, scored_jobs: list,
                    ios_descriptions: dict = None,
                    delay_seconds: float = 2.0) -> dict:
        """
        Generates outreach messages for a list of scored jobs.

        scored_jobs:      list of (job, score_result) tuples
        ios_descriptions: dict of {job_id: ios_product_description}

        Returns dict of {job_id: outreach_message}
        """
        results = {}
        ios_descriptions = ios_descriptions or {}

        eligible = [(job, res) for job, res in scored_jobs
                    if res.get("score", 0) >= self.min_score]

        print(f"\n[Outreach] Generating messages for {len(eligible)} jobs "
            f"(score >= {self.min_score})...")

        for i, (job, score_result) in enumerate(eligible):
            job_id  = job.get("id")
            score   = score_result.get("score", 0)
            ios_desc = ios_descriptions.get(job_id, "")

            print(f"  [{i+1}/{len(eligible)}] {job.get('company', '?')[:30]}...",
                end=" ")

            message = self.generate(job, ios_product_desc=ios_desc, score=score)
            results[job_id] = message

            if message:
                print(f"✓ ({len(message)} chars)")
            else:
                print("skipped")

            if i < len(eligible) - 1:
                time.sleep(delay_seconds)

        return results


# ─────────────────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing Outreach Generator...")
    print("=" * 55)

    generator = OutreachGenerator(min_score=60)

    test_cases = [
        {
            "job": {
                "id": 1,
                "company": "nooro",
                "role": "iOS Developer Intern",
                "remote": "Yes",
            },
            "ios_desc": "a health and wellness iOS app focused on sleep tracking",
            "score": 68,
        },
        {
            "job": {
                "id": 2,
                "company": "YC Startup",
                "role": "Junior iOS Developer",
                "remote": "Yes",
            },
            "ios_desc": "a B2B productivity iOS app for field service teams",
            "score": 90,
        },
        {
            "job": {
                "id": 3,
                "company": "Low Score Co",
                "role": "iOS Dev",
                "remote": "No",
            },
            "ios_desc": "",
            "score": 40,   # below threshold — should return ""
        },
    ]

    for tc in test_cases:
        job   = tc["job"]
        score = tc["score"]
        print(f"\n{job['company']} (score: {score}):")

        msg = generator.generate(
            job=job,
            ios_product_desc=tc["ios_desc"],
            score=score,
        )

        if msg:
            print(f'  "{msg}"')
            print(f"  Length: {len(msg)} chars")
        else:
            print("  Skipped (below threshold)")

        if score >= 60:
            time.sleep(2)   # rate limit