# processors/hunter_client.py
#
# PURPOSE:
#   Queries Hunter.io's free API to find email patterns and
#   recruiter contacts for a company domain.
#
# FREE TIER LIMITS:
#   25 domain searches/month
#   25 email finder requests/month
#
# QUOTA STRATEGY:
#   - Only call for jobs scoring >= ENRICHMENT_MIN_SCORE (default 70)
#   - Cache results per domain (one call covers multiple jobs at same company)
#   - Track usage count so we never accidentally exceed the limit
#
# PLACEMENT: processors/hunter_client.py

import os
import sys
import json
import requests
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import HUNTER_API_KEY

HUNTER_BASE_URL = "https://api.hunter.io/v2"

# Local cache file — avoids re-querying the same domain twice
# Stored in project root, gitignored
CACHE_FILE = Path(__file__).parent.parent / ".hunter_cache.json"


class HunterClient:
    """
    Wraps Hunter.io's domain search API with caching and quota tracking.
    """

    def __init__(self):
        self.api_key = HUNTER_API_KEY
        self.enabled = bool(self.api_key)
        self._cache  = self._load_cache()

        if not self.enabled:
            print("[Hunter] No API key configured — email enrichment disabled.")
            print("[Hunter] Add HUNTER_API_KEY to .env to enable.")

    def search_domain(self, domain: str) -> dict:
        """
        Searches Hunter.io for all known email addresses at a domain.

        Returns a dict with:
        {
            "pattern":    "{first}.{last}@stripe.com",
            "emails":     [...list of contact dicts...],
            "recruiter":  {best recruiter contact or None},
        }

        Returns empty dict on failure or if Hunter is not configured.
        """
        if not self.enabled:
            return {}

        if not domain:
            return {}

        # Check cache first — don't waste quota on repeated lookups
        if domain in self._cache:
            print(f"[Hunter] Using cached result for {domain}")
            return self._cache[domain]

        print(f"[Hunter] Querying {domain}...")

        try:
            response = requests.get(
                f"{HUNTER_BASE_URL}/domain-search",
                params={
                    "domain":  domain,
                    "api_key": self.api_key,
                    "limit":   10,         # max contacts to return
                    "type":    "personal", # skip generic info@ addresses
                },
                timeout=15,
            )

            if response.status_code == 401:
                print("[Hunter] Invalid API key.")
                return {}

            if response.status_code == 429:
                print("[Hunter] Rate limit or monthly quota exceeded.")
                return {}

            if response.status_code != 200:
                print(f"[Hunter] API error {response.status_code}")
                return {}

            data = response.json().get("data", {})
            result = self._parse_response(data, domain)

            # Cache the result
            self._cache[domain] = result
            self._save_cache()

            return result

        except requests.exceptions.RequestException as e:
            print(f"[Hunter] Request failed: {e}")
            return {}

    def _parse_response(self, data: dict, domain: str) -> dict:
        """
        Parses the Hunter.io domain search response into our standard format.
        Identifies the best recruiter contact from the results.
        """
        pattern = data.get("pattern", "")
        if pattern:
            # Add the domain to get a full template
            # e.g. "{first}.{last}" → "{first}.{last}@stripe.com"
            pattern = f"{pattern}@{domain}" if "@" not in pattern else pattern

        emails_raw = data.get("emails", [])

        # Parse each contact
        contacts = []
        for e in emails_raw:
            contact = {
                "email":      e.get("value", ""),
                "first_name": e.get("first_name", ""),
                "last_name":  e.get("last_name", ""),
                "position":   e.get("position", ""),
                "linkedin":   e.get("linkedin", ""),
                "confidence": e.get("confidence", 0),
            }
            contacts.append(contact)

        # Find the best recruiter contact
        recruiter = self._find_best_recruiter(contacts)

        return {
            "pattern":   pattern,
            "emails":    contacts,
            "recruiter": recruiter,
        }

    def _find_best_recruiter(self, contacts: list) -> dict | None:
        """
        Picks the most relevant contact from a list.
        Prioritises: recruiters > engineering managers > iOS engineers > anyone.
        """
        if not contacts:
            return None

        # Scoring function for contact relevance
        def contact_score(c: dict) -> int:
            title = (c.get("position") or "").lower()
            score = 0
            if any(t in title for t in ["recruit", "talent", "hr", "people"]):
                score += 30
            if any(t in title for t in ["engineering manager", "eng manager", "em "]):
                score += 25
            if any(t in title for t in ["ios", "swift", "mobile"]):
                score += 20
            if any(t in title for t in ["head of", "director", "vp", "chief"]):
                score += 10
            if c.get("linkedin"):
                score += 5
            score += min(c.get("confidence", 0) // 10, 10)
            return score

        sorted_contacts = sorted(contacts, key=contact_score, reverse=True)
        best = sorted_contacts[0]

        # Only return if we have at least a name
        if not best.get("first_name") and not best.get("email"):
            return None

        return best

    def construct_email(self, pattern: str,
                        first_name: str, last_name: str) -> str:
        """
        Given an email pattern and a person's name, constructs their likely email.

        "{first}.{last}@stripe.com" + "John" + "Doe" → "john.doe@stripe.com"
        "{first}@stripe.com"        + "John" + "Doe" → "john@stripe.com"
        """
        if not pattern or not first_name:
            return ""

        email = pattern.lower()
        email = email.replace("{first}", first_name.lower())
        email = email.replace("{last}",  last_name.lower() if last_name else "")
        email = email.replace("{f}",     first_name[0].lower() if first_name else "")

        # Clean up any double dots or trailing dots before @
        parts = email.split("@")
        if len(parts) == 2:
            local = parts[0].strip(".")
            local = re.sub(r'\.+', '.', local)
            email = f"{local}@{parts[1]}"

        return email

    def get_remaining_quota(self) -> dict:
        """
        Checks how many Hunter.io requests remain this month.
        Useful for monitoring before running large enrichment batches.
        """
        if not self.enabled:
            return {"searches": 0, "verifications": 0}

        try:
            response = requests.get(
                f"{HUNTER_BASE_URL}/account",
                params={"api_key": self.api_key},
                timeout=10,
            )
            if response.status_code == 200:
                data = response.json().get("data", {})
                requests_data = data.get("requests", {})
                return {
                    "searches": requests_data.get(
                        "searches", {}
                    ).get("available", 0),
                    "verifications": requests_data.get(
                        "verifications", {}
                    ).get("available", 0),
                }
        except Exception:
            pass
        return {"searches": 0, "verifications": 0}

    def _load_cache(self) -> dict:
        """Loads the domain result cache from disk."""
        try:
            if CACHE_FILE.exists():
                with open(CACHE_FILE) as f:
                    return json.load(f)
        except Exception:
            pass
        return {}

    def _save_cache(self):
        """Saves the domain result cache to disk."""
        try:
            with open(CACHE_FILE, "w") as f:
                json.dump(self._cache, f, indent=2)
        except Exception:
            pass


import re   # needed by construct_email


# ─────────────────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing Hunter.io client...")
    print("=" * 55)

    client = HunterClient()

    if not client.enabled:
        print("\nHunter API key not configured.")
        print("Add HUNTER_API_KEY to .env to test.")
    else:
        # Check quota before testing
        quota = client.get_remaining_quota()
        print(f"\nRemaining quota: {quota['searches']} searches, "
            f"{quota['verifications']} verifications")

        # Test with a well-known company that Hunter knows about
        print("\nSearching stripe.com...")
        result = client.search_domain("stripe.com")

        if result:
            print(f"Email pattern: {result.get('pattern', 'not found')}")
            recruiter = result.get("recruiter")
            if recruiter:
                print(f"Best contact:  {recruiter.get('first_name')} "
                    f"{recruiter.get('last_name')}")
                print(f"Position:      {recruiter.get('position', 'unknown')}")
                print(f"Email:         {recruiter.get('email', 'not available')}")
                print(f"LinkedIn:      {recruiter.get('linkedin', 'not available')}")
            else:
                print("No contacts found for this domain")
        else:
            print("No results returned")

        # Test email construction
        pattern = "{first}.{last}@stripe.com"
        email   = client.construct_email(pattern, "John", "Doe")
        print(f"\nEmail construction test: {email}")
        assert email == "john.doe@stripe.com", f"Expected john.doe@stripe.com, got {email}"
        print("Email construction: OK")