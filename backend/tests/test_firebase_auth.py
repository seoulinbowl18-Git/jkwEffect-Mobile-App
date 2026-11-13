# Firebase ID-token login (POST /api/auth/firebase). Self-contained: tokens are signed with a
# local RSA key whose JWK replaces Google's published keys, so no network is needed.
#   pytest tests/test_firebase_auth.py -n 0
import os
import sys
import time
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
jwt = pytest.importorskip("jwt")
from cryptography.hazmat.primitives.asymmetric import rsa  # noqa: E402
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_firebase")
os.environ["KOMERCE_RECONCILE_SECONDS"] = "0"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

PROJECT = "ourbuzzer-test"
KID = "test-kid-1"
PRIVATE = rsa.generate_private_key(public_exponent=65537, key_size=2048)
OTHER = rsa.generate_private_key(public_exponent=65537, key_size=2048)
JWK = {**jwt.algorithms.RSAAlgorithm.to_jwk(PRIVATE.public_key(), as_dict=True), "kid": KID, "alg": "RS256"}


def make_token(key=PRIVATE, kid=KID, **overrides):
    t = int(time.time())
    claims = {
        "iss": f"https://securetoken.google.com/{PROJECT}", "aud": PROJECT, "sub": "firebase-uid-123",
        "iat": t, "exp": t + 3600, "auth_time": t, "email": "Ani@Gmail.com", "email_verified": True,
        "name": "Ani Kreator", "picture": "https://lh3.googleusercontent.com/a/x",
        "firebase": {"sign_in_provider": "google.com"},
    }
    claims.update(overrides)
    claims = {k: v for k, v in claims.items() if v is not None}
    return jwt.encode(claims, key, algorithm="RS256", headers={"kid": kid})


@pytest.fixture()
def client(monkeypatch):
    server.db = AsyncMongoMockClient()["test_firebase"]
    server._firebase_keys.update(keys={}, expires=0.0)
    fetches = []

    async def fake_fetch():
        fetches.append(1)
        return {KID: JWK}, 3600

    monkeypatch.setattr(server, "_fetch_firebase_jwks", fake_fetch)
    monkeypatch.setenv("FIREBASE_PROJECT_ID", PROJECT)
    monkeypatch.setattr(server, "ADMIN_EMAIL", "boss@ourbuzzer.id")
    with TestClient(server.app) as c:
        c.fetches = fetches
        yield c


def login(c, token):
    return c.post("/api/auth/firebase", json={"id_token": token})


def test_first_login_creates_user_and_session(client):
    r = login(client, make_token())
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["email"] == "ani@gmail.com" and d["role"] is None and d["session_token"]
    assert "password_hash" not in d and "firebase_uid" in d
    me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {d['session_token']}"})
    assert me.status_code == 200 and me.json()["name"] == "Ani Kreator"


def test_second_login_reuses_account_and_caches_keys(client):
    a = login(client, make_token()).json()
    client.post("/api/users/role", json={"role": "creator"}, headers={"Authorization": f"Bearer {a['session_token']}"})
    b = login(client, make_token()).json()
    assert b["user_id"] == a["user_id"] and b["role"] == "creator"
    assert len(client.fetches) == 1  # Google keys fetched once, then cached


def test_admin_email_becomes_admin(client):
    assert login(client, make_token(email="boss@ourbuzzer.id")).json()["role"] == "admin"


@pytest.mark.parametrize("overrides,why", [
    ({"aud": "someone-else"}, "wrong audience"),
    ({"iss": "https://securetoken.google.com/someone-else"}, "wrong issuer"),
    ({"exp": int(time.time()) - 3600, "iat": int(time.time()) - 7200}, "expired"),
    ({"sub": ""}, "empty subject"),
])
def test_invalid_claims_rejected(client, overrides, why):
    r = login(client, make_token(**overrides))
    assert r.status_code == 401, why


def test_forged_signature_rejected(client):
    assert login(client, make_token(key=OTHER)).status_code == 401


def test_unknown_kid_refetches_then_rejects(client):
    r = login(client, make_token(kid="rotated-away"))
    assert r.status_code == 401 and len(client.fetches) == 2  # one forced refresh


def test_garbage_and_hs256_rejected(client):
    assert login(client, "x" * 40).status_code == 401
    hs = jwt.encode({"sub": "a", "aud": PROJECT}, "secret", algorithm="HS256", headers={"kid": KID})
    assert login(client, hs).status_code == 401


def test_requires_google_provider_and_verified_email(client):
    r = login(client, make_token(firebase={"sign_in_provider": "password"}))
    assert r.status_code == 401
    r = login(client, make_token(email_verified=False))
    assert r.status_code == 401
    r = login(client, make_token(email=None))
    assert r.status_code == 401


def test_not_configured(client, monkeypatch):
    monkeypatch.delenv("FIREBASE_PROJECT_ID")
    assert login(client, make_token()).status_code == 503


def test_drops_unverified_password_of_preregistered_account(client):
    """Someone registered ani@gmail.com with a password; the real owner signs in with Google."""
    reg = client.post("/api/auth/register", json={"name": "Penyusup", "email": "ani@gmail.com", "password": "rahasia123"})
    attacker = reg.json()["session_token"]
    assert login(client, make_token()).status_code == 200
    assert client.get("/api/auth/me", headers={"Authorization": f"Bearer {attacker}"}).status_code == 401
    r = client.post("/api/auth/login", json={"email": "ani@gmail.com", "password": "rahasia123"})
    assert r.status_code == 401
