# Social accounts (TikTok / Instagram / Threads) + Telegram community linking via the bot.
#   pytest tests/test_social.py -n 0
import os
import sys
from datetime import timedelta
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_social")
os.environ["KOMERCE_RECONCILE_SECONDS"] = "0"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

server.RECONCILE_SECONDS = 0
A = {"Authorization": "Bearer tok_ani"}
B = {"Authorization": "Bearer tok_budi"}
TOKEN = "123:ABC"


class FakeTelegram:
    def __init__(self):
        self.sent = []

    def client(self, *a, **k):
        fake = self

        class _C:
            async def __aenter__(self):
                return self

            async def __aexit__(self, *a):
                return False

            async def post(self, url, json=None, **kw):
                fake.sent.append((url.rsplit("/", 1)[-1], json))
                return _R()

        return _C()


class _R:
    status_code = 200

    def json(self):
        return {"ok": True}


@pytest.fixture()
def env(monkeypatch):
    server.db = AsyncMongoMockClient()["test_social"]
    tg = FakeTelegram()
    monkeypatch.setattr(server.httpx, "AsyncClient", tg.client)
    for k in ("TELEGRAM_BOT_TOKEN", "TELEGRAM_BOT_USERNAME", "TELEGRAM_GROUP_URL", "PUBLIC_BASE_URL", "RAILWAY_PUBLIC_DOMAIN"):
        monkeypatch.delenv(k, raising=False)
    with TestClient(server.app) as c:
        for uid in ("ani", "budi"):
            c.portal.call(server.db.users.insert_one, server.new_user_doc(uid, f"{uid}@x.id", uid.title(), role="creator"))
            c.portal.call(server.db.user_sessions.insert_one, {"user_id": uid, "session_token": f"tok_{uid}",
                                                               "expires_at": server.now() + timedelta(days=1), "created_at": server.now()})
        yield c, tg


@pytest.mark.parametrize("platform,raw,expected", [
    ("tiktok", "@Ani.Kreator", "ani.kreator"),
    ("tiktok", "https://www.tiktok.com/@ani_kreator?lang=id", "ani_kreator"),
    ("instagram", "instagram.com/ani.kreator/", "ani.kreator"),
    ("instagram", "https://www.instagram.com/ani.kreator/reels", "ani.kreator"),
    ("threads", "https://www.threads.net/@ani", "ani"),
    ("threads", "https://www.threads.com/@ani", "ani"),
    ("tiktok", "https://www.instagram.com/ani", None),  # wrong platform
    ("instagram", "ani kreator", None),
    ("instagram", ".ani", None),
    ("tiktok", "", None),
])
def test_parse_handle(platform, raw, expected):
    assert server.parse_social_handle(platform, raw) == expected


def test_link_update_unlink_social(env):
    c, _ = env
    assert c.get("/api/users/social", headers=A).json() == {"tiktok": None, "instagram": None, "threads": None, "telegram": None}
    r = c.put("/api/users/social/tiktok", json={"handle": "https://www.tiktok.com/@Ani.Kreator"}, headers=A)
    assert r.status_code == 200
    assert r.json()["tiktok"]["username"] == "ani.kreator" and r.json()["tiktok"]["url"] == "https://www.tiktok.com/@ani.kreator"
    assert c.get("/api/auth/me", headers=A).json()["profile"]["tiktok"] == "@ani.kreator"  # mobile app still reads this
    r = c.put("/api/users/social/tiktok", json={"handle": "@ani.baru"}, headers=A)  # update
    assert r.json()["tiktok"]["username"] == "ani.baru"
    assert c.put("/api/users/social/instagram", json={"handle": "not valid!"}, headers=A).status_code == 400
    assert c.put("/api/users/social/youtube", json={"handle": "ani"}, headers=A).status_code == 422
    r = c.delete("/api/users/social/tiktok", headers=A)
    assert r.json()["tiktok"] is None and "tiktok" not in c.get("/api/auth/me", headers=A).json()["profile"]


def test_same_account_cannot_be_linked_twice(env):
    c, _ = env
    c.put("/api/users/social/instagram", json={"handle": "ani.kreator"}, headers=A)
    r = c.put("/api/users/social/instagram", json={"handle": "@Ani.Kreator"}, headers=B)
    assert r.status_code == 409 and "pengguna lain" in r.json()["detail"]


def test_profile_form_keeps_social_and_legacy_fields_sync(env):
    c, _ = env
    c.put("/api/users/social/tiktok", json={"handle": "ani"}, headers=A)
    # Web profile form no longer sends tiktok/instagram → must not wipe them.
    c.put("/api/users/profile", json={"name": "Ani K", "bank_method": "BCA"}, headers=A)
    assert c.get("/api/users/social", headers=A).json()["tiktok"]["username"] == "ani"
    # Older app versions still edit them on the profile form → mirrored into social.
    c.put("/api/users/profile", json={"name": "Ani K", "instagram": "@ani.ig", "tiktok": ""}, headers=A)
    s = c.get("/api/users/social", headers=A).json()
    assert s["instagram"]["username"] == "ani.ig" and s["tiktok"] is None


def test_community_links(env, monkeypatch):
    c, _ = env
    assert c.get("/api/public/community").json() == {"telegram_url": "", "telegram_bot": "", "telegram_connect_enabled": False}
    monkeypatch.setenv("TELEGRAM_BOT_USERNAME", "@OurBuzzerBot")
    monkeypatch.setenv("TELEGRAM_GROUP_URL", "[https://t.me/+abcDEF](https://t.me/+abcDEF)")
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", TOKEN)
    assert c.get("/api/public/community").json() == {"telegram_url": "https://t.me/+abcDEF", "telegram_bot": "OurBuzzerBot",
                                                     "telegram_connect_enabled": True}


def test_telegram_link_flow(env, monkeypatch):
    c, tg = env
    assert c.post("/api/users/social/telegram/link", headers=A).status_code == 503  # not configured
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", TOKEN)
    monkeypatch.setenv("TELEGRAM_BOT_USERNAME", "OurBuzzerBot")
    monkeypatch.setenv("TELEGRAM_GROUP_URL", "https://t.me/+abcDEF")
    url = c.post("/api/users/social/telegram/link", headers=A).json()["url"]
    assert url.startswith("https://t.me/OurBuzzerBot?start=")
    code = url.split("=", 1)[1]
    secret = {"X-Telegram-Bot-Api-Secret-Token": server.telegram_webhook_secret(TOKEN)}
    upd = {"message": {"text": f"/start {code}", "chat": {"id": 555, "type": "private"},
                       "from": {"id": 555, "username": "ani_tg", "first_name": "Ani"}}}
    assert c.post("/api/telegram/webhook", json=upd).status_code == 403  # missing secret
    assert c.post("/api/telegram/webhook", json=upd, headers=secret).status_code == 200
    assert c.get("/api/users/social", headers=A).json()["telegram"]["username"] == "ani_tg"
    method, payload = tg.sent[-1]
    assert method == "sendMessage" and payload["chat_id"] == 555
    assert payload["reply_markup"]["inline_keyboard"][0][0]["url"] == "https://t.me/+abcDEF"  # group invite button
    # Code is single use.
    c.post("/api/telegram/webhook", json=upd, headers=secret)
    assert "kedaluwarsa" in tg.sent[-1][1]["text"]
    # The same Telegram account cannot be linked to a second user.
    code_b = c.post("/api/users/social/telegram/link", headers=B).json()["url"].split("=", 1)[1]
    c.post("/api/telegram/webhook", json={**upd, "message": {**upd["message"], "text": f"/start {code_b}"}}, headers=secret)
    assert "akun Gibran for 2029 lain" in tg.sent[-1][1]["text"]
    assert c.get("/api/users/social", headers=B).json()["telegram"] is None
    # Unlink.
    assert c.delete("/api/users/social/telegram", headers=A).json()["telegram"] is None


def test_telegram_expired_code(env, monkeypatch):
    c, tg = env
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", TOKEN)
    monkeypatch.setenv("TELEGRAM_BOT_USERNAME", "OurBuzzerBot")
    code = c.post("/api/users/social/telegram/link", headers=A).json()["url"].split("=", 1)[1]
    c.portal.call(server.db.telegram_links.update_one, {"code": code}, {"$set": {"expires_at": server.now() - timedelta(seconds=1)}})
    c.post("/api/telegram/webhook", headers={"X-Telegram-Bot-Api-Secret-Token": server.telegram_webhook_secret(TOKEN)},
           json={"message": {"text": f"/start {code}", "chat": {"id": 1, "type": "private"}, "from": {"id": 1}}})
    assert c.get("/api/users/social", headers=A).json()["telegram"] is None
    assert "kedaluwarsa" in tg.sent[-1][1]["text"]


def test_bot_token_never_logged(env, monkeypatch, caplog):
    import logging
    c, _ = env
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", TOKEN)
    caplog.set_level(logging.INFO)
    c.portal.call(server.telegram_send, 1, "hi")
    c.portal.call(server.setup_telegram_webhook, "https://api.ourbuzzer.test")
    assert TOKEN not in caplog.text
    assert logging.getLogger("httpx").getEffectiveLevel() >= logging.WARNING
