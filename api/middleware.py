
import hmac
import json
import sys
import os

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import PIPELINE_API_KEY


# Public paths that skip ALL authentication
PUBLIC_PATHS = {
    "/health",
    "/docs",
    "/openapi.json",
    "/redoc",
    "/n8n-ping",
    "/auth/register",
    "/auth/login",
}


class APIKeyMiddleware(BaseHTTPMiddleware):

    async def dispatch(self, request: Request, call_next):
        # ── Skip auth for public paths ────────────────────────────────────
        if request.url.path in PUBLIC_PATHS:
            request.state.user = None
            return await call_next(request)

        # ── Read credentials from request ─────────────────────────────────
        x_api_key    = request.headers.get("X-API-Key", "")
        auth_header  = request.headers.get("Authorization", "")

        # ── Mode 1: Static API key ────────────────────────────────────────
        # Use hmac.compare_digest instead of != to prevent timing attacks.
        # Both strings are encoded to bytes because compare_digest requires
        # the same type on both sides.
        if x_api_key:
            if hmac.compare_digest(
                x_api_key.encode("utf-8"),
                PIPELINE_API_KEY.encode("utf-8"),
            ):
                request.state.user = None   # personal mode, no user object
                return await call_next(request)

            # Key looks like a user-generated key ("ds_…") — try the DB
            if x_api_key.startswith("ds_"):
                user = _lookup_user_api_key(x_api_key)
                if user is not None:
                    request.state.user = user
                    return await call_next(request)

            # Key provided but matched nothing — reject immediately
            return _unauthorized("Invalid API key.")

        # ── Mode 3: JWT Bearer token ──────────────────────────────────────
        if auth_header.startswith("Bearer "):
            token = auth_header[len("Bearer "):]
            user  = _verify_jwt(token)
            if user is not None:
                request.state.user = user
                return await call_next(request)
            return _unauthorized("Invalid or expired token.")

        # ── No credentials at all ─────────────────────────────────────────
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