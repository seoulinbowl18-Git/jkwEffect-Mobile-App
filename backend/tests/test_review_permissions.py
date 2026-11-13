# Pemisahan peran: brand tidak ikut me-review konten; semua review, cek views & verifikasi
# bukti hanya oleh Admin Pusat (Owner); notifikasi hasil review hanya ke kreator.
#   pytest tests/test_review_permissions.py -n 0
import os
import sys
from datetime import timedelta
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_review_permissions")
os.environ["KOMERCE_RECONCILE_SECONDS"] = "0"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

server.RECONCILE_SECONDS = 0
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
USERS = (("brand_1", "brand", False), ("creator_1", "creator", False), ("creator_2", "creator", False),
         ("mod_1", "admin", False), ("owner_1", "admin", True))
H = {u: {"Authorization": f"Bearer tok_{u}"} for u, _, _ in USERS}


@pytest.fixture()
def env():
    server.db = AsyncMongoMockClient()["test_review_permissions"]
    with TestClient(server.app) as c:
        for uid, role, owner in USERS:
            c.portal.call(server.db.users.insert_one,
                          server.new_user_doc(uid, f"{uid}@x.id", uid, role=role, is_owner=owner))
            c.portal.call(server.db.user_sessions.insert_one, {
                "user_id": uid, "session_token": f"tok_{uid}",
                "expires_at": server.now() + timedelta(days=1), "created_at": server.now()})
        c.portal.call(server.db.campaigns.insert_one, {
            "campaign_id": "cmp_1", "brand_id": "brand_1", "title": "Kopi", "status": "active", "budget": 1_000_000,
            "spent": 100_000, "rate_per_1k": 10_000, "min_views": 1000, "platforms": ["tiktok"], "total_views": 10_000,
            "submission_count": 0, "created_at": server.iso()})
        yield c


def submit(c, who="creator_1", n=1):
    r = c.post("/api/submissions", json={"campaign_id": "cmp_1", "platform": "tiktok",
                                         "video_url": f"https://tiktok.com/@{who}/video/{n}"}, headers=H[who])
    assert r.status_code == 200, r.text
    return r.json()["submission_id"]


def notes(c, who):
    return [n["title"] + " | " + n["body"] for n in c.get("/api/notifications", headers=H[who]).json()["items"]]


def test_brand_cannot_review_verify_or_list_submissions(env):
    sid = submit(env)
    assert env.post(f"/api/submissions/{sid}/review", json={"action": "approve"}, headers=H["brand_1"]).status_code == 403
    assert env.post(f"/api/submissions/{sid}/review", json={"action": "reject"}, headers=H["brand_1"]).status_code == 403
    assert env.get("/api/brand/submissions", headers=H["brand_1"]).status_code == 403
    env.post(f"/api/submissions/{sid}/review", json={"action": "approve"}, headers=H["owner_1"])
    env.post(f"/api/submissions/{sid}/claim-proof", data={"views": "5000"},
             files=[("files", ("a.png", PNG, "image/png"))], headers=H["creator_1"])
    r = env.post(f"/api/submissions/{sid}/verify", json={"action": "approve", "verified_views": 5000}, headers=H["brand_1"])
    assert r.status_code == 403


def test_only_owner_reviews_moderation_admin_is_refused(env):
    sid = submit(env)
    assert env.post(f"/api/submissions/{sid}/review", json={"action": "approve"}, headers=H["mod_1"]).status_code == 403
    assert env.get("/api/admin/submissions", headers=H["mod_1"]).status_code == 403
    assert env.post(f"/api/submissions/{sid}/review", json={"action": "approve"}, headers=H["owner_1"]).status_code == 200
    env.post(f"/api/submissions/{sid}/claim-proof", data={"views": "5000"},
             files=[("files", ("a.png", PNG, "image/png"))], headers=H["creator_1"])
    assert env.post(f"/api/submissions/{sid}/verify", json={"action": "approve", "verified_views": 5000},
                    headers=H["mod_1"]).status_code == 403
    r = env.post(f"/api/submissions/{sid}/verify", json={"action": "approve", "verified_views": 5000}, headers=H["owner_1"])
    assert r.status_code == 200 and r.json()["payout"] == 50_000
    assert [s["status"] for s in env.get("/api/admin/submissions", headers=H["owner_1"]).json()] == ["disetujui"]


def test_notifications_go_to_owner_and_the_creator_only(env):
    sid = submit(env)
    other = submit(env, who="creator_2")
    assert any(n.startswith("Submission baru") for n in notes(env, "owner_1"))
    assert notes(env, "brand_1") == []
    assert notes(env, "mod_1") == []
    assert any("sedang direview" in n for n in notes(env, "creator_1"))

    env.post(f"/api/submissions/{sid}/review", json={"action": "approve"}, headers=H["owner_1"])
    env.post(f"/api/submissions/{other}/review", json={"action": "reject", "note": "Logo tidak terlihat"}, headers=H["owner_1"])
    c1, c2 = notes(env, "creator_1"), notes(env, "creator_2")
    assert any("siap diklaim" in n for n in c1) and not any("ditolak" in n for n in c1)
    assert any("Konten ditolak. Logo tidak terlihat" in n for n in c2) and not any("siap diklaim" in n for n in c2)

    env.post(f"/api/submissions/{sid}/claim-proof", data={"views": "5000"},
             files=[("files", ("a.png", PNG, "image/png"))], headers=H["creator_1"])
    assert any(n.startswith("Klaim views baru") for n in notes(env, "owner_1"))
    assert any("Views sedang dicek" in n for n in notes(env, "creator_1"))
    env.post(f"/api/submissions/{sid}/verify", json={"action": "approve", "verified_views": 5000}, headers=H["owner_1"])
    assert any("Views terverifikasi! +Rp 50.000" in n for n in notes(env, "creator_1"))
    assert not any("terverifikasi" in n for n in notes(env, "creator_2"))
    assert notes(env, "brand_1") == []


def test_old_review_notifications_hidden_from_brand(env):
    for title in ("Submission baru", "Klaim views baru", "Top up berhasil"):
        env.portal.call(server.notify, "brand_1", title, "x")
    r = env.get("/api/notifications", headers=H["brand_1"]).json()
    assert [n["title"] for n in r["items"]] == ["Top up berhasil"] and r["unread"] == 1


def test_brand_sees_general_campaign_data_only(env):
    submit(env)
    submit(env, n=2)
    submit(env, who="creator_2")
    stats = env.get("/api/brand/stats", headers=H["brand_1"]).json()
    assert stats == {"brand_balance": 0, "active": 1, "spent": 100_000, "views": 10_000,
                     "creators": 2, "budget_left": 900_000}
    [camp] = env.get("/api/brand/campaigns", headers=H["brand_1"]).json()
    assert camp["creator_count"] == 2 and camp["submission_count"] == 3 and camp["total_views"] == 10_000
