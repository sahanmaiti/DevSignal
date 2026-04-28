# config/settings.py
#
# PURPOSE:
#   Central home for ALL configuration in the project.
#   Every other file imports from here — nothing reads os.getenv() directly.
#
#   Why centralize? If you ever rename a variable or change a default,
#   you change it in ONE place and everything updates automatically.
#
# HOW IT WORKS:
#   1. load_dotenv() reads your .env file
#   2. os.getenv("KEY") retrieves the value for that key
#   3. The second argument to os.getenv() is the default if the key is missing

import os
from dotenv import load_dotenv

# load_dotenv() must be called before any os.getenv() calls.
# It reads .env from the current directory (or parent directories).
load_dotenv()


# ─────────────────────────────────────────────────────────────
# DATABASE
# ─────────────────────────────────────────────────────────────

# Full PostgreSQL connection string.
# Format: postgresql://USER:PASSWORD@HOST:PORT/DATABASE_NAME
# The default matches our docker-compose.yml setup.
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://radar:radar_pass@localhost:5432/devsignal"
)


# ─────────────────────────────────────────────────────────────
# TELEGRAM
# ─────────────────────────────────────────────────────────────

# Your bot's API token from @BotFather
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")

# Your personal Telegram chat ID (where the bot sends messages to you)
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")


# ── AI (free via Groq) ────────────────────────────────────────────────────
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")

# Model to use — llama-3.1-8b-instant is free, fast, great at JSON
GROQ_MODEL   = "llama-3.1-8b-instant"

# Scoring thresholds
HIGH_SCORE_ALERT_THRESHOLD = 85   # send immediate Telegram alert above this
DIGEST_MIN_SCORE           = 60   # only include in digest above this
# ─────────────────────────────────────────────────────────────
# ENRICHMENT APIs
# ─────────────────────────────────────────────────────────────

# Hunter.io — discovers email patterns for a company domain
HUNTER_API_KEY = os.getenv("HUNTER_API_KEY", "")

# Apollo.io — finds recruiter and hiring manager contact info
APOLLO_API_KEY = os.getenv("APOLLO_API_KEY", "")

# Serper.dev for Google search (free tier: 100 searches/month)
# Get free key at serper.dev — used for LinkedIn profile finding
SERPER_API_KEY = os.getenv("SERPER_API_KEY", "")
# Only enrich jobs scoring at or above this threshold
# (conserves Hunter.io's 25/month free quota)
ENRICHMENT_MIN_SCORE = 70

ADZUNA_APP_ID  = os.getenv("ADZUNA_APP_ID", "")
ADZUNA_APP_KEY = os.getenv("ADZUNA_APP_KEY", "")

# ─────────────────────────────────────────────────────────────
# SCRAPER SETTINGS
# ─────────────────────────────────────────────────────────────

# How many years of experience is the maximum we'll accept in a role
MAX_EXPERIENCE_YEARS = 2

# How many top opportunities to include in the Telegram digest
DIGEST_TOP_N = 5

# Minimum score (0-100) for a job to appear in the Telegram digest
DIGEST_MIN_SCORE = 70

NEON_DATABASE_URL = os.getenv("NEON_DATABASE_URL", "")