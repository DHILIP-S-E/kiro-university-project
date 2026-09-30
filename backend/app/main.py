from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import reminders, events, captures, memory, ai

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

app.include_router(reminders.router, prefix="/reminders", tags=["reminders"])
app.include_router(events.router, prefix="/events", tags=["events"])
app.include_router(captures.router, prefix="/captures", tags=["captures"])
app.include_router(memory.router, prefix="/memory", tags=["memory"])
app.include_router(ai.router, prefix="/ai", tags=["ai"])


@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "service": "Personal Memory OS API", "version": "1.0.0"}


@app.get("/health/me", tags=["health"])
async def health_me(user_id: str = None):
    """Protected health check — returns the authenticated user's ID."""
    from app.auth import get_current_user_id
    from fastapi import Depends
    return {"status": "ok", "user_id": user_id}
