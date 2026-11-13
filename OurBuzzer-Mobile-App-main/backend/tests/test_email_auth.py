# Email + password auth tests. Self-contained: runs the FastAPI app in-process against an
# in-memory Mongo (mongomock-motor), so no live backend / EXPO_PUBLIC_BACKEND_URL is needed.
#   pip install mongomock-motor && pytest tests/test_email_auth.py -n 0
import os
import sys
import time
from pathlib import Path

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

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


# ---------------- Firebase (Google) login ----------------
_RSA = rsa.generate_private_key(public_exponent=65537, key_size=2048)
PROJECT = "test-project"


def firebase_token(email="ani@ourbuzzer.id", name="Ani Asli", provider="google.com",
                   email_verified=True, aud=PROJECT, iss=None, exp_in=3600, sub="fb_uid_1", key=_RSA):
    t = int(time.time())
    claims = {"aud": aud, "iss": iss or f"https://securetoken.google.com/{PROJECT}", "sub": sub,
              "iat": t, "exp": t + exp_in, "auth_time": t, "email": email, "name": name,
              "email_verified": email_verified, "firebase": {"sign_in_provider": provider}}
    return jwt.encode(claims, key, algorithm="RS256", headers={"kid": "test"})


@pytest.fixture()
def firebase(monkeypatch):
    monkeypatch.setattr(server, "FIREBASE_PROJECT_ID", PROJECT)
    monkeypatch.setattr(server, "_firebase_signing_key", lambda _tok: _RSA.public_key())


def fb_login(c, token):
    return c.post("/api/auth/firebase", json={"id_token": token})


def test_firebase_login_creates_user_and_session(client, firebase):
    r = fb_login(client, firebase_token(email="Budi@OurBuzzer.id", name="Budi"))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["email"] == "budi@ourbuzzer.id" and body["name"] == "Budi"
    assert body["role"] is None and "password_hash" not in body
    me = client.get("/api/auth/me", headers=bearer(body["session_token"])).json()
    assert me["firebase_uid"] == "fb_uid_1" and me["auth_provider"] == "google"
    # Login kedua memakai akun yang sama, bukan membuat user baru.
    r2 = fb_login(client, firebase_token(email="budi@ourbuzzer.id"))
    assert r2.json()["user_id"] == body["user_id"]


def test_firebase_login_admin_email_gets_admin_role(client, firebase):
    r = fb_login(client, firebase_token(email="boss@ourbuzzer.id"))
    assert r.status_code == 200 and r.json()["role"] == "admin"


@pytest.mark.parametrize("kwargs", [
    {"aud": "proyek-lain"},
    {"iss": "https://securetoken.google.com/proyek-lain"},
    {"exp_in": -3600},
    {"provider": "password"},
    {"email_verified": False},
    {"key": rsa.generate_private_key(public_exponent=65537, key_size=2048)},
])
def test_firebase_login_rejects_invalid_tokens(client, firebase, kwargs):
    r = fb_login(client, firebase_token(**kwargs))
    assert r.status_code == 401, (kwargs, r.text)


def test_firebase_login_rejects_garbage_and_missing_config(client, firebase, monkeypatch):
    assert fb_login(client, "bukan-jwt").status_code == 401
    monkeypatch.setattr(server, "FIREBASE_PROJECT_ID", "")
    assert fb_login(client, firebase_token()).status_code == 503


def test_google_login_drops_unverified_password(client, firebase):
    """Someone registers ani@ with a password; the real owner then signs in with Google.
    The unverified password and its sessions must stop working (pre-account-hijacking defense)."""
    attacker_tok = register(client).json()["session_token"]

    r = fb_login(client, firebase_token())
    assert r.status_code == 200
    google_tok = r.json()["session_token"]

    assert client.get("/api/auth/me", headers=bearer(attacker_tok)).status_code == 401
    r = client.post("/api/auth/login", json={"email": "ani@ourbuzzer.id", "password": "rahasia123"})
    assert r.status_code == 401
    assert client.get("/api/auth/me", headers=bearer(google_tok)).status_code == 200
