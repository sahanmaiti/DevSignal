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

import os
import sys
import time
import re
import requests

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

MAX_MESSAGE_LENGTH = 4096


class TelegramBot:
    def __init__(self):
        self.token = TELEGRAM_BOT_TOKEN
        self.chat_id = TELEGRAM_CHAT_ID
        self.base_url = f"https://api.telegram.org/bot{self.token}"
        self._configured = bool(self.token and self.chat_id)

        if not self._configured:
            print("[Telegram] WARNING: BOT_TOKEN or CHAT_ID not set in .env")
            print("[Telegram] Notifications disabled.")

    # ─────────────────────────────────────────────
    # PUBLIC METHODS
    # ─────────────────────────────────────────────

    def send_digest(self, jobs: list) -> bool:
        """
        Sends digest of jobs.

        Updated behavior:
        - If no jobs -> send no jobs message
        - Otherwise sort/show top 5 regardless of threshold
        """
        if not self._configured:
            return False

        if not jobs:
            return self._send(self._format_no_jobs_message())

        # Sort by score, show top 5 regardless of score threshold
        message = self._format_digest(jobs)
        return self._send(message)

    def send_run_summary(
        self,
        jobs_found: int,
        jobs_filtered: int,
        jobs_new: int,
        jobs_stored: int,
        sources: dict = None,
    ) -> bool:
        if not self._configured:
            return False

        message = self._format_run_summary(
            jobs_found,
            jobs_filtered,
            jobs_new,
            jobs_stored,
            sources,
        )
        return self._send(message)

    def send_high_score_alert(self, job: dict) -> bool:
        if not self._configured:
            return False

        message = self._format_high_score_alert(job)
        return self._send(message)

    def send_error_alert(self, error_message: str) -> bool:
        if not self._configured:
            return False

        text = (
            f"<b>DevSignal — Pipeline Error</b>\n\n"
            f"<code>{self._escape_html(error_message[:500])}</code>\n\n"
            f"Check terminal for traceback."
        )
        return self._send(text)

    def test_connection(self) -> bool:
        if not self._configured:
            print("[Telegram] Credentials missing.")
            return False

        text = (
            "<b>DevSignal</b> — Bot connected successfully!\n\n"
            "You'll receive iOS job digests here."
        )

        ok = self._send(text)
        if ok:
            print("[Telegram] Test message sent.")
        return ok

    # ─────────────────────────────────────────────
    # FORMATTERS
    # ─────────────────────────────────────────────

    def _format_digest(self, jobs: list) -> str:
        sorted_jobs = sorted(
            jobs,
            key=lambda j: (j.get("opportunity_score") or 0),
            reverse=True,
        )

        top_jobs = sorted_jobs[:5]

        lines = [f"<b>DevSignal — {len(jobs)} new iOS jobs found</b>\n"]

        for i, job in enumerate(top_jobs, 1):
            company = self._escape_html(job.get("company", "Unknown")[:40])
            role = self._escape_html(job.get("role", "Unknown")[:50])
            source = self._escape_html(job.get("job_source", "")[:20])
            remote = job.get("remote", "Unknown")
            score = job.get("opportunity_score")
            link = job.get("apply_link", "")
            location = self._escape_html(job.get("location", "")[:40])

            score_text = (
                f"Score: <b>{score}/100</b>"
                if score is not None
                else f"Source: {source}"
            )

            remote_badge = {
                "Yes": "Remote",
                "Hybrid": "Hybrid",
                "No": "On-site",
                "Unknown": "Location TBD",
            }.get(remote, remote)

            block = f"\n<b>{i}. {company}</b>\n"
            block += f"   {role}\n"
            block += f"   {remote_badge}"

            if location and location.lower() not in ["remote", "see post", ""]:
                block += f" · {location}"

            block += f"\n   {score_text}\n"

            recruiter_name = job.get("recruiter_name", "")
            linkedin = job.get("linkedin_profile", "")

            if recruiter_name:
                block += (
                    f"\n   Contact: "
                    f"{self._escape_html(recruiter_name[:30])}"
                )
                if linkedin:
                    block += f' — <a href="{linkedin}">LinkedIn</a>'

            if link:
                block += f'   <a href="{link}">Apply</a>'
            else:
                block += "   No link available"

            lines.append(block)

        if len(jobs) > 5:
            lines.append(f"\n<i>+{len(jobs)-5} more in database</i>")

        return "\n".join(lines)

    def _format_run_summary(
        self,
        jobs_found: int,
        jobs_filtered: int,
        jobs_new: int,
        jobs_stored: int,
        sources: dict = None,
    ) -> str:
        lines = ["<b>DevSignal — Run Complete</b>\n"]

        lines.append(
            f"Scraped:   <b>{jobs_found}</b>\n"
            f"Filtered:  <b>{jobs_found - jobs_filtered}</b> dropped\n"
            f"New:       <b>{jobs_new}</b> unique\n"
            f"Stored:    <b>{jobs_stored}</b> added to DB"
        )

        if sources:
            lines.append("\n<b>By source:</b>")
            for source, count in sorted(
                sources.items(),
                key=lambda x: x[1],
                reverse=True,
            ):
                if count > 0:
                    bar = "█" * min(count, 10)
                    lines.append(f"  {source[:18]:<18} {bar} {count}")

        return "\n".join(lines)

    def _format_high_score_alert(self, job: dict) -> str:
        company = self._escape_html(job.get("company", "Unknown"))
        role = self._escape_html(job.get("role", "Unknown"))
        score = job.get("opportunity_score", 0)
        remote = job.get("remote", "Unknown")
        visa = job.get("visa_sponsorship", "Unknown")
        source = job.get("job_source", "")
        link = job.get("apply_link", "")

        lines = [
            f"<b>High-Score Alert — {score}/100</b>\n",
            f"<b>{company}</b>",
            role,
            "",
            f"Remote: {remote}",
            f"Visa: {visa}",
            f"Source: {source}",
        ]

        if link:
            lines.append(f'\n<a href="{link}">Apply now</a>')

        outreach = job.get("outreach_message", "")
        if outreach:
            lines.append("\n<b>Suggested outreach:</b>")
            lines.append(
                f"<i>{self._escape_html(outreach[:300])}</i>"
            )

        return "\n".join(lines)

    def _format_no_jobs_message(self) -> str:
        return (
            "<b>DevSignal — Run Complete</b>\n\n"
            "No new iOS opportunities found this run.\n"
            "All scraped jobs already exist in the database.\n\n"
            "<i>The system will check again later.</i>"
        )

    # ─────────────────────────────────────────────
    # HTTP LAYER
    # ─────────────────────────────────────────────

    def _send(self, text: str, retry: bool = True) -> bool:
        try:
            chunks = self._split_message(text)

            for chunk in chunks:
                ok = self._send_chunk(chunk, retry=retry)
                if not ok:
                    return False
                if len(chunks) > 1:
                    time.sleep(0.3)

            return True

        except Exception as e:
            print(f"[Telegram] Unexpected error: {e}")
            return False

    def _send_chunk(self, text: str, retry: bool = True) -> bool:
        url = f"{self.base_url}/sendMessage"

        payload = {
            "chat_id": self.chat_id,
            "text": text,
            "parse_mode": "HTML",
            "disable_web_page_preview": True,
        }

        try:
            response = requests.post(url, json=payload, timeout=15)
            data = response.json()

            if data.get("ok"):
                return True

            error = data.get("description", "Unknown error")
            print(f"[Telegram] API error: {error}")

            if "parse error" in error.lower():
                plain = re.sub(r"<[^>]+>", "", text)
                return self._send_chunk(plain, retry=False)

            return False

        except requests.exceptions.ConnectionError:
            if retry:
                print("[Telegram] Connection failed. Retrying...")
                time.sleep(5)
                return self._send_chunk(text, retry=False)

            return False

        except requests.exceptions.Timeout:
            print("[Telegram] Request timed out.")
            return False

    def _split_message(self, text: str) -> list:
        if len(text) <= MAX_MESSAGE_LENGTH:
            return [text]

        chunks = []
        lines = text.split("\n")
        current = ""

        for line in lines:
            test = current + "\n" + line if current else line

            if len(test) > MAX_MESSAGE_LENGTH:
                if current:
                    chunks.append(current)
                current = line
            else:
                current = test

        if current:
            chunks.append(current)

        return chunks

    @staticmethod
    def _escape_html(text: str) -> str:
        if not text:
            return ""

        return (
            text.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
        )


# ─────────────────────────────────────────────
# CONVENIENCE FUNCTIONS
# ─────────────────────────────────────────────

def send_digest(jobs: list) -> bool:
    return TelegramBot().send_digest(jobs)


def send_run_summary(
    jobs_found: int,
    jobs_filtered: int,
    jobs_new: int,
    jobs_stored: int,
    sources: dict = None,
) -> bool:
    return TelegramBot().send_run_summary(
        jobs_found,
        jobs_filtered,
        jobs_new,
        jobs_stored,
        sources,
    )


def send_high_score_alert(job: dict) -> bool:
    return TelegramBot().send_high_score_alert(job)


def send_error_alert(error_message: str) -> bool:
    return TelegramBot().send_error_alert(error_message)


# ─────────────────────────────────────────────
# SELF TEST
# ─────────────────────────────────────────────

if __name__ == "__main__":
    print("Testing Telegram bot...")
    print("=" * 55)

    bot = TelegramBot()

    if not bot._configured:
        print("Credentials missing.")
        sys.exit(1)

    bot.test_connection()