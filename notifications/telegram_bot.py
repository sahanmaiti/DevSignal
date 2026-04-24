# notifications/telegram_bot.py
#
# PURPOSE:
#   Sends formatted Telegram messages for the DevSignal pipeline.
#   Three message types: digest (top jobs), summary (run stats), alert (high score).
#
# DESIGN:
#   - Never crashes the pipeline. All Telegram errors are caught and logged.
#   - Retries once on network failure before giving up.
#   - Uses HTML parse mode (simpler than MarkdownV2 escaping rules).
#   - Long messages are automatically split to stay under Telegram's 4096 char limit.
#
# USAGE:
#   from notifications.telegram_bot import TelegramBot
#   bot = TelegramBot()
#   bot.send_digest(top_jobs)
#   bot.send_run_summary(jobs_found=70, jobs_new=44, jobs_stored=44)
#
# PLACEMENT: notifications/telegram_bot.py

import os
import sys
import time
import requests

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

# Telegram's max message length
MAX_MESSAGE_LENGTH = 4096


class TelegramBot:
    """
    Sends DevSignal notifications to a Telegram chat.

    All public methods are safe to call even if Telegram credentials
    are not configured — they'll log a warning and return False instead
    of crashing the pipeline.
    """

    def __init__(self):
        self.token   = TELEGRAM_BOT_TOKEN
        self.chat_id = TELEGRAM_CHAT_ID
        self.base_url = f"https://api.telegram.org/bot{self.token}"
        self._configured = bool(self.token and self.chat_id)

        if not self._configured:
            print("[Telegram] WARNING: BOT_TOKEN or CHAT_ID not set in .env")
            print("[Telegram] Notifications are disabled until credentials are added.")

    # ─────────────────────────────────────────────────────────────────────
    # PUBLIC METHODS — call these from run_scraper.py
    # ─────────────────────────────────────────────────────────────────────

    def send_digest(self, jobs: list) -> bool:
        """
        Sends the main job digest — top 5 opportunities from the latest run.

        jobs: list of job dicts from db_client.get_top_opportunities()
            or the new_jobs list from run_scraper.py

        Returns True if sent successfully, False otherwise.
        """
        if not self._configured:
            return False

        if not jobs:
            return self._send(self._format_no_jobs_message())

        message = self._format_digest(jobs)
        return self._send(message)

    def send_run_summary(self, jobs_found: int, jobs_filtered: int,
                        jobs_new: int, jobs_stored: int,
                        sources: dict = None) -> bool:
        """
        Sends a compact run statistics message.

        sources: dict of {source_name: count} e.g. {"HackerNews": 54, "Remotive": 1}
        """
        if not self._configured:
            return False

        message = self._format_run_summary(
            jobs_found, jobs_filtered, jobs_new, jobs_stored, sources
        )
        return self._send(message)

    def send_high_score_alert(self, job: dict) -> bool:
        """
        Sends an immediate alert for a single high-scoring job (score >= 85).
        Called from ai/scorer.py in Phase 5.
        """
        if not self._configured:
            return False

        message = self._format_high_score_alert(job)
        return self._send(message)

    def send_error_alert(self, error_message: str) -> bool:
        """
        Sends a pipeline error notification.
        Called from run_scraper.py exception handler.
        """
        if not self._configured:
            return False

        text = (
            f"<b>DevSignal — Pipeline Error</b>\n\n"
            f"<code>{self._escape_html(error_message[:500])}</code>\n\n"
            f"Check your terminal for the full traceback."
        )
        return self._send(text)

    def test_connection(self) -> bool:
        """
        Sends a simple test message to verify the bot is working.
        Call this during setup to confirm credentials are correct.
        """
        if not self._configured:
            print("[Telegram] Cannot test — credentials not configured.")
            return False

        text = (
            "<b>DevSignal</b> — Bot connected successfully!\n\n"
            "You'll receive iOS internship digests here after each pipeline run."
        )
        success = self._send(text)
        if success:
            print("[Telegram] Test message sent successfully.")
        return success

    # ─────────────────────────────────────────────────────────────────────
    # MESSAGE FORMATTERS
    # Each returns a plain HTML string ready to send
    # ─────────────────────────────────────────────────────────────────────

    def _format_digest(self, jobs: list) -> str:
        """
        Formats the top 5 jobs into a readable digest message.

        Uses HTML formatting:
        <b>text</b>  = bold
        <i>text</i>  = italic
        <code>text</code> = monospace
        <a href="url">text</a> = hyperlink
        """
        # Sort by opportunity_score descending, fall back to date_found
        sorted_jobs = sorted(
            jobs,
            key=lambda j: (j.get("opportunity_score") or 0),
            reverse=True
        )
        top_jobs = sorted_jobs[:5]

        lines = [f"<b>DevSignal — {len(jobs)} new iOS jobs found</b>\n"]

        for i, job in enumerate(top_jobs, 1):
            company  = self._escape_html(job.get("company", "Unknown")[:40])
            role     = self._escape_html(job.get("role", "Unknown")[:50])
            source   = self._escape_html(job.get("job_source", "")[:20])
            remote   = job.get("remote", "Unknown")
            score    = job.get("opportunity_score")
            link     = job.get("apply_link", "")
            location = self._escape_html(job.get("location", "")[:40])

            # Score display — only show if scored, otherwise show source
            score_text = f"Score: <b>{score}/100</b>" if score else f"Source: {source}"

            # Remote badge
            remote_badge = {
                "Yes":     "Remote",
                "Hybrid":  "Hybrid",
                "No":      "On-site",
                "Unknown": "Location TBD",
            }.get(remote, remote)

            # Build the job block
            job_block = f"\n<b>{i}. {company}</b>\n"
            job_block += f"   {role}\n"
            job_block += f"   {remote_badge}"
            if location and location.lower() not in ["remote", "see post", ""]:
                job_block += f" · {location}"
            job_block += f"\n   {score_text}\n"
            
            # Recruiter info
            recruiter_name = job.get("recruiter_name", "")
            linkedin_url   = job.get("linkedin_profile", "")

            if recruiter_name:
                job_block += f"\n   Contact: {self._escape_html(recruiter_name[:30])}"
                if linkedin_url:
                    job_block += f' — <a href="{linkedin_url}">LinkedIn</a>'

            # Apply link
            if link:
                short_link = link[:60] + "..." if len(link) > 60 else link
                job_block += f'   <a href="{link}">Apply</a>'
            else:
                job_block += "   No link available"

            lines.append(job_block)

        if len(jobs) > 5:
            lines.append(f"\n<i>+{len(jobs) - 5} more in database</i>")

        return "\n".join(lines)

    def _format_run_summary(self, jobs_found: int, jobs_filtered: int,
                            jobs_new: int, jobs_stored: int,
                            sources: dict = None) -> str:
        """
        Formats a compact pipeline run statistics message.
        """
        lines = ["<b>DevSignal — Run Complete</b>\n"]

        lines.append(
            f"Scraped:   <b>{jobs_found}</b>\n"
            f"Filtered:  <b>{jobs_found - jobs_filtered}</b> dropped\n"
            f"New:       <b>{jobs_new}</b> unique\n"
            f"Stored:    <b>{jobs_stored}</b> added to DB"
        )

        if sources:
            lines.append("\n<b>By source:</b>")
            for source, count in sorted(sources.items(),
                                        key=lambda x: x[1], reverse=True):
                if count > 0:
                    bar = "█" * min(count, 10)
                    lines.append(f"  {source[:18]:<18} {bar} {count}")

        return "\n".join(lines)

    def _format_high_score_alert(self, job: dict) -> str:
        """
        Formats an urgent single-job alert for high-scoring opportunities.
        """
        company  = self._escape_html(job.get("company", "Unknown"))
        role     = self._escape_html(job.get("role", "Unknown"))
        score    = job.get("opportunity_score", 0)
        remote   = job.get("remote", "Unknown")
        visa     = job.get("visa_sponsorship", "Unknown")
        link     = job.get("apply_link", "")
        source   = job.get("job_source", "")

        lines = [
            f"<b>High-Score Alert — {score}/100</b>\n",
            f"<b>{company}</b>",
            f"{role}",
            f"",
            f"Remote:  {remote}",
            f"Visa:    {visa}",
            f"Source:  {source}",
        ]

        if link:
            lines.append(f'\n<a href="{link}">Apply now</a>')

        outreach = job.get("outreach_message", "")
        if outreach:
            lines.append(f"\n<b>Suggested outreach:</b>")
            lines.append(f"<i>{self._escape_html(outreach[:300])}</i>")

        return "\n".join(lines)

    def _format_no_jobs_message(self) -> str:
        """Message to send when 0 new jobs were found this run."""
        return (
            "<b>DevSignal — Run Complete</b>\n\n"
            "No new iOS opportunities found this run.\n"
            "All scraped jobs already exist in the database.\n\n"
            "<i>The system will check again in 12 hours.</i>"
        )

    # ─────────────────────────────────────────────────────────────────────
    # HTTP LAYER — handles the actual API calls + retries + error handling
    # ─────────────────────────────────────────────────────────────────────

    def _send(self, text: str, retry: bool = True) -> bool:
        """
        Sends a message to the configured chat.

        If the message is too long (> 4096 chars), splits it automatically.
        Retries once on network failure.
        Never raises exceptions — always returns True/False.
        """
        try:
            # Split long messages into chunks
            chunks = self._split_message(text)

            for chunk in chunks:
                success = self._send_chunk(chunk, retry=retry)
                if not success:
                    return False
                if len(chunks) > 1:
                    time.sleep(0.3)   # brief pause between chunks

            return True

        except Exception as e:
            print(f"[Telegram] Unexpected error: {e}")
            return False

    def _send_chunk(self, text: str, retry: bool = True) -> bool:
        """Sends a single message chunk to the Telegram API."""
        url     = f"{self.base_url}/sendMessage"
        payload = {
            "chat_id":    self.chat_id,
            "text":       text,
            "parse_mode": "HTML",
            # Don't show link previews — keeps messages compact
            "disable_web_page_preview": True,
        }

        try:
            response = requests.post(url, json=payload, timeout=15)
            data     = response.json()

            if data.get("ok"):
                return True
            else:
                error = data.get("description", "Unknown error")
                print(f"[Telegram] API error: {error}")

                # Common fixable errors
                if "parse error" in error.lower():
                    print("[Telegram] HTML parse error — retrying without formatting")
                    # Strip HTML tags and retry once
                    import re
                    plain = re.sub(r'<[^>]+>', '', text)
                    return self._send_chunk(plain, retry=False)

                return False

        except requests.exceptions.ConnectionError:
            if retry:
                print("[Telegram] Connection failed — retrying in 5 seconds...")
                time.sleep(5)
                return self._send_chunk(text, retry=False)
            print("[Telegram] Connection failed after retry.")
            return False

        except requests.exceptions.Timeout:
            print("[Telegram] Request timed out.")
            return False

    def _split_message(self, text: str) -> list:
        """
        Splits a message into chunks under MAX_MESSAGE_LENGTH.
        Splits on newlines to avoid cutting mid-word.
        """
        if len(text) <= MAX_MESSAGE_LENGTH:
            return [text]

        chunks = []
        lines  = text.split("\n")
        current_chunk = ""

        for line in lines:
            test = current_chunk + "\n" + line if current_chunk else line
            if len(test) > MAX_MESSAGE_LENGTH:
                if current_chunk:
                    chunks.append(current_chunk)
                current_chunk = line
            else:
                current_chunk = test

        if current_chunk:
            chunks.append(current_chunk)

        return chunks if chunks else [text[:MAX_MESSAGE_LENGTH]]

    @staticmethod
    def _escape_html(text: str) -> str:
        """
        Escapes characters that have special meaning in Telegram HTML:
        < > & must be escaped to &lt; &gt; &amp;
        Without this, a company name like "A&B Corp" or "2<3 Inc"
        would break the HTML parser and cause a Telegram API error.
        """
        if not text:
            return ""
        return (
            text
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
        )


# ─────────────────────────────────────────────────────────────────────────
# CONVENIENCE FUNCTIONS
# Import these directly for cleaner call sites in run_scraper.py
# ─────────────────────────────────────────────────────────────────────────

def send_digest(jobs: list) -> bool:
    return TelegramBot().send_digest(jobs)

def send_run_summary(jobs_found: int, jobs_filtered: int,
                    jobs_new: int, jobs_stored: int,
                    sources: dict = None) -> bool:
    return TelegramBot().send_run_summary(
        jobs_found, jobs_filtered, jobs_new, jobs_stored, sources
    )

def send_high_score_alert(job: dict) -> bool:
    return TelegramBot().send_high_score_alert(job)

def send_error_alert(error_message: str) -> bool:
    return TelegramBot().send_error_alert(error_message)


# ─────────────────────────────────────────────────────────────────────────
# SELF-TEST
# ─────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Testing Telegram bot...")
    print("=" * 55)

    bot = TelegramBot()

    if not bot._configured:
        print("\nCredentials not found in .env")
        print("Add TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID then try again.")
        sys.exit(1)

    # Test 1: connection test
    print("\n[Test 1] Sending connection test message...")
    ok = bot.test_connection()
    print(f"Result: {'sent' if ok else 'FAILED'}")

    # Test 2: digest with mock jobs
    print("\n[Test 2] Sending mock job digest...")
    mock_jobs = [
        {
            "company": "Acme Corp",
            "role": "iOS Developer Intern",
            "remote": "Yes",
            "location": "Remote",
            "job_source": "RemoteOK",
            "opportunity_score": 88,
            "apply_link": "https://example.com/job/1",
            "visa_sponsorship": "Yes",
        },
        {
            "company": "YC Startup",
            "role": "Junior iOS Engineer",
            "remote": "Hybrid",
            "location": "San Francisco, CA",
            "job_source": "HackerNews",
            "opportunity_score": 74,
            "apply_link": "https://news.ycombinator.com/item?id=123",
            "visa_sponsorship": "Unknown",
        },
        {
            "company": "Mobile Co & Partners",  # tests HTML escaping of &
            "role": "Swift Intern",
            "remote": "Yes",
            "location": "Remote",
            "job_source": "Remotive",
            "opportunity_score": None,           # tests unscored job display
            "apply_link": "https://example.com/job/3",
            "visa_sponsorship": "No",
        },
    ]
    ok = bot.send_digest(mock_jobs)
    print(f"Result: {'sent' if ok else 'FAILED'}")

    # Test 3: run summary
    print("\n[Test 3] Sending mock run summary...")
    ok = bot.send_run_summary(
        jobs_found=70,
        jobs_filtered=51,
        jobs_new=44,
        jobs_stored=44,
        sources={"HackerNews": 54, "Remotive": 1, "RemoteOK": 0},
    )
    print(f"Result: {'sent' if ok else 'FAILED'}")

    # Test 4: no new jobs
    print("\n[Test 4] Sending no-new-jobs message...")
    ok = bot.send_digest([])
    print(f"Result: {'sent' if ok else 'FAILED'}")

    print("\nAll tests done. Check your Telegram.")