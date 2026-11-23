# Owner Control Center: campaign CRUD + budget/brand balance, suspend, balance adjust, ledger, audit, sync.
#   pytest tests/test_owner_admin.py -n 0
import os
import sys
from datetime import timedelta
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_owner")
os.environ["KOMERCE_RECONCILE_SECONDS"] = "0"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

server.RECONCILE_SECONDS = 0
O = {"Authorization": "Bearer tok_owner"}
M = {"Authorization": "Bearer tok_mod"}  # moderation admin (Google), not owner
B = {"Authorization": "Bearer tok_brand"}
C = {"Authorization": "Bearer tok_creator"}

# Campaign gerakan (aksi relawan) buatan Owner: tanpa brand, rate, budget, minimal views.
AKSI = {"title": "Sebarkan Video Kegiatan", "category": "Sebar Narasi", "platforms": ["tiktok", "facebook"],
        "target_actions": ["share", "komentar"], "thumbnail": "", "instructions": "Bagikan video ke akunmu.",
        "exclusive": False}


@pytest.fixture()
def c():
    server.db = AsyncMongoMockClient()["test_owner"]
    with TestClient(server.app) as client:
        users = [
            server.new_user_doc("owner", "owner@x.id", "Owner", role="admin", is_owner=True),
            server.new_user_doc("mod", "mod@x.id", "Moderator", role="admin"),
            server.new_user_doc("brand", "brand@x.id", "Brand", role="brand", brand_balance=3_000_000,
                                profile={"brand_name": "Kopi Kita"}),
            server.new_user_doc("creator", "creator@x.id", "Ani", role="creator", balance=200_000),
        ]
        for u in users:
            client.portal.call(server.db.users.insert_one, u)
            client.portal.call(server.db.user_sessions.insert_one, {
                "user_id": u["user_id"], "session_token": f"tok_{u['user_id']}",
                "expires_at": server.now() + timedelta(days=1), "created_at": server.now()})
        yield client


def me(c, h):
    return c.get("/api/auth/me", headers=h).json()


def audit(c):
    return c.get("/api/admin/audit", headers=O).json()


def create(c, **kw):
    r = c.post("/api/admin/campaigns", json={**AKSI, **kw}, headers=O)
    assert r.status_code == 200, r.text
    return r.json()


def legacy(c, budget=1_000_000):
    """Campaign brand lama (dibuat sebelum mode gerakan): budget sudah dipotong dari saldo brand."""
    cid = server.gen_id("cmp")
    c.portal.call(server.db.campaigns.insert_one, {
        "campaign_id": cid, "brand_id": "brand", "brand_name": "Kopi Kita", "title": "Kopi Susu Viral", "category": "F&B",
        "platforms": ["tiktok"], "rate_per_1k": 5000, "min_views": 1000, "budget": budget, "spent": 0, "thumbnail": "",
        "instructions": "Buat video 30 detik.", "exclusive": False, "status": "active", "funded_by": "brand",
        "submission_count": 0, "total_views": 0, "deadline": (server.now() + timedelta(days=30)).isoformat(),
        "created_at": server.iso()})
    c.portal.call(server.db.users.update_one, {"user_id": "brand"}, {"$inc": {"brand_balance": -budget}})
    return cid


# ---------------- access ----------------
def test_owner_only_endpoints_reject_moderators_and_others(c):
    for h in (M, B, C):
        assert c.post("/api/admin/campaigns", json=AKSI, headers=h).status_code == 403
        assert c.patch("/api/admin/users/creator", json={"verified": True}, headers=h).status_code == 403
        assert c.post("/api/admin/users/creator/balance", json={"field": "balance", "delta": 1, "note": "abc"},
                      headers=h).status_code == 403
        assert c.get("/api/admin/audit", headers=h).status_code == 403
    assert c.get("/api/admin/users/creator/ledger", headers=M).status_code == 200  # moderators may read
    assert c.get("/api/admin/users/creator/ledger", headers=C).status_code == 403


# ---------------- campaigns ----------------
def test_create_aksi_tanpa_brand_rate_budget(c):
    cmp = create(c, rate_per_1k=5000, budget=1_000_000, brand_id="brand")  # field komersial lama diabaikan
    assert cmp["kind"] == "aksi" and cmp["brand_name"] == "Gibran for 2029" and cmp["funded_by"] == "owner"
    assert cmp["rate_per_1k"] == 0 and cmp["budget"] == 0 and cmp["min_views"] == 0 and cmp["budget_left_pct"] == 0
    assert cmp["target_actions"] == ["share", "komentar"] and cmp["platforms"] == ["tiktok", "facebook"]
    assert me(c, B)["brand_balance"] == 3_000_000  # saldo brand tidak tersentuh
    assert audit(c)[0]["action"] == "campaign.create"
    assert any(x["campaign_id"] == cmp["campaign_id"] for x in c.get("/api/campaigns").json())  # tampil untuk semua


def test_create_aksi_validasi(c):
    assert c.post("/api/admin/campaigns", json={**AKSI, "category": "F&B"}, headers=O).status_code == 400
    assert c.post("/api/admin/campaigns", json={**AKSI, "target_actions": []}, headers=O).status_code == 422
    assert c.post("/api/admin/campaigns", json={**AKSI, "target_actions": ["views"]}, headers=O).status_code == 422
    assert c.post("/api/admin/campaigns", json={**AKSI, "platforms": ["myspace"]}, headers=O).status_code == 422
    for cat in server.GERAKAN_CATEGORIES:
        assert c.post("/api/admin/campaigns", json={**AKSI, "category": cat}, headers=O).status_code == 200


def test_update_aksi_dan_tutup_read_only(c):
    cid = create(c)["campaign_id"]
    body = {**AKSI, "title": "Hadiri Konsolidasi", "category": "Agenda", "target_actions": ["kehadiran"],
            "deadline": "2030-01-31T16:59:00.000Z"}
    r = c.put(f"/api/admin/campaigns/{cid}", json=body, headers=O)
    assert r.status_code == 200, r.text
    assert r.json()["target_actions"] == ["kehadiran"] and r.json()["deadline"].startswith("2030-01-31")
    assert c.put(f"/api/admin/campaigns/{cid}", json={**body, "target_actions": []}, headers=O).status_code == 422
    assert audit(c)[0]["action"] == "campaign.edit"
    c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "closed"}, headers=O)
    assert c.put(f"/api/admin/campaigns/{cid}", json=body, headers=O).status_code == 400


def test_update_campaign_brand_lama_tidak_mengubah_budget(c):
    cid = legacy(c)  # brand 2.000.000
    r = c.put(f"/api/admin/campaigns/{cid}", json={**AKSI, "category": "F&B", "target_actions": None, "budget": 9_000_000}, headers=O)
    assert r.status_code == 200, r.text
    assert r.json()["budget"] == 1_000_000 and me(c, B)["brand_balance"] == 2_000_000


def test_aksi_tidak_tertutup_otomatis_setelah_setoran_disetujui(c):
    cid = create(c)["campaign_id"]
    c.portal.call(server.db.submissions.insert_one, {
        "submission_id": "sub_a", "campaign_id": cid, "campaign_title": AKSI["title"], "brand_id": "gibran2029",
        "creator_id": "creator", "creator_name": "Ani", "platform": "tiktok", "video_url": "https://tiktok.com/@a/video/9",
        "status": "diproses", "claimed_views": 10, "verified_views": 0, "payout": 0, "rate_per_1k": 0, "min_views": 0, "note": ""})
    r = c.post("/api/submissions/sub_a/verify", json={"action": "approve", "verified_views": 10}, headers=O)
    assert r.status_code == 200, r.text
    assert r.json()["payout"] == 0
    assert c.get(f"/api/campaigns/{cid}").json()["status"] == "active"


def test_pause_resume_close_refunds_unspent(c):
    cid = legacy(c)
    c.portal.call(server.db.campaigns.update_one, {"campaign_id": cid}, {"$set": {"spent": 250_000}})
    assert c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "paused"}, headers=O).status_code == 200
    assert not any(x["campaign_id"] == cid for x in c.get("/api/campaigns").json())
    assert c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "active"}, headers=M).status_code == 200
    r = c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "closed"}, headers=O)
    assert r.json()["refund"] == 750_000 and me(c, B)["brand_balance"] == 2_750_000
    assert [a["action"] for a in audit(c)][:2] == ["campaign.status", "campaign.status"]  # moderator's resume not logged


def test_delete_closes_refunds_and_hides(c):
    cid = legacy(c)
    r = c.delete(f"/api/admin/campaigns/{cid}", headers=O)
    assert r.status_code == 200 and r.json()["refund"] == 1_000_000
    assert me(c, B)["brand_balance"] == 3_000_000
    assert c.get(f"/api/campaigns/{cid}").status_code == 404
    assert not any(x["campaign_id"] == cid for x in c.get("/api/admin/campaigns", headers=O).json())
    assert not any(x["campaign_id"] == cid for x in c.get("/api/brand/campaigns", headers=B).json())
    assert audit(c)[0]["action"] == "campaign.delete"
    assert c.delete(f"/api/admin/campaigns/{cid}", headers=O).status_code == 404


# ---------------- users ----------------
def test_suspend_logs_out_blocks_and_reactivates(c):
    r = c.patch("/api/admin/users/creator", json={"status": "suspended", "suspend_reason": "Beli views"}, headers=O)
    assert r.status_code == 200 and r.json()["status"] == "suspended"
    res = c.get("/api/auth/me", headers=C)
    assert res.status_code == 401  # session deleted → signed out of web & app
    # Even a fresh login is refused while suspended.
    with pytest.raises(Exception):
        c.portal.call(server.start_session, server.Response(), "creator")
    assert c.patch("/api/admin/users/creator", json={"status": "suspended"}, headers=O).status_code == 400  # reason required
    assert c.patch("/api/admin/users/creator", json={"status": "active"}, headers=O).json()["status"] == "active"
    body = c.portal.call(server.start_session, server.Response(), "creator")
    assert body["session_token"]
    assert [a["detail"].get("status") for a in audit(c)][:2] == ["active", "suspended"]


def test_cannot_change_owner_accounts(c):
    assert c.patch("/api/admin/users/owner", json={"status": "suspended", "suspend_reason": "x y z"}, headers=O).status_code == 400


def test_verify_flag(c):
    assert c.patch("/api/admin/users/brand", json={"verified": True}, headers=O).json()["verified"] is True


def test_balance_adjust_with_note_and_never_negative(c):
    r = c.post("/api/admin/users/creator/balance", json={"field": "balance", "delta": 50_000, "note": "Bonus Oktober"}, headers=O)
    assert r.status_code == 200 and r.json()["balance"] == 250_000
    r = c.post("/api/admin/users/creator/balance", json={"field": "balance", "delta": -300_000, "note": "Koreksi"}, headers=O)
    assert r.status_code == 400 and "minus" in r.json()["detail"]
    assert me(c, C)["balance"] == 250_000
    assert c.post("/api/admin/users/creator/balance", json={"field": "balance", "delta": -250_000, "note": "Koreksi"},
                  headers=O).json()["balance"] == 0
    assert c.post("/api/admin/users/creator/balance", json={"field": "balance", "delta": 1, "note": ""}, headers=O).status_code == 422
    assert c.post("/api/admin/users/creator/balance", json={"field": "brand_balance", "delta": 1, "note": "abc"},
                  headers=O).status_code == 400
    led = c.get("/api/admin/users/creator/ledger", headers=O).json()
    assert [(x["type"], x["amount"], x["note"]) for x in led[:2]] == [("owner_adjust", -250_000, "Koreksi"),
                                                                      ("owner_adjust", 50_000, "Bonus Oktober")]
    assert audit(c)[0]["action"] == "user.balance" and audit(c)[0]["detail"]["after"] == 0


# ---------------- moderation audit + sync ----------------
def test_owner_withdrawal_approval_is_audited_and_bumps_sync(c):
    w = c.post("/api/withdrawals", json={"amount": 100_000, "method": "BCA", "account_number": "1234567890",
                                         "account_holder": "Ani"}, headers=C).json()
    v0 = c.get("/api/sync").json()["v"]
    r = c.post(f"/api/admin/withdrawals/{w['withdrawal_id']}", json={"action": "approve", "reference": "TRF-1"}, headers=O)
    assert r.status_code == 200
    assert c.get("/api/sync").json()["v"] > v0
    a = audit(c)[0]
    assert a["action"] == "withdrawal.approve" and a["detail"]["reference"] == "TRF-1"


def test_every_owner_write_bumps_sync(c):
    v = c.get("/api/sync").json()["v"]
    cid = create(c)["campaign_id"]
    for call in (lambda: c.put(f"/api/admin/campaigns/{cid}", json=AKSI, headers=O),
                 lambda: c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "paused"}, headers=O),
                 lambda: c.patch("/api/admin/users/creator", json={"verified": True}, headers=O),
                 lambda: c.post("/api/admin/users/creator/balance", json={"field": "balance", "delta": 1, "note": "abc"}, headers=O),
                 lambda: c.delete(f"/api/admin/campaigns/{cid}", headers=O)):
        assert call().status_code == 200
        nv = c.get("/api/sync").json()["v"]
        assert nv > v
        v = nv


def test_link_facebook_valid():
    assert server.valid_url("https://www.facebook.com/share/v/abc", "facebook")
    assert server.valid_url("https://fb.watch/xyz", "facebook")
    assert not server.valid_url("https://tiktok.com/@a/video/1", "facebook")
