# processors/enricher.py
#
# PURPOSE:
#   Orchestrates the full enrichment pipeline for a job.
#   Combines: domain finder → Hunter.io → LinkedIn finder → AI fallback
#
# QUOTA STRATEGY:
#   Hunter.io (25/month): only for jobs scoring >= ENRICHMENT_MIN_SCORE
#   Serper (100/month after initial):  only for jobs scoring >= ENRICHMENT_MIN_SCORE
#   Groq (free): AI fallback for lower-scored jobs
#
# PLACEMENT: processors/enricher.py

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from processors.domain_finder   import find_domain, extract_email_from_text
from processors.hunter_client   import HunterClient
from processors.linkedin_finder import LinkedInFinder
from storage.db_client          import db
from config.settings            import ENRICHMENT_MIN_SCORE, GROQ_API_KEY


class Enricher:
    """
    Enriches job records with recruiter contact information.

    For each job, attempts to find:
    - recruiter_name
    - recruiter_role
    - linkedin_profile URL
    - email address or email pattern
    """

    def __init__(self):
        self.hunter   = HunterClient()
        self.linkedin = LinkedInFinder()

    def enrich(self, job: dict) -> dict:
        """
        Runs the full enrichment pipeline for a single job.

        Returns an enrichment dict:
        {
            "recruiter_name":    "Jane Smith",
            "recruiter_role":    "iOS Engineering Manager",
            "linkedin_profile":  "https://linkedin.com/in/janesmith",
            "email":             "jane.smith@stripe.com",
            "enrichment_source": "hunter+linkedin",
        }
        Empty strings for any field we couldn't find.
        """
        result = {
            "recruiter_name":    "",
            "recruiter_role":    "",
            "linkedin_profile":  "",
            "email":             "",
            "enrichment_source": "",
        }

        company     = job.get("company", "")
        score       = job.get("opportunity_score") or 0
        description = job.get("description_raw", "")

        # ── Layer 1: Extract from existing data (always runs) ─────────────

        # Check if description has a direct email
        direct_email = extract_email_from_text(description)
        if direct_email:
            result["email"]             = direct_email
            result["enrichment_source"] = "description"

        # ── Layer 2: Hunter.io (only for high-scoring jobs) ───────────────

        if score >= ENRICHMENT_MIN_SCORE and self.hunter.enabled:
            domain = find_domain(job)

            if domain:
                hunter_result = self.hunter.search_domain(domain)

                if hunter_result:
                    recruiter = hunter_result.get("recruiter")
                    pattern   = hunter_result.get("pattern", "")

                    if recruiter:
                        fname = recruiter.get("first_name", "")
                        lname = recruiter.get("last_name", "")

                        result["recruiter_name"] = (
                            f"{fname} {lname}".strip() or ""
                        )
                        result["recruiter_role"] = recruiter.get("position", "")
                        result["linkedin_profile"] = recruiter.get("linkedin", "")

                        # Use direct email if available, otherwise construct from pattern
                        if recruiter.get("email"):
                            result["email"] = recruiter["email"]
                        elif pattern and fname:
                            result["email"] = self.hunter.construct_email(
                                pattern, fname, lname
                            )

                        result["enrichment_source"] = "hunter"

        # ── Layer 3: LinkedIn search (for high-scoring jobs missing recruiter) ─

        if (score >= ENRICHMENT_MIN_SCORE
                and self.linkedin.enabled
                and not result["linkedin_profile"]):

            li_result = self.linkedin.find_recruiter(company, job.get("role", ""))

            if li_result:
                if not result["recruiter_name"]:
                    result["recruiter_name"] = li_result.get("name", "")
                if not result["recruiter_role"]:
                    result["recruiter_role"] = li_result.get("title", "")
                result["linkedin_profile"] = li_result.get("linkedin", "")

                if result["enrichment_source"]:
                    result["enrichment_source"] += "+linkedin"
                else:
                    result["enrichment_source"] = "linkedin"

        # ── Layer 4: AI fallback (for any job with no recruiter found) ────

        if not result["recruiter_name"] and GROQ_API_KEY:
            ai_result = self._ai_guess_recruiter(job)
            if ai_result:
                result["recruiter_role"]    = ai_result.get("likely_title", "")
                result["enrichment_source"] = "ai_guess"

        return result

    def _ai_guess_recruiter(self, job: dict) -> dict:
        """
        Uses Groq to suggest the most likely recruiter title to search for.
        Returns a dict with 'likely_title' — no real contact data.
        """
        try:
            from groq import Groq
            from config.settings import GROQ_MODEL

            client = Groq(api_key=GROQ_API_KEY)
            prompt = (
                f"For a {job.get('role', 'iOS role')} at {job.get('company', 'a startup')}, "
                f"what is the most likely job title of the person who would review "
                f"internship applications? Reply with just the title, 4 words max."
            )

            resp = client.chat.completions.create(
                model=GROQ_MODEL,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=20,
                temperature=0,
            )
            title = resp.choices[0].message.content.strip().strip('"')
            return {"likely_title": title}

        except Exception:
            return {}

    def enrich_batch(self, jobs: list,
                     delay_seconds: float = 1.0) -> list:
        """
        Enriches a list of jobs and writes results to the database.

        Returns list of (job, enrichment_result) tuples.
        """
        results       = []
        enriched_count = 0
        skipped_count  = 0

        for i, job in enumerate(jobs):
            job_id  = job.get("id")
            company = job.get("company", "?")[:30]
            score   = job.get("opportunity_score") or 0

            print(f"  [{i+1}/{len(jobs)}] {company:<30} (score: {score})", end=" ")

            enrichment = self.enrich(job)

            # Only write to DB if we found something
            has_data = any([
                enrichment["recruiter_name"],
                enrichment["email"],
                enrichment["linkedin_profile"],
            ])

            if has_data:
                db.update_recruiter(
                    job_id=job_id,
                    recruiter_name=enrichment["recruiter_name"],
                    recruiter_role=enrichment["recruiter_role"],
                    linkedin_profile=enrichment["linkedin_profile"],
                    email=enrichment["email"],
                )
                source = enrichment["enrichment_source"]
                print(f"→ enriched ({source})")
                enriched_count += 1
            else:
                print("→ no data found")
                skipped_count += 1

            results.append((job, enrichment))

            if i < len(jobs) - 1:
                time.sleep(delay_seconds)

        print(f"\n[Enricher] Complete: {enriched_count} enriched, "
            f"{skipped_count} no data found")
        return results