from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.auth import get_current_user_id
from app.routers import reminders, events, captures, memory, ai, account, devices, auth

app = FastAPI(
    title="Personal Memory OS API",
    version="1.0.0",
    description="AWS-native personal reminder and memory platform",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten to specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(reminders.router, prefix="/reminders", tags=["reminders"])
app.include_router(events.router, prefix="/events", tags=["events"])
app.include_router(captures.router, prefix="/captures", tags=["captures"])
app.include_router(memory.router, prefix="/memory", tags=["memory"])
app.include_router(ai.router, prefix="/ai", tags=["ai"])
app.include_router(account.router, prefix="/account", tags=["account"])
app.include_router(devices.router, prefix="/devices", tags=["devices"])


@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "service": "Personal Memory OS API", "version": "1.0.0"}


@app.get("/health/me", tags=["health"])
async def health_me(user_id: str = Depends(get_current_user_id)):
    """Protected health check - returns the authenticated user's ID."""
    return {"status": "ok", "user_id": user_id}
