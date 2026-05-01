from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from config.settings import PIPELINE_API_KEY


class APIKeyMiddleware(BaseHTTPMiddleware):
    
    PUBLIC_PATHS = {"/health", "/docs", "/openapi.json", "/redoc"}

    async def dispatch(self, request: Request, call_next):
        if request.url.path in self.PUBLIC_PATHS:
            return await call_next(request)
        
        api_key = request.headers.get("X-API-Key")
        
        if request.url.path not in ["/", "/health", "/docs", "/openapi.json"]:
            if api_key != PIPELINE_API_KEY:
                raise HTTPException(
                status_code=401,
                detail="Invalid or missing API key. Pass it as X-API-Key header."
        )
        
        return await call_next(request)