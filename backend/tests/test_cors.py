import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

from fastapi.testclient import TestClient

from app.main import app


def preflight(origin):
    return TestClient(app).options(
        "/auth/login",
        headers={"Origin": origin, "Access-Control-Request-Method": "POST", "Access-Control-Request-Headers": "authorization,content-type"},
    )


def test_default_allows_any_origin_without_credentials():
    r = preflight("https://anything.example")
    assert r.status_code == 200
    assert r.headers["access-control-allow-origin"] == "*"
    assert "access-control-allow-credentials" not in r.headers


def test_restricted_origins_only_allow_the_listed_site():
    from fastapi import FastAPI
    from fastapi.middleware.cors import CORSMiddleware

    mini = FastAPI()
    mini.add_middleware(CORSMiddleware, allow_origins=["https://app.example.com"], allow_credentials=False,
                        allow_methods=["*"], allow_headers=["*"])

    @mini.post("/x")
    def x():
        return {}

    c = TestClient(mini)
    ok = c.options("/x", headers={"Origin": "https://app.example.com", "Access-Control-Request-Method": "POST"})
    bad = c.options("/x", headers={"Origin": "https://evil.example", "Access-Control-Request-Method": "POST"})
    assert ok.headers.get("access-control-allow-origin") == "https://app.example.com"
    assert "access-control-allow-origin" not in bad.headers
