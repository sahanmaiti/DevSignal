# ai/ios_classifier.py
#
# PURPOSE:
#   Determines whether a company builds a native iOS application.
#   Used as input to the scorer — iOS product = +15 points.
#
# HOW IT WORKS:
#   Sends company + role + description to Groq (Llama 3.1).
#   Parses the JSON response for a yes/no verdict + reason.
#
# FREE: Uses Groq API free tier — no cost.
#
# PLACEMENT: ai/ios_classifier.py

import os
import sys
import json
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from groq import Groq
from config.settings import GROQ_API_KEY, GROQ_MODEL


# The classification prompt.
# Written to be concise — shorter prompts use fewer tokens = more free quota.
CLASSIFIER_PROMPT = """You are classifying whether a company builds a native iOS app.

Company: {company}
Role: {role}
Description: {description}

Does this company build a native iOS application (Swift/Objective-C, not just a mobile website or React Native wrapper)?

Respond ONLY with valid JSON, nothing else:
{{"builds_ios": true/false, "reason": "one sentence explanation"}}"""


class IOSClassifier:
    """
    Classifies whether a company builds a native iOS product.
    Uses Groq's free Llama 3.1 API.
    """

    def __init__(self):
        if not GROQ_API_KEY:
            raise ValueError(
                "GROQ_API_KEY not set in .env\n"
                "Get a free key at console.groq.com"
            )
        self.client = Groq(api_key=GROQ_API_KEY)
        self.model  = GROQ_MODEL

    def classify(self, job: dict) -> dict:
        """
        Classifies a single job dict.

        Returns:
            {
                "builds_ios": True/False,
                "reason": "one sentence explanation"
            }

        On any failure, returns {"builds_ios": None, "reason": "classification failed"}
        so the scorer can treat it as unknown without crashing.
        """
        company     = job.get("company", "")[:100]
        role        = job.get("role", "")[:100]
        description = job.get("description_raw", "")[:400]

        # Quick heuristic check first — if description mentions Swift/SwiftUI
        # explicitly, we can classify without an API call (saves quota)
        heuristic = self._heuristic_classify(
            company, role, description, job.get("tech_stack", "")
        )
        if heuristic is not None:
            return heuristic

        # Otherwise, ask the AI
        prompt = CLASSIFIER_PROMPT.format(
            company=company,
            role=role,
            description=description,
        )

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0,       # deterministic — same job = same answer
                max_tokens=100,      # we only need a tiny JSON response
            )

            raw = response.choices[0].message.content.strip()
            return self._parse_response(raw)

        except Exception as e:
            print(f"[Classifier] Error for '{company}': {e}")
            return {"builds_ios": None, "reason": f"classification failed: {e}"}

    def _heuristic_classify(self, company: str, role: str,
                            description: str, tech_stack: str) -> dict | None:
        """
        Fast rule-based classification that avoids an API call.
        Returns a result dict if confident, None if unsure (triggers AI).
        """
        combined = (company + " " + role + " " + description + " " + tech_stack).lower()

        # Strong iOS signals — confidently True
        strong_ios = ["swift", "swiftui", "uikit", "objective-c",
                    "xcode", "ios sdk", "core data", "arkit"]
        for signal in strong_ios:
            if signal in combined:
                return {
                    "builds_ios": True,
                    "reason": f"Job explicitly mentions {signal}"
                }

        # Strong non-iOS signals — confidently False
        non_ios = ["react native", "flutter", "android only",
                "web developer", "backend engineer", "data scientist",
                "machine learning engineer", "devops", "frontend react"]
        for signal in non_ios:
            if signal in combined and "ios" not in combined:
                return {
                    "builds_ios": False,
                    "reason": f"Role appears to be {signal}, not iOS native"
                }

        # Unsure — let the AI decide
        return None

    def _parse_response(self, raw: str) -> dict:
        """
        Parses the AI's JSON response.
        Handles common formatting issues (code blocks, extra whitespace).
        """
        # Strip markdown code blocks if the model wrapped the JSON
        if "```" in raw:
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        raw = raw.strip()

        try:
            data = json.loads(raw)
            return {
                "builds_ios": bool(data.get("builds_ios", False)),
                "reason":     str(data.get("reason", ""))[:200],
            }
        except json.JSONDecodeError:
            # AI returned something that isn't valid JSON
            # Make a best-effort interpretation
            raw_lower = raw.lower()
            if "true" in raw_lower or "yes" in raw_lower:
                return {"builds_ios": True, "reason": "AI responded affirmatively"}
            return {"builds_ios": False, "reason": "Could not parse AI response"}

    def classify_batch(self, jobs: list,
                    delay_seconds: float = 0.5) -> list:
        """
        Classifies a list of jobs with a small delay between calls
        to respect Groq's 30 RPM rate limit.

        Returns list of (job, classification_result) tuples.
        """
        results = []
        for i, job in enumerate(jobs):
            result = self.classify(job)
            results.append((job, result))

            # Progress indicator
            company = job.get("company", "?")[:25]
            verdict = "iOS" if result.get("builds_ios") else "not iOS"
            print(f"  [{i+1}/{len(jobs)}] {company:<25} → {verdict}")

            # Rate limiting — Groq free tier: 30 RPM
            if i < len(jobs) - 1:
                time.sleep(delay_seconds)

        return results


# ─────────────────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing iOS Classifier...")
    print("=" * 55)

    classifier = IOSClassifier()

    test_jobs = [
        {
            "company": "Mercury",
            "role": "iOS Swift Developer",
            "description_raw": "Building the Mercury banking app for iPhone using Swift and SwiftUI.",
            "tech_stack": "swift, swiftui",
        },
        {
            "company": "Some Web Agency",
            "role": "Mobile Developer",
            "description_raw": "Building responsive web apps. Some mobile work. React and Node.js.",
            "tech_stack": "react, nodejs",
        },
        {
            "company": "FitTrack",
            "role": "iOS Intern",
            "description_raw": "We build health and fitness tracking apps for iPhone. You will work on our main app.",
            "tech_stack": "ios, mobile",
        },
    ]

    print()
    for job in test_jobs:
        result = classifier.classify(job)
        verdict = "Builds iOS" if result["builds_ios"] else "Does NOT build iOS"
        print(f"  {job['company']}: {verdict}")
        print(f"  Reason: {result['reason']}")
        print()