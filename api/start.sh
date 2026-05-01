#!/bin/bash
# api/start.sh
# 
# Starts the DevSignal API server.
# Usage: bash api/start.sh
#
# uvicorn is the ASGI server that runs FastAPI.
# --reload means: automatically restart when you edit a .py file (dev mode only).
# --host 0.0.0.0 means: accept connections from any IP (needed for iOS simulator).
# --port 8000 is the port number (iOS app will call http://localhost:8000).

cd "$(dirname "$0")/.."   # change to project root regardless of where you call this from

source venv/bin/activate   # activate your virtual environment

uvicorn api.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --reload \
    --log-level info