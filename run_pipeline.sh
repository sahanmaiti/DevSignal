#!/bin/bash
# run_pipeline.sh
#
# PURPOSE:
#   Entry point called by n8n's Execute Command node.
#   Runs the full DevSignal pipeline with proper environment setup.
#
# DESIGNED FOR:
#   Running inside the n8n Docker container where:
#   - Project files are mounted at /app
#   - Python venv is at /app/venv
#   - Working directory should be /app
#
# CAN ALSO BE RUN DIRECTLY ON YOUR MAC:
#   bash run_pipeline.sh
#
# PLACEMENT: project root

set -e   # exit immediately if any command fails

# ── Detect where we're running ────────────────────────────────────────────
# Inside Docker container: project is at /app
# On your Mac directly:    project is wherever this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set project root — works both in Docker (/app) and on Mac
if [ -d "/app" ] && [ -f "/app/run_scraper.py" ]; then
    PROJECT_ROOT="/app"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

# ── Set Python path ────────────────────────────────────────────────────────
PYTHON="$PROJECT_ROOT/venv/bin/python"

# Fallback: if venv doesn't exist, try system python
if [ ! -f "$PYTHON" ]; then
    PYTHON=$(which python3 || which python)
fi

# ── Change to project directory ───────────────────────────────────────────
cd "$PROJECT_ROOT"

# ── Log start ─────────────────────────────────────────────────────────────
echo "============================================"
echo "  DevSignal Pipeline — $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Project: $PROJECT_ROOT"
echo "  Python:  $PYTHON"
echo "============================================"
echo ""

# ── Run the pipeline ──────────────────────────────────────────────────────

echo ">>> Step 1: Scraping..."
$PYTHON run_scraper.py
SCRAPER_EXIT=$?

if [ $SCRAPER_EXIT -ne 0 ]; then
    echo "ERROR: Scraper failed with exit code $SCRAPER_EXIT"
    exit $SCRAPER_EXIT
fi

echo ""
echo ">>> Step 2: AI Scoring..."
$PYTHON run_scorer.py
SCORER_EXIT=$?

if [ $SCORER_EXIT -ne 0 ]; then
    echo "WARNING: Scorer failed with exit code $SCORER_EXIT"
    echo "Continuing pipeline (scoring failure is non-fatal)..."
fi

echo ""
echo ">>> Step 3: Enrichment..."
$PYTHON run_enricher.py --min-score 70
ENRICHER_EXIT=$?

if [ $ENRICHER_EXIT -ne 0 ]; then
    echo "WARNING: Enricher failed with exit code $ENRICHER_EXIT"
    echo "Continuing (enrichment failure is non-fatal)..."
fi

echo ""
echo "============================================"
echo "  Pipeline complete — $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"

exit 0
