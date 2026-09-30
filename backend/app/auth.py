"""
Cognito JWT authentication middleware.

Downloads the JWKS from the Cognito User Pool endpoint and verifies
every incoming Bearer token. Injects the Cognito `sub` (user ID) as a
FastAPI dependency.
"""

import httpx
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.config import settings
from functools import lru_cache

security = HTTPBearer(auto_error=True)

_JWKS_CACHE: dict | None = None


async def _get_cognito_public_keys() -> dict:
    global _JWKS_CACHE
    if _JWKS_CACHE is not None:
        return _JWKS_CACHE
    url = (
        f"https://cognito-idp.{settings.cognito_region}.amazonaws.com"
        f"/{settings.cognito_user_pool_id}/.well-known/jwks.json"
    )
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(url)
        response.raise_for_status()
        _JWKS_CACHE = response.json()
        return _JWKS_CACHE


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    """
    FastAPI dependency. Validates the Cognito JWT and returns the user's `sub`.

    Usage:
        @router.get("/something")
        async def handler(user_id: str = Depends(get_current_user_id)):
            ...
    """
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired authentication token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Decode header without verification to get `kid`
        header = jwt.get_unverified_header(token)
        kid = header.get("kid")
        if not kid:
            raise credentials_exception

        # Find matching public key
        jwks = await _get_cognito_public_keys()
        public_key = next(
            (k for k in jwks.get("keys", []) if k.get("kid") == kid), None
        )
        if not public_key is None and not public_key:
            raise credentials_exception

        # Fallback: if Cognito not configured (dev mode), accept any non-empty token
        if not settings.cognito_user_pool_id:
            # Dev mode — extract sub from unverified payload
            unverified = jwt.get_unverified_claims(token)
            return unverified.get("sub", "dev_user")

        if public_key is None:
            raise credentials_exception

        # Verify and decode
        payload = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=settings.cognito_app_client_id or None,
            options={"verify_aud": bool(settings.cognito_app_client_id)},
        )
        user_id: str | None = payload.get("sub")
        if not user_id:
            raise credentials_exception
        return user_id

    except JWTError:
        raise credentials_exception
    except HTTPException:
        raise
    except Exception:
        raise credentials_exception
