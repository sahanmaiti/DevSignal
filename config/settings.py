import os
import secrets
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────────────────────────────────────
# DATABASE
# ─────────────────────────────────────────────────────────────────────────────

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://radar:radar_pass@localhost:5433/devsignal"   # BUG-2 fix: 5433 not 5432
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

# ─────────────────────────────────────────────────────────────────────────────

_pipeline_api_key = os.getenv("PIPELINE_API_KEY")
if not _pipeline_api_key:
    raise RuntimeError(
        "PIPELINE_API_KEY environment variable is not set.\n"
        "Add it to your .env file.  Generate a value with:\n"
        "  python -c \"import secrets; print(secrets.token_hex(32))\""
    )
PIPELINE_API_KEY: str = _pipeline_api_key

APP_ENV = os.getenv("APP_ENV", "development")   # "development" | "production"

# ─────────────────────────────────────────────────────────────────────────────
# SEC-1: CORS allowed origins
#
# In development every localhost port is allowed so the iOS app,
# React dev server, etc. all work without config changes.
#
# In production set ALLOWED_ORIGINS in your .env as a comma-separated list:
#   ALLOWED_ORIGINS=https://app.devsignal.com,https://dashboard.devsignal.com
#
# The wildcard "*" is intentionally absent from the production list.
# ─────────────────────────────────────────────────────────────────────────────

_DEVELOPMENT_ORIGINS = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:5173",   # Vite
    "http://localhost:8000",
    "http://127.0.0.1:8000",
]

if APP_ENV == "production":
    # Read from env, fall back to an empty list so we fail loudly rather
    # than silently allowing everything.
    _raw_origins = os.getenv("ALLOWED_ORIGINS", "")
    ALLOWED_ORIGINS: list[str] = (
        [o.strip() for o in _raw_origins.split(",") if o.strip()]
        if _raw_origins
        else []
    )
    if not ALLOWED_ORIGINS:
        import warnings
        warnings.warn(
            "APP_ENV=production but ALLOWED_ORIGINS is not set. "
            "CORS will reject all cross-origin requests. "
            "Set ALLOWED_ORIGINS=https://your-domain.com in your .env file.",
            stacklevel=1,
        )
else:
    ALLOWED_ORIGINS = _DEVELOPMENT_ORIGINS

# ─────────────────────────────────────────────────────────────────────────────
# SEC-2: Public API docs paths
#
# In development /docs, /redoc, and /openapi.json are open so you can
# explore the API interactively.  In production they are locked behind
# authentication by removing them from the public-paths set.
# ─────────────────────────────────────────────────────────────────────────────

if APP_ENV == "production":
    PUBLIC_PATHS: frozenset[str] = frozenset({
        "/health",
        "/n8n-ping",
        "/auth/register",
        "/auth/login",
        "/devices",
    })
else:
    PUBLIC_PATHS: frozenset[str] = frozenset({
        "/health",
        "/n8n-ping",
        "/docs",
        "/openapi.json",
        "/redoc",
        "/auth/register",
        "/auth/login",
        "/devices",
    })

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