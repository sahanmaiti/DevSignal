import hmac
import json
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response
from config.settings import PIPELINE_API_KEY


class APIKeyMiddleware(BaseHTTPMiddleware):

    PUBLIC_PATHS = {"/health", "/docs", "/openapi.json", "/redoc", "/n8n-ping"}

    async def dispatch(self, request: Request, call_next):
        if request.url.path in self.PUBLIC_PATHS:
            return await call_next(request)

        api_key = request.headers.get("X-API-Key") or ""

        # BUG-6 FIX: use hmac.compare_digest instead of != to prevent
        # timing attacks. Plain string comparison short-circuits on the
        # first mismatched byte; compare_digest always takes the same time
        # regardless of where the mismatch occurs.
        if not hmac.compare_digest(
            api_key.encode("utf-8"),
            PIPELINE_API_KEY.encode("utf-8"),
        ):
            body = json.dumps({
                "detail": "Invalid or missing API key. Pass it as X-API-Key header."
            })
            return Response(content=body, status_code=401,
                            media_type="application/json")

        return await call_next(request)