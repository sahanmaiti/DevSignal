import os
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────────────────────
# DATABASE
# ─────────────────────────────────────────────────────────────

# BUG-2 FIX: docker-compose.yml maps host port 5433 → container port 5432.
# The default here must use 5433 (the host-side port) or the app will
# silently fail to connect unless DATABASE_URL is explicitly set in .env.
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://radar:radar_pass@localhost:5433/devsignal"
)

# ─────────────────────────────────────────────────────────────
# TELEGRAM
# ─────────────────────────────────────────────────────────────

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID   = os.getenv("TELEGRAM_CHAT_ID", "")

# ─────────────────────────────────────────────────────────────
# AI (free via Groq)
# ─────────────────────────────────────────────────────────────

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL   = "llama-3.1-8b-instant"

HIGH_SCORE_ALERT_THRESHOLD = 55
OUTREACH_MIN_SCORE         = 45

# ─────────────────────────────────────────────────────────────
# ENRICHMENT APIs
# ─────────────────────────────────────────────────────────────

HUNTER_API_KEY       = os.getenv("HUNTER_API_KEY", "")
SERPER_API_KEY       = os.getenv("SERPER_API_KEY", "")
ENRICHMENT_MIN_SCORE = 50

ADZUNA_APP_ID  = os.getenv("ADZUNA_APP_ID", "")
ADZUNA_APP_KEY = os.getenv("ADZUNA_APP_KEY", "")

# ─────────────────────────────────────────────────────────────
# SCRAPER SETTINGS
# ─────────────────────────────────────────────────────────────

MAX_EXPERIENCE_YEARS = 2
DIGEST_TOP_N         = 5
DIGEST_MIN_SCORE     = 45

NEON_DATABASE_URL = os.getenv("NEON_DATABASE_URL", "")

# BUG-5 FIX (partial): remove the insecure plaintext default.
# If PIPELINE_API_KEY is not set in .env the app should refuse to start,
# not silently run with a publicly-known key baked into the source code.
# Uncomment the strict line and remove the fallback once you've added
# PIPELINE_API_KEY to every deployment environment.
#
# Strict (recommended for production):
#   PIPELINE_API_KEY = os.environ["PIPELINE_API_KEY"]
#
# Permissive (current — keeps local dev working without .env changes):
PIPELINE_API_KEY = os.getenv("PIPELINE_API_KEY", "devsignal-local-key-2024")

APP_ENV = os.getenv("APP_ENV", "development")