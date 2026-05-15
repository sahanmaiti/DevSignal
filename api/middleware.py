import hmac
import json
import sys
import os

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config.settings import PIPELINE_API_KEY, PUBLIC_PATHS


class APIKeyMiddleware(BaseHTTPMiddleware):

    async def dispatch(self, request: Request, call_next):
        # ── Skip auth for public paths ──────────────────────────────────────
        # PUBLIC_PATHS is a frozenset defined in settings.py.
        # In development it includes /docs, /openapi.json, /redoc.
        # In production those paths are absent so this branch is never taken
        # for them (and FastAPI itself won't even register those routes).
        if request.url.path in PUBLIC_PATHS:
            request.state.user = None
            return await call_next(request)

        # ── Read credentials from request ───────────────────────────────────
        x_api_key   = request.headers.get("X-API-Key", "")
        auth_header = request.headers.get("Authorization", "")

        # ── Mode 1: Static pipeline API key ────────────────────────────────
        
        if x_api_key:
            if hmac.compare_digest(
                x_api_key.encode("utf-8"),
                PIPELINE_API_KEY.encode("utf-8"),
            ):
                request.state.user = None
                return await call_next(request)

            # Per-user ds_ key — look up in the database
            if x_api_key.startswith("ds_"):
                user = _lookup_user_api_key(x_api_key)
                if user is not None:
                    request.state.user = user
                    return await call_next(request)

            # Key provided but matched nothing — reject immediately.
            # We do NOT fall through to the JWT branch so that a wrong key
            # always returns 401 rather than silently trying other methods.
            return _unauthorized("Invalid API key.")

        # ── Mode 2: JWT Bearer token ────────────────────────────────────────
        if auth_header.startswith("Bearer "):
            token = auth_header[len("Bearer "):]
            user  = _verify_jwt(token)
            if user is not None:
                request.state.user = user
                return await call_next(request)
            return _unauthorized("Invalid or expired token.")

        # ── No credentials at all ───────────────────────────────────────────
        return _unauthorized(
            "Authentication required. "
            "Pass X-API-Key header or Authorization: Bearer <token>."
        )


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def _unauthorized(detail: str) -> Response:
    body = json.dumps({"detail": detail})
    return Response(
        content=body,
        status_code=401,
        media_type="application/json",
        headers={"WWW-Authenticate": 'Bearer realm="DevSignal"'},
    )


def _lookup_user_api_key(raw_key: str):
    """
    Looks up a per-user API key in the database.
    Returns a user dict on success, None on failure.
    Imported lazily to avoid a circular-import at module load time.
    """
    try:
        from api.auth import lookup_api_key
        return lookup_api_key(raw_key)
    except Exception:
        return None


def _verify_jwt(token: str):
    """
    Validates a JWT and returns the user dict.
    Returns None on any failure (invalid, expired, user not found).
    """
    try:
        from api.auth import decode_access_token, get_user_by_id
        payload = decode_access_token(token)
        return get_user_by_id(payload["sub"])
    except Exception:
        return None