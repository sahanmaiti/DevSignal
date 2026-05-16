import json
import os
import sys
from typing import Any

import redis.asyncio as aioredis

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import REDIS_URL


class RedisCache:
    """
    Async Redis cache with JSON serialisation.

    Falls back gracefully if Redis is unavailable — callers get None
    on a cache miss and the DB query runs normally. This means Redis
    outages degrade performance but never break correctness.
    """

    def __init__(self):
        self._client: aioredis.Redis | None = None

    async def _get_client(self) -> aioredis.Redis | None:
        """Lazy-initialises the Redis connection."""
        if self._client is None:
            try:
                self._client = aioredis.from_url(
                    REDIS_URL,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=2,   # fail fast if Redis is down
                )
                # Verify the connection is alive
                await self._client.ping()
            except Exception as e:
                print(f"[Cache] Redis unavailable: {e} — caching disabled")
                self._client = None
        return self._client

    async def get(self, key: str) -> Any | None:
        """Returns the cached value, or None on miss / error."""
        client = await self._get_client()
        if client is None:
            return None
        try:
            raw = await client.get(key)
            return json.loads(raw) if raw is not None else None
        except Exception:
            return None

    async def set(self, key: str, value: Any, ttl: int = 300) -> None:
        """
        Stores value as JSON with an expiry (TTL in seconds).
        Default 300s = 5 minutes — matches the iOS app's pull-to-refresh UX.
        """
        client = await self._get_client()
        if client is None:
            return
        try:
            await client.setex(key, ttl, json.dumps(value, default=str))
        except Exception:
            pass   # cache write failure is non-fatal

    async def delete(self, key: str) -> None:
        """Invalidates a cache key (e.g. after a pipeline run)."""
        client = await self._get_client()
        if client is None:
            return
        try:
            await client.delete(key)
        except Exception:
            pass

    async def delete_pattern(self, pattern: str) -> None:
        """Invalidates all keys matching a glob pattern."""
        client = await self._get_client()
        if client is None:
            return
        try:
            keys = await client.keys(pattern)
            if keys:
                await client.delete(*keys)
        except Exception:
            pass


# Singleton — import this everywhere
cache = RedisCache()