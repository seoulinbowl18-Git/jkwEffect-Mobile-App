# Email + password auth tests. Self-contained: runs the FastAPI app in-process against an
# in-memory Mongo (mongomock-motor), so no live backend / EXPO_PUBLIC_BACKEND_URL is needed.
#   pip install mongomock-motor && pytest tests/test_email_auth.py -n 0
import os
import sys
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_email_auth")
os.environ["ADMIN_EMAIL"] = "boss@ourbuzzer.id"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

server.ADMIN_EMAIL = "boss@ourbuzzer.id"


@pytest.fixture()
def client():
    server.db = AsyncMongoMockClient()["test_email_auth"]
    server._login_fails.clear()
    with TestClient(server.app) as c:
        yield c


def register(c, email="ani@ourbuzzer.id", password="rahasia123", name="Ani Kreator"):
    return c.post("/api/auth/register", json={"name": name, "email": email, "password": password})


def bearer(tok):
    return {"Authorization": f"Bearer {tok}"}


def test_register_returns_session_and_no_hash(client):
    r = register(client, email="Ani@OurBuzzer.id")
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["email"] == "ani@ourbuzzer.id"
    assert d["role"] is None  # -> onboarding (pilih peran)
    assert d["session_token"]
    assert "password_hash" not in d and "password_hash" not in d["user"]
    me = client.get("/api/auth/me", headers=bearer(d["session_token"]))
    assert me.status_code == 200 and "password_hash" not in me.json()


def test_register_then_choose_role_and_login(client):
    tok = register(client).json()["session_token"]
    r = client.post("/api/users/role", json={"role": "creator"}, headers=bearer(tok))
    assert r.status_code == 200 and r.json()["role"] == "creator" and "password_hash" not in r.json()

    r = client.post("/api/auth/login", json={"email": "ANI@ourbuzzer.id", "password": "rahasia123"})
    assert r.status_code == 200, r.text
    assert r.json()["role"] == "creator"
    assert r.json()["session_token"] != tok


def test_register_duplicate_and_validation(client):
    assert register(client).status_code == 200
    r = register(client)
    assert r.status_code == 400 and "sudah terdaftar" in r.json()["detail"]
    assert register(client, email="b@ourbuzzer.id", password="pendek").status_code == 422
    assert register(client, email="bukan-email").status_code == 422
    assert register(client, email="c@ourbuzzer.id", password="é" * 40).status_code == 422  # 80 bytes > 72


def test_admin_email_cannot_self_register(client):
    r = register(client, email="boss@ourbuzzer.id")
    assert r.status_code == 400


def test_login_wrong_password_and_unknown_email(client):
    register(client)
    r = client.post("/api/auth/login", json={"email": "ani@ourbuzzer.id", "password": "salah-banget"})
    assert r.status_code == 401 and r.json()["detail"] == "Email atau password salah"
    r = client.post("/api/auth/login", json={"email": "tidakada@ourbuzzer.id", "password": "apapun123"})
    assert r.status_code == 401 and r.json()["detail"] == "Email atau password salah"


def test_google_only_account(client):
    client.portal.call(server.db.users.insert_one, server.new_user_doc(
        "user_g", "gina@ourbuzzer.id", "Gina", email_verified=True, auth_provider="google"))
    r = client.post("/api/auth/login", json={"email": "gina@ourbuzzer.id", "password": "apapun123"})
    assert r.status_code == 401 and "Google" in r.json()["detail"]
    r = register(client, email="gina@ourbuzzer.id")
    assert r.status_code == 400 and "Google" in r.json()["detail"]


def test_login_rate_limited(client):
    register(client)
    for _ in range(server.MAX_FAILS_PER_EMAIL):
        client.post("/api/auth/login", json={"email": "ani@ourbuzzer.id", "password": "salah-banget"})
    r = client.post("/api/auth/login", json={"email": "ani@ourbuzzer.id", "password": "rahasia123"})
    assert r.status_code == 429


def test_logout_invalidates_email_session(client):
    tok = register(client).json()["session_token"]
    assert client.post("/api/auth/logout", headers=bearer(tok)).json() == {"ok": True}
    assert client.get("/api/auth/me", headers=bearer(tok)).status_code == 401


def test_google_login_drops_unverified_password(client, monkeypatch):
    """Someone registers ani@ with a password; the real owner then signs in with Google.
    The unverified password and its sessions must stop working (pre-account-hijacking defense)."""
    attacker_tok = register(client).json()["session_token"]

    class FakeResp:
        status_code = 200

        def json(self):
            return {"email": "ani@ourbuzzer.id", "name": "Ani Asli", "picture": None, "session_token": "google_tok"}

    class FakeClient:
        def __init__(self, *a, **k):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def get(self, *a, **k):
            return FakeResp()

    monkeypatch.setattr(server.httpx, "AsyncClient", FakeClient)
    r = client.post("/api/auth/session", json={"session_id": "sid"})
    assert r.status_code == 200 and r.json()["session_token"] == "google_tok"

    assert client.get("/api/auth/me", headers=bearer(attacker_tok)).status_code == 401
    r = client.post("/api/auth/login", json={"email": "ani@ourbuzzer.id", "password": "rahasia123"})
    assert r.status_code == 401
    assert client.get("/api/auth/me", headers=bearer("google_tok")).status_code == 200
