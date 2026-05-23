"""Shared slowapi Limiter instance.

Lives at module-top-level so any router can `from rate_limit import limiter`
and apply `@limiter.limit(...)` to its handlers without an import cycle
with `main.py`. `main.py` wires it into `app.state.limiter` and registers
the 429 exception handler.

Key function: client IP via `get_remote_address`. Behind Railway/Fly/etc.
the platform sets `X-Forwarded-For`; slowapi reads it by default.
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
