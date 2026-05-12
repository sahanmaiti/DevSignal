
import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from passlib.context import CryptContext

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config.settings import JWT_SECRET, JWT_ALGORITHM, JWT_EXPIRE_MINUTES
from storage.db_client import db_client


# ─────────────────────────────────────────────────────────────────────────────
# PASSWORD HASHING
# ─────────────────────────────────────────────────────────────────────────────

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    """Returns a bcrypt hash of a plaintext password."""
    return _pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    """Returns True if plain matches the stored bcrypt hash."""
    return _pwd_context.verify(plain, hashed)


# ─────────────────────────────────────────────────────────────────────────────
# JWT
# ─────────────────────────────────────────────────────────────────────────────

def create_access_token(user_id: str, email: str,
                        expires_in: Optional[int] = None) -> str:
    """
    Creates a signed JWT containing the user's id and email.

    expires_in: override the default TTL (minutes) from settings.
    """
    minutes = expires_in if expires_in is not None else JWT_EXPIRE_MINUTES
    expire  = datetime.now(timezone.utc) + timedelta(minutes=minutes)
    payload = {
        "sub":   user_id,   # "subject" — standard JWT claim, holds user id
        "email": email,
        "exp":   expire,
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    """
    Decodes and validates a JWT.  Raises HTTPException 401 on any failure.
    Returns the decoded payload dict on success.
    """
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        if payload.get("sub") is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing subject",
            )
        return payload
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token validation failed: {exc}",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ─────────────────────────────────────────────────────────────────────────────
# PER-USER API KEYS
# ─────────────────────────────────────────────────────────────────────────────

def generate_api_key() -> tuple[str, str]:
    """
    Generates a new API key pair.

    Returns (raw_key, key_hash) where:
    raw_key  — shown to the user ONCE at creation time; never stored
    key_hash — SHA-256 digest stored in the api_keys table
    """
    raw      = "ds_" + secrets.token_urlsafe(32)   # e.g. "ds_A3bC…"
    key_hash = _sha256(raw)
    return raw, key_hash


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def hash_api_key(raw_key: str) -> str:
    """Public helper — hash a raw key before looking it up in the DB."""
    return _sha256(raw_key)


# ─────────────────────────────────────────────────────────────────────────────
# DB HELPERS (synchronous — called from auth endpoints only, not hot path)
# ─────────────────────────────────────────────────────────────────────────────

def get_user_by_email(email: str) -> Optional[dict]:
    """Returns the users row for email, or None."""
    with db_client.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, email, hashed_password, plan, is_active "
                "FROM users WHERE email = %s LIMIT 1",
                (email.lower().strip(),),
            )
            row = cur.fetchone()
            if row is None:
                return None
            return {
                "id":              str(row[0]),
                "email":           row[1],
                "hashed_password": row[2],
                "plan":            row[3],
                "is_active":       row[4],
            }


def get_user_by_id(user_id: str) -> Optional[dict]:
    """Returns the users row for user_id, or None."""
    with db_client.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, email, plan, is_active FROM users WHERE id = %s::uuid",
                (user_id,),
            )
            row = cur.fetchone()
            if row is None:
                return None
            return {
                "id":        str(row[0]),
                "email":     row[1],
                "plan":      row[2],
                "is_active": row[3],
            }


def create_user(email: str, password: str, plan: str = "free") -> dict:
    """
    Inserts a new user row.  Raises HTTPException 409 on duplicate email.
    Returns the new user dict (without hashed_password).
    """
    import psycopg2
    hashed = hash_password(password)
    try:
        with db_client.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO users (email, hashed_password, plan) "
                    "VALUES (%s, %s, %s) RETURNING id, email, plan",
                    (email.lower().strip(), hashed, plan),
                )
                row = cur.fetchone()
                return {"id": str(row[0]), "email": row[1], "plan": row[2]}
    except psycopg2.errors.UniqueViolation:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Email '{email}' is already registered.",
        )


def lookup_api_key(raw_key: str) -> Optional[dict]:
    """
    Looks up a raw API key in the api_keys table.
    Updates last_used timestamp on a hit.
    Returns the matching user dict, or None if not found / revoked.
    """
    key_hash = _sha256(raw_key)
    with db_client.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT u.id, u.email, u.plan, u.is_active
                FROM api_keys k
                JOIN users u ON k.user_id = u.id
                WHERE k.key_hash = %s AND k.revoked = FALSE
                LIMIT 1
                """,
                (key_hash,),
            )
            row = cur.fetchone()
            if row is None:
                return None
            user = {
                "id":        str(row[0]),
                "email":     row[1],
                "plan":      row[2],
                "is_active": row[3],
            }
            # Touch last_used (fire-and-forget; ignore errors)
            try:
                cur.execute(
                    "UPDATE api_keys SET last_used = NOW() WHERE key_hash = %s",
                    (key_hash,),
                )
            except Exception:
                pass
            return user


def create_api_key_for_user(user_id: str, name: str = "default") -> str:
    """
    Generates a new API key, stores its hash, returns the raw key.
    The raw key is the only time it will ever be visible.
    """
    raw, key_hash = generate_api_key()
    with db_client.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO api_keys (user_id, key_hash, name) VALUES (%s, %s, %s)",
                (user_id, key_hash, name),
            )
    return raw


def list_api_keys_for_user(user_id: str) -> list[dict]:
    """Returns all non-revoked API keys for a user (without the hash)."""
    with db_client.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, name, last_used, created_at "
                "FROM api_keys WHERE user_id = %s AND revoked = FALSE "
                "ORDER BY created_at DESC",
                (user_id,),
            )
            return [
                {
                    "id":         str(r[0]),
                    "name":       r[1],
                    "last_used":  r[2].isoformat() if r[2] else None,
                    "created_at": r[3].isoformat(),
                }
                for r in cur.fetchall()
            ]


def revoke_api_key(key_id: str, user_id: str) -> bool:
    """Revokes an API key. Returns True if a row was updated."""
    with db_client.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE api_keys SET revoked = TRUE "
                "WHERE id = %s::uuid AND user_id = %s::uuid",
                (key_id, user_id),
            )
            return cur.rowcount > 0


# ─────────────────────────────────────────────────────────────────────────────
# FASTAPI DEPENDENCY — get the current authenticated user
#
# Usage in endpoint:
#   @app.get("/me")
#   async def me(user = Depends(get_current_user)):
#       return {"email": user["email"]}
#
# Returns None (rather than raising) when the endpoint is called without
# credentials — lets callers decide whether auth is required.
# ─────────────────────────────────────────────────────────────────────────────

_bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> Optional[dict]:
    """
    Tries to authenticate the request via a JWT Bearer token.
    Returns the user dict or None (does NOT raise on missing credentials).
    """
    if credentials is None:
        return None
    try:
        payload = decode_access_token(credentials.credentials)
        return get_user_by_id(payload["sub"])
    except HTTPException:
        return None


async def require_user(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> dict:
    """
    Dependency that REQUIRES a valid authenticated user.
    Raises 401 if not authenticated, 403 if account is inactive.

    Authentication is resolved in priority order:

    1. request.state.user — set by APIKeyMiddleware for both X-API-Key modes.
    Per-user ds_ keys land here with a full user dict.
    This covers all API-key authenticated requests.

    2. JWT Bearer token — extracted directly from the Authorization header.
    Fallback for direct JWT use (web dashboard, tests).

    Without checking request.state.user first, requests authenticated via a
    per-user API key (ds_xxx) would always get 401 on protected endpoints
    because the Authorization header is absent for API-key requests.
    """
    # ── Priority 1: middleware already authenticated this request ─────────
    middleware_user = getattr(request.state, "user", None)
    if middleware_user is not None:
        if not middleware_user.get("is_active"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is inactive.",
            )
        return middleware_user

    # ── Priority 2: JWT Bearer token ──────────────────────────────────────
    if credentials is not None:
        try:
            payload = decode_access_token(credentials.credentials)
            user = get_user_by_id(payload["sub"])
            if user is not None:
                if not user.get("is_active"):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Account is inactive.",
                    )
                return user
        except HTTPException:
            pass

    # ── No valid credentials found ────────────────────────────────────────
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required.",
        headers={"WWW-Authenticate": "Bearer"},
    )