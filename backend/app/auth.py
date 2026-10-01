"""
Cognito JWT authentication middleware.

Downloads the JWKS from the Cognito User Pool endpoint and verifies every
incoming Bearer token (signature, expiry, issuer, token_use, app client).
Injects the Cognito `sub` (user ID) as a FastAPI dependency.

Insecure dev mode (accept any token) exists ONLY when ALLOW_INSECURE_DEV_AUTH=true.
If Cognito is not configured and dev mode is off, every request is refused —
a misconfigured deployment must fail closed, never accept forged tokens.
"""

import httpx
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.config import settings

security = HTTPBearer(auto_error=True)

_JWKS_CACHE: dict | None = None


def expected_issuer() -> str:
    return (
        f"https://cognito-idp.{settings.cognito_region}.amazonaws.com"
        f"/{settings.cognito_user_pool_id}"
    )


def validate_claims(claims: dict, issuer: str, app_client_id: str) -> str | None:
    """Return the user's `sub` if the (already signature-verified) claims are
    acceptable for this API, else None. Pure — unit tested."""
    if claims.get("iss") != issuer:
        return None
    use = claims.get("token_use")
    if use == "access":
        client = claims.get("client_id")
    elif use == "id":
        client = claims.get("aud")
    else:
        return None
    if app_client_id and client != app_client_id:
        return None
    sub = claims.get("sub")
    return sub if isinstance(sub, str) and sub else None


async def _get_cognito_public_keys(force: bool = False) -> dict:
    global _JWKS_CACHE
    if _JWKS_CACHE is not None and not force:
        return _JWKS_CACHE
    url = expected_issuer() + "/.well-known/jwks.json"
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
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired authentication token",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not settings.cognito_user_pool_id:
        if settings.allow_insecure_dev_auth:
            try:
                return jwt.get_unverified_claims(token).get("sub", "dev_user")
            except JWTError:
                return "dev_user"
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication is not configured",
        )

    try:
        kid = jwt.get_unverified_header(token).get("kid")
        if not kid:
            raise unauthorized

        jwks = await _get_cognito_public_keys()
        key = next((k for k in jwks.get("keys", []) if k.get("kid") == kid), None)
        if key is None:  # keys may have rotated
            jwks = await _get_cognito_public_keys(force=True)
            key = next((k for k in jwks.get("keys", []) if k.get("kid") == kid), None)
        if key is None:
            raise unauthorized

        claims = jwt.decode(
            token, key, algorithms=["RS256"], options={"verify_aud": False}
        )
        user_id = validate_claims(claims, expected_issuer(), settings.cognito_app_client_id)
        if not user_id:
            raise unauthorized
        return user_id

    except HTTPException:
        raise
    except Exception:
        raise unauthorized
