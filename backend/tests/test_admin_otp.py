# Admin Pusat (Owner) login with WhatsApp OTP via Fonnte. Fonnte is faked; no real messages.
#   pytest tests/test_admin_otp.py -n 0
import os
import re
import sys
from datetime import timedelta
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_admin_otp")
os.environ["KOMERCE_RECONCILE_SECONDS"] = "0"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

server.RECONCILE_SECONDS = 0
OWNER = "081234567890"


class FakeFonnte:
    def __init__(self):
        self.sent = []
        self.reply = {"status": True, "detail": "success! message in queue"}
        self.fail = None

    def client(self, *a, **k):
        fake = self

        class _C:
            async def __aenter__(self):
                return self

            async def __aexit__(self, *a):
                return False

            async def post(self, url, headers=None, data=None, **kw):
                if fake.fail:
                    raise fake.fail
                fake.sent.append((url, headers, data))
                return _Resp(fake.reply)

        return _C()

    def last_code(self):
        return re.search(r"\*(\d{6})\*", self.sent[-1][2]["message"]).group(1)


class _Resp:
    status_code = 200

    def __init__(self, body):
        self._body = body

    def json(self):
        return self._body


@pytest.fixture()
def env(monkeypatch):
    server.db = AsyncMongoMockClient()["test_admin_otp"]
    server._login_fails.clear()
    fake = FakeFonnte()
    monkeypatch.setattr(server.httpx, "AsyncClient", fake.client)
    monkeypatch.setenv("FONNTE_TOKEN", "fonnte-test-token")
    monkeypatch.setenv("OWNER_PHONES", f"{OWNER}, +62 811-1111-111")
    with TestClient(server.app) as c:
        yield c, fake


def request_otp(c, phone=OWNER):
    return c.post("/api/admin/request-otp", json={"phone": phone})


def test_normalize_phone():
    assert server.normalize_phone("0812-3456-7890") == "6281234567890"
    assert server.normalize_phone("+62 812 3456 7890") == "6281234567890"
    assert server.normalize_phone("81234567890") == "6281234567890"


def test_owner_phones_parses_env(env):
    assert server.owner_phones() == {"6281234567890", "628111111111"}


def test_full_login_flow_creates_admin_session(env):
    c, fake = env
    r = request_otp(c, "+62 812-3456-7890")  # any format of a listed number
    assert r.status_code == 200, r.text
    assert r.json()["ok"] is True and "•" in r.json()["phone"]
    url, headers, data = fake.sent[-1]
    assert url == "https://api.fonnte.com/send"
    assert headers == {"Authorization": "fonnte-test-token"}
    assert data["target"] == "6281234567890" and data["countryCode"] == "62"
    code = fake.last_code()
    # Only a hash is stored, never the code itself.
    doc = c.portal.call(server.db.admin_otps.find_one, {"phone": "6281234567890"})
    assert code not in str(doc)

    r = c.post("/api/admin/verify-otp", json={"phone": OWNER, "code": code})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["role"] == "admin" and body["session_token"] and body["phone"] == "6281234567890"
    me = c.get("/api/auth/me", headers={"Authorization": f"Bearer {body['session_token']}"}).json()
    assert me["role"] == "admin"
    assert c.get("/api/admin/stats", headers={"Authorization": f"Bearer {body['session_token']}"}).status_code == 200
    # One-time use.
    assert c.post("/api/admin/verify-otp", json={"phone": OWNER, "code": code}).status_code == 401


def test_second_login_reuses_same_owner_account(env):
    c, fake = env
    ids = []
    for _ in range(2):
        c.portal.call(server.db.admin_otps.update_one, {"phone": "6281234567890"}, {"$unset": {"last_sent_at": ""}})
        request_otp(c)
        ids.append(c.post("/api/admin/verify-otp", json={"phone": OWNER, "code": fake.last_code()}).json()["user_id"])
    assert ids[0] == ids[1]


def test_unregistered_number_is_rejected_and_nothing_sent(env):
    c, fake = env
    r = request_otp(c, "089999999999")
    assert r.status_code == 403 and r.json()["detail"] == "Nomor ini tidak terdaftar sebagai Admin Pusat"
    assert fake.sent == []
    assert c.post("/api/admin/verify-otp", json={"phone": "089999999999", "code": "123456"}).status_code == 401


def test_wrong_code_attempt_limit(env):
    c, fake = env
    request_otp(c)
    code = fake.last_code()
    wrong = "000000" if code != "000000" else "111111"
    for i in range(server.OTP_MAX_ATTEMPTS - 1):
        r = c.post("/api/admin/verify-otp", json={"phone": OWNER, "code": wrong})
        assert r.status_code == 401 and "Sisa" in r.json()["detail"]
    r = c.post("/api/admin/verify-otp", json={"phone": OWNER, "code": wrong})
    assert r.status_code == 429
    # The OTP is burned: even the right code no longer works.
    assert c.post("/api/admin/verify-otp", json={"phone": OWNER, "code": code}).status_code == 401


def test_expired_code(env):
    c, fake = env
    request_otp(c)
    code = fake.last_code()
    c.portal.call(server.db.admin_otps.update_one, {"phone": "6281234567890"},
                  {"$set": {"expires_at": server.now() - timedelta(seconds=1)}})
    r = c.post("/api/admin/verify-otp", json={"phone": OWNER, "code": code})
    assert r.status_code == 401 and "kedaluwarsa" in r.json()["detail"]


def test_resend_cooldown_and_hourly_limit(env):
    c, fake = env
    assert request_otp(c).status_code == 200
    r = request_otp(c)
    assert r.status_code == 429 and "Tunggu" in r.json()["detail"]
    for _ in range(server.OTP_MAX_PER_HOUR - 1):
        c.portal.call(server.db.admin_otps.update_one, {"phone": "6281234567890"}, {"$unset": {"last_sent_at": ""}})
        assert request_otp(c).status_code == 200
    c.portal.call(server.db.admin_otps.update_one, {"phone": "6281234567890"}, {"$unset": {"last_sent_at": ""}})
    r = request_otp(c)
    assert r.status_code == 429 and "1 jam" in r.json()["detail"]
    assert len(fake.sent) == server.OTP_MAX_PER_HOUR


def test_fonnte_failure_returns_502_and_stores_nothing(env):
    c, fake = env
    fake.reply = {"status": False, "reason": "invalid token"}
    r = request_otp(c)
    assert r.status_code == 502
    assert c.portal.call(server.db.admin_otps.find_one, {"phone": "6281234567890"}) is None
    fake.reply = {"status": True}
    fake.fail = RuntimeError("network down")
    assert request_otp(c).status_code == 502


def test_not_configured(env, monkeypatch):
    c, _ = env
    monkeypatch.delenv("FONNTE_TOKEN")
    assert request_otp(c).status_code == 503


def test_bad_code_format_rejected(env):
    c, _ = env
    assert c.post("/api/admin/verify-otp", json={"phone": OWNER, "code": "12ab56"}).status_code == 422


def test_owner_login_sets_is_owner(env):
    c, fake = env
    request_otp(c)
    body = c.post("/api/admin/verify-otp", json={"phone": OWNER, "code": fake.last_code()}).json()
    assert body["is_owner"] is True and body["user"]["is_owner"] is True


def test_sync_version_bumps_after_writes_only(env):
    c, fake = env
    v0 = c.get("/api/sync").json()["v"]
    assert isinstance(v0, int) and v0 >= 1
    c.get("/api/sync")
    assert c.get("/api/sync").json()["v"] == v0  # reads do not bump
    request_otp(c)  # successful POST
    v1 = c.get("/api/sync").json()["v"]
    assert v1 > v0
    request_otp(c, "089999999999")  # 403 → no bump
    assert c.get("/api/sync").json()["v"] == v1
