import os
import secrets
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────────────────────────────────────
# DATABASE
# ─────────────────────────────────────────────────────────────────────────────

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://radar:radar_pass@localhost:5433/devsignal"
)

# ─────────────────────────────────────────────────────────────────────────────
# TELEGRAM
# ─────────────────────────────────────────────────────────────────────────────

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID   = os.getenv("TELEGRAM_CHAT_ID", "")

# ─────────────────────────────────────────────────────────────────────────────
# AI (free via Groq)
# ─────────────────────────────────────────────────────────────────────────────

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL   = "llama-3.1-8b-instant"

HIGH_SCORE_ALERT_THRESHOLD = 55
OUTREACH_MIN_SCORE         = 45

# ─────────────────────────────────────────────────────────────────────────────
# ENRICHMENT APIs
# ─────────────────────────────────────────────────────────────────────────────

HUNTER_API_KEY       = os.getenv("HUNTER_API_KEY", "")
SERPER_API_KEY       = os.getenv("SERPER_API_KEY", "")
ENRICHMENT_MIN_SCORE = 50

ADZUNA_APP_ID  = os.getenv("ADZUNA_APP_ID", "")
ADZUNA_APP_KEY = os.getenv("ADZUNA_APP_KEY", "")

# ─────────────────────────────────────────────────────────────────────────────
# SCRAPER SETTINGS
# ─────────────────────────────────────────────────────────────────────────────

MAX_EXPERIENCE_YEARS = 2
DIGEST_TOP_N         = 5
DIGEST_MIN_SCORE     = 45

NEON_DATABASE_URL = os.getenv("NEON_DATABASE_URL", "")

PIPELINE_API_KEY = os.getenv("PIPELINE_API_KEY", "devsignal-local-key-2024")

APP_ENV = os.getenv("APP_ENV", "development")

# ─────────────────────────────────────────────────────────────────────────────
# AUTH — ARCH-2
# ─────────────────────────────────────────────────────────────────────────────

JWT_SECRET         = os.getenv("JWT_SECRET", secrets.token_hex(32))
JWT_ALGORITHM      = "HS256"
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

# ─────────────────────────────────────────────────────────────────────────────
# QUEUE — ARCH-4
# ─────────────────────────────────────────────────────────────────────────────

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")