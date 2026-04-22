# config/keywords.py
#
# PURPOSE:
#   All search terms and classification rules live here.
#   When you want to add a new role type or tech keyword, you edit this file
#   and every scraper picks it up automatically — no scraper code to change.

# ─────────────────────────────────────────────────────────────
# JOB TITLE KEYWORDS
# These are what we search for when scanning job titles.
# Using .lower() means these are case-insensitive in scrapers.
# ─────────────────────────────────────────────────────────────

IOS_ROLE_KEYWORDS = [
    "ios intern",
    "ios developer intern",
    "ios engineer intern",
    "ios software intern",
    "junior ios developer",
    "junior ios engineer",
    "junior ios software engineer",
    "swift intern",
    "swift developer intern",
    "swift engineer intern",
    "swiftui intern",
    "swiftui developer",
    "mobile ios intern",
    "mobile developer intern ios",
    "apple developer intern",
]


# ─────────────────────────────────────────────────────────────
# TECH STACK KEYWORDS
# If a job mentions any of these, it's iOS-relevant.
# Used as a secondary check when the title isn't explicit.
# ─────────────────────────────────────────────────────────────

IOS_TECH_KEYWORDS = [
    "swift",
    "swiftui",
    "uikit",
    "xcode",
    "objective-c",
    "objc",
    "combine",          # Apple's reactive framework
    "core data",        # Apple's persistence framework
    "arkit",            # Augmented reality
    "mapkit",           # Maps
    "avfoundation",     # Audio/video
    "core ml",          # On-device machine learning
    "ios sdk",
    "apple platform",
    "cocoa touch",
    "cocoapods",        # iOS package manager
    "spm",              # Swift Package Manager
    "testflight",       # Apple's beta testing platform
    "app store connect",
]


# ─────────────────────────────────────────────────────────────
# EXCLUSION KEYWORDS
# If a job title contains these, skip it even if it mentions "iOS".
# Prevents false positives like "iOS QA Automation Engineer (10+ years)"
# ─────────────────────────────────────────────────────────────

EXCLUDE_KEYWORDS = [
    "senior",
    "staff",
    "principal",
    "lead developer",
    "lead engineer",
    "head of",
    "director",
    "manager",         # hiring manager, not the role
    "10+ years",
    "8+ years",
    "7+ years",
    "5+ years",
    "4+ years",
    "3+ years",
]


# ─────────────────────────────────────────────────────────────
# VISA POSITIVE SIGNALS
# If a job description contains any of these phrases, we mark
# visa_sponsorship as "Yes" — even without a formal statement.
# ─────────────────────────────────────────────────────────────

VISA_POSITIVE_PHRASES = [
    "visa sponsorship",
    "sponsor visa",
    "will sponsor",
    "h1b",
    "h-1b",
    "work authorization",
    "open to international",
    "global candidates",
    "relocation assistance",
    "we offer visa",          
    "we provide sponsorship",
]


# ─────────────────────────────────────────────────────────────
# EXPERIENCE LEVEL PATTERNS
# Regex-ready strings to detect experience requirements in job text.
# We use these in job_parser.py (Phase 3).
# ─────────────────────────────────────────────────────────────

EXPERIENCE_PATTERNS = [
    r"(\d+)\+?\s*years?\s+of\s+experience",
    r"(\d+)\+?\s*yrs?\s+experience",
    r"experience[:\s]+(\d+)\+?\s*years?",
    r"minimum\s+(\d+)\s+years?",
    r"at\s+least\s+(\d+)\s+years?",
    r"(\d+)-(\d+)\s+years?\s+experience",
]