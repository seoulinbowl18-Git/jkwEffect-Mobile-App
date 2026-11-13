# Komerce top-up + callback + reconciliation, payments config, and image uploads.
# Self-contained: in-process app + mongomock-motor + a fake Komerce HTTP client.
#   pytest tests/test_payments_uploads.py -n 0
import hashlib
import hmac
import json
import os
import sys
from datetime import timedelta
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_payments")
os.environ["KOMERCE_RECONCILE_SECONDS"] = "0"  # no background loop in tests
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

server.RECONCILE_SECONDS = 0
BASE = "https://komerce.test"
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


class FakeKomerce:
    """Stands in for httpx.AsyncClient; records calls, answers like the Komerce Payment API."""

    def __init__(self):
        self.calls = []
        self.status = "PENDING"
        self.create_status = 200
        self.create_body = None
        self.fail = None

    def client(self, *a, **k):
        fake = self

        class _C:
            async def __aenter__(self):
                return self

            async def __aexit__(self, *a):
                return False

            async def post(self, url, json=None, headers=None):
                fake.calls.append(("POST", url, json, headers))
                if fake.fail:
                    raise fake.fail
                body = fake.create_body or {"meta": {"code": 200}, "data": {
                    "payment_id": "PAY_1", "qr_string": "000201QRIS" if json["payment_type"] == "qris" else "",
                    "va_number": "8808123" if json["payment_type"] == "bank_transfer" else "",
                    "payment_url": "https://pay.test/PAY_1"}}
                return _Resp(fake.create_status, body)

            async def get(self, url, headers=None):
                fake.calls.append(("GET", url, None, headers))
                if fake.fail:
                    raise fake.fail
                return _Resp(200, {"data": {"payment_id": "PAY_1", "status": fake.status}})

        return _C()


class _Resp:
    def __init__(self, status, body):
        self.status_code = status
        self._body = body
        self.text = json.dumps(body)
        self.headers = {"content-type": "application/json"}

    def json(self):
        return self._body


@pytest.fixture()
def env(monkeypatch):
    server.db = AsyncMongoMockClient()["test_payments"]
    fake = FakeKomerce()
    monkeypatch.setattr(server.httpx, "AsyncClient", fake.client)
    monkeypatch.setenv("KOMERCE_BASE_URL", BASE + "/")
    monkeypatch.setenv("KOMERCE_API_KEY", "sandbox-key")
    monkeypatch.setenv("PUBLIC_BASE_URL", "https://api.ourbuzzer.test")
    with TestClient(server.app) as c:
        for uid, role in (("brand_1", "brand"), ("creator_1", "creator")):
            c.portal.call(server.db.users.insert_one, server.new_user_doc(uid, f"{uid}@x.id", uid, role=role))
            c.portal.call(server.db.user_sessions.insert_one, {
                "user_id": uid, "session_token": f"tok_{uid}",
                "expires_at": server.now() + timedelta(days=1), "created_at": server.now()})
        yield c, fake


B = {"Authorization": "Bearer tok_brand_1"}
C = {"Authorization": "Bearer tok_creator_1"}


def brand_balance(c):
    return c.get("/api/auth/me", headers=B).json()["brand_balance"]


def create_qris(c, amount=250000):
    r = c.post("/api/brand/topups", json={"amount": amount, "payment_type": "qris"}, headers=B)
    assert r.status_code == 200, r.text
    return r.json()


def test_not_configured_returns_503_and_config_flag(env, monkeypatch):
    c, _ = env
    monkeypatch.delenv("KOMERCE_API_KEY")
    assert c.get("/api/payments/config", headers=B).json() == {"komerce_configured": False, "sandbox": False}
    r = c.post("/api/brand/topups", json={"amount": 100000, "payment_type": "qris"}, headers=B)
    assert r.status_code == 503 and r.json()["detail"] == "Pembayaran Komerce belum dikonfigurasi"


def test_configured_flag_and_sandbox(env, monkeypatch):
    c, _ = env
    monkeypatch.setenv("KOMERCE_BASE_URL", "https://api-sandbox.komerce.id")
    assert c.get("/api/payments/config", headers=B).json() == {"komerce_configured": True, "sandbox": True}


def test_create_qris_calls_komerce_correctly(env):
    c, fake = env
    t = create_qris(c)
    method, url, payload, headers = fake.calls[-1]
    assert (method, url) == ("POST", f"{BASE}/api/v1/user/payment/create")  # trailing slash stripped
    assert headers["x-api-key"] == "sandbox-key"
    assert payload["callback_url"] == "https://api.ourbuzzer.test/api/payments/komerce/callback"
    # Tagihan = saldo masuk Rp 250.000 + biaya layanan platform 10% (Rp 25.000).
    assert payload["amount"] == 275000 and payload["order_id"] == t["topup_id"]
    assert payload["items"] == [{"name": "Top up saldo campaign", "quantity": 1, "price": 250000},
                                {"name": "Biaya layanan platform (10%)", "quantity": 1, "price": 25000}]
    assert (t["amount"], t["fee"], t["fee_pct"], t["total"]) == (250000, 25000, 10, 275000)
    assert t["qr_string"] == "000201QRIS" and t["status"] == "pending"
    assert "callback_key" not in t and "callback_url" not in t


def test_create_va_sends_channel(env):
    c, fake = env
    r = c.post("/api/brand/topups", json={"amount": 100000, "payment_type": "bank_transfer", "channel_code": "BNI"},
               headers=B)
    assert r.json()["va_number"] == "8808123"
    assert fake.calls[-1][2]["channel_code"] == "BNI"


def test_check_status_credits_once(env):
    c, fake = env
    t = create_qris(c)
    assert c.post(f"/api/brand/topups/{t['topup_id']}/check", headers=B).json()["status"] == "pending"
    assert brand_balance(c) == 0
    fake.status = "PAID"
    assert c.post(f"/api/brand/topups/{t['topup_id']}/check", headers=B).json()["status"] == "paid"
    c.post(f"/api/brand/topups/{t['topup_id']}/check", headers=B)
    assert brand_balance(c) == 250000  # credited exactly once
    assert fake.calls[-1][1] == f"{BASE}/api/v1/user/payment/status/PAY_1"


def test_callback_with_valid_signature_credits(env):
    c, fake = env
    t = create_qris(c)
    key = c.portal.call(server.db.topups.find_one, {"topup_id": t["topup_id"]})["callback_key"]
    body = json.dumps({"data": {"payment_id": "PAY_1", "order_id": t["topup_id"], "status": "PAID"}}).encode()

    bad = c.post("/api/payments/komerce/callback", content=body, headers={"X-Callback-Api-Key": "nope"})
    assert bad.status_code == 401 and brand_balance(c) == 0

    fake.status = "PAID"  # callback is re-confirmed against Komerce before crediting
    sig = hmac.new(key.encode(), body, hashlib.sha256).hexdigest()
    ok = c.post("/api/payments/komerce/callback", content=body, headers={"X-Callback-Api-Key": sig})
    assert ok.status_code == 200 and brand_balance(c) == 250000


def test_callback_cannot_fake_paid_status(env):
    c, fake = env
    t = create_qris(c)
    key = c.portal.call(server.db.topups.find_one, {"topup_id": t["topup_id"]})["callback_key"]
    body = json.dumps({"data": {"payment_id": "PAY_1", "status": "PAID"}}).encode()
    sig = hmac.new(key.encode(), body, hashlib.sha256).hexdigest()
    c.post("/api/payments/komerce/callback", content=body, headers={"X-Callback-Api-Key": sig})
    assert brand_balance(c) == 0  # Komerce still says PENDING


def test_expired_status_is_applied(env):
    c, fake = env
    t = create_qris(c)
    fake.status = "CANCELLED"
    assert c.post(f"/api/brand/topups/{t['topup_id']}/check", headers=B).json()["status"] == "canceled"


def test_reconcile_credits_pending_paid_topups(env):
    c, fake = env
    create_qris(c, 100000)
    create_qris(c, 150000)
    fake.status = "PAID"
    n = c.portal.call(server.reconcile_pending_topups_once, 20, 0)
    assert n == 2 and brand_balance(c) == 250000
    assert c.portal.call(server.reconcile_pending_topups_once, 20, 0) == 0


def test_komerce_errors_are_actionable(env):
    c, fake = env
    fake.create_status = 401
    fake.create_body = {"meta": {}}
    r = c.post("/api/brand/topups", json={"amount": 100000, "payment_type": "qris"}, headers=B)
    assert r.status_code == 502 and "KOMERCE_API_KEY" in r.json()["detail"]

    fake.create_status, fake.create_body = 404, {}
    r = c.post("/api/brand/topups", json={"amount": 100000, "payment_type": "qris"}, headers=B)
    assert "KOMERCE_BASE_URL" in r.json()["detail"]

    fake.fail = server.httpx.ConnectError("down")
    r = c.post("/api/brand/topups", json={"amount": 100000, "payment_type": "qris"}, headers=B)
    assert r.status_code == 502 and "menghubungi Komerce" in r.json()["detail"]
    assert c.portal.call(server.db.topups.count_documents, {}) == 0


def test_check_survives_komerce_outage(env):
    c, fake = env
    t = create_qris(c)
    fake.fail = server.httpx.ConnectError("down")
    r = c.post(f"/api/brand/topups/{t['topup_id']}/check", headers=B)
    assert r.status_code == 200 and r.json()["status"] == "pending"


# ---------------- uploads ----------------
def test_brand_upload_and_serve(env):
    c, _ = env
    r = c.post("/api/uploads", files={"file": ("thumb.png", PNG, "image/png")}, headers=B)
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["url"] == f"https://api.ourbuzzer.test/api/uploads/{d['upload_id']}"
    g = c.get(f"/api/uploads/{d['upload_id']}")
    assert g.status_code == 200 and g.content == PNG and g.headers["content-type"] == "image/png"


def test_upload_rejections(env):
    c, _ = env
    assert c.post("/api/uploads", files={"file": ("a.png", PNG, "image/png")}, headers=C).status_code == 403
    r = c.post("/api/uploads", files={"file": ("a.png", b"<svg onload=alert(1)>", "image/png")}, headers=B)
    assert r.status_code == 400  # content sniffed, client content-type ignored
    big = b"\xff\xd8\xff" + b"\x00" * (2 * 1024 * 1024)
    assert c.post("/api/uploads", files={"file": ("a.jpg", big, "image/jpeg")}, headers=B).status_code == 413
    assert c.get("/api/uploads/img_missing").status_code == 404


def test_creator_avatar_upload_replace_and_delete(env):
    c, _ = env
    r = c.post("/api/users/avatar", files={"file": ("me.png", PNG, "image/png")}, headers=C)
    assert r.status_code == 200, r.text
    u = r.json()
    first = u["picture"]
    assert first.startswith("https://api.ourbuzzer.test/api/uploads/img_") and u["picture_custom"] is True
    assert c.get(first.replace("https://api.ourbuzzer.test", "")).content == PNG
    # Replacing deletes the previous upload.
    second = c.post("/api/users/avatar", files={"file": ("me2.png", PNG, "image/png")}, headers=C).json()["picture"]
    assert second != first
    assert c.get(first.replace("https://api.ourbuzzer.test", "")).status_code == 404
    # Validation is the same as /uploads.
    assert c.post("/api/users/avatar", files={"file": ("x.png", b"not an image", "image/png")}, headers=C).status_code == 400
    assert c.post("/api/users/avatar", files={"file": ("x.png", PNG, "image/png")}).status_code == 401
    # Delete → back to the Google photo (none here) and the upload is gone.
    d = c.delete("/api/users/avatar", headers=C).json()
    assert d["picture"] is None and d["picture_custom"] is False
    assert c.get(second.replace("https://api.ourbuzzer.test", "")).status_code == 404


def test_google_login_keeps_custom_avatar(env):
    c, _ = env
    uid = c.portal.call(server.upsert_verified_user, "creator_1@x.id", "creator_1", "https://g.test/a.jpg")
    assert c.get("/api/auth/me", headers=C).json()["picture"] == "https://g.test/a.jpg"
    custom = c.post("/api/users/avatar", files={"file": ("me.png", PNG, "image/png")}, headers=C).json()["picture"]
    c.portal.call(server.upsert_verified_user, "creator_1@x.id", "creator_1", "https://g.test/b.jpg")
    me = c.get("/api/auth/me", headers=C).json()
    assert uid == "creator_1" and me["picture"] == custom  # Google login does not overwrite it
    # Removing the custom photo restores the latest Google photo.
    assert c.delete("/api/users/avatar", headers=C).json()["picture"] == "https://g.test/b.jpg"


@pytest.mark.parametrize("raw,expected", [
    ("https://api.ourbuzzer.test", "https://api.ourbuzzer.test"),
    ("  https://api.ourbuzzer.test/  ", "https://api.ourbuzzer.test"),
    ('"https://api.ourbuzzer.test"', "https://api.ourbuzzer.test"),
    ("api.ourbuzzer.test", "https://api.ourbuzzer.test"),
    ("https://api.ourbuzzer.test/api", "https://api.ourbuzzer.test"),
    ("[https://api.ourbuzzer.test](https://api.ourbuzzer.test)", "https://api.ourbuzzer.test"),
    ("ourbuzzer-mobile-app-production.up.railway.app", "https://ourbuzzer-mobile-app-production.up.railway.app"),
    ("", ""), ("localhost", ""), ("https://", ""), ("not a url", ""),
])
def test_clean_base_url(raw, expected):
    assert server.clean_base_url(raw) == expected


def test_callback_url_survives_messy_public_base_url(env, monkeypatch):
    c, fake = env
    monkeypatch.setenv("PUBLIC_BASE_URL", "[https://api.ourbuzzer.test/](https://api.ourbuzzer.test/)")
    create_qris(c)
    assert fake.calls[-1][2]["callback_url"] == "https://api.ourbuzzer.test/api/payments/komerce/callback"


def test_callback_url_falls_back_to_railway_domain(env, monkeypatch):
    c, fake = env
    monkeypatch.setenv("PUBLIC_BASE_URL", "BASE URL")  # unusable
    monkeypatch.setenv("RAILWAY_PUBLIC_DOMAIN", "ourbuzzer-mobile-app-production.up.railway.app")
    create_qris(c)
    assert fake.calls[-1][2]["callback_url"] == \
        "https://ourbuzzer-mobile-app-production.up.railway.app/api/payments/komerce/callback"
