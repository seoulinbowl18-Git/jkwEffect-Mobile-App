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

CAMPAIGN = {"title": "Kopi Susu Viral", "category": "F&B", "platforms": ["tiktok"], "rate_per_1k": 5000,
            "min_views": 1000, "budget": 1_000_000, "thumbnail": "", "instructions": "Buat video 30 detik.",
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
    r = c.post("/api/admin/campaigns", json={**CAMPAIGN, "brand_id": "brand", **kw}, headers=O)
    assert r.status_code == 200, r.text
    return r.json()


# ---------------- access ----------------
def test_owner_only_endpoints_reject_moderators_and_others(c):
    for h in (M, B, C):
        assert c.post("/api/admin/campaigns", json={**CAMPAIGN, "brand_id": "brand"}, headers=h).status_code == 403
        assert c.patch("/api/admin/users/creator", json={"verified": True}, headers=h).status_code == 403
        assert c.post("/api/admin/users/creator/balance", json={"field": "balance", "delta": 1, "note": "abc"},
                      headers=h).status_code == 403
        assert c.get("/api/admin/audit", headers=h).status_code == 403
    assert c.get("/api/admin/users/creator/ledger", headers=M).status_code == 200  # moderators may read
    assert c.get("/api/admin/users/creator/ledger", headers=C).status_code == 403


# ---------------- campaigns ----------------
def test_create_charging_brand_deducts_balance_and_logs(c):
    cmp = create(c, charge_brand=True)
    assert cmp["funded_by"] == "brand" and cmp["status"] == "active" and cmp["brand_name"] == "Kopi Kita"
    assert me(c, B)["brand_balance"] == 2_000_000
    ledger = c.get("/api/admin/users/brand/ledger", headers=O).json()
    assert ledger[0]["type"] == "campaign_budget" and ledger[0]["amount"] == -1_000_000
    assert audit(c)[0]["action"] == "campaign.create"
    assert any(x["campaign_id"] == cmp["campaign_id"] for x in c.get("/api/campaigns").json())  # live for everyone


def test_create_owner_funded_does_not_touch_brand_and_no_refund_on_close(c):
    cmp = create(c)
    assert cmp["funded_by"] == "owner" and me(c, B)["brand_balance"] == 3_000_000
    assert c.patch(f"/api/campaigns/{cmp['campaign_id']}/status", json={"status": "closed"}, headers=O).json()["refund"] == 0
    assert me(c, B)["brand_balance"] == 3_000_000


def test_create_rejects_insufficient_balance_unknown_or_suspended_brand(c):
    r = c.post("/api/admin/campaigns", json={**CAMPAIGN, "brand_id": "brand", "budget": 5_000_000, "charge_brand": True}, headers=O)
    assert r.status_code == 400 and "tidak cukup" in r.json()["detail"]
    assert me(c, B)["brand_balance"] == 3_000_000
    assert c.post("/api/admin/campaigns", json={**CAMPAIGN, "brand_id": "creator"}, headers=O).status_code == 404
    c.patch("/api/admin/users/brand", json={"status": "suspended", "suspend_reason": "Spam"}, headers=O)
    assert c.post("/api/admin/campaigns", json={**CAMPAIGN, "brand_id": "brand"}, headers=O).status_code == 400


def test_update_budget_adjusts_brand_balance_both_ways(c):
    cid = create(c, charge_brand=True)["campaign_id"]  # brand 2.000.000
    body = {**CAMPAIGN, "title": "Kopi Susu Viral 2", "budget": 1_500_000, "deadline": "2030-01-31T16:59:00.000Z"}
    r = c.put(f"/api/admin/campaigns/{cid}", json=body, headers=O)
    assert r.status_code == 200, r.text
    assert r.json()["budget"] == 1_500_000 and r.json()["deadline"].startswith("2030-01-31")
    assert me(c, B)["brand_balance"] == 1_500_000
    r = c.put(f"/api/admin/campaigns/{cid}", json={**body, "budget": 400_000}, headers=O)
    assert r.status_code == 200
    assert me(c, B)["brand_balance"] == 2_600_000
    types = [x["type"] for x in c.get("/api/admin/users/brand/ledger", headers=O).json()]
    assert types[:3] == ["campaign_refund", "campaign_budget", "campaign_budget"]
    a = audit(c)[0]
    assert a["action"] == "campaign.edit" and a["detail"]["budget"] == {"from": 1_500_000, "to": 400_000}


def test_update_budget_increase_needs_brand_balance(c):
    cid = create(c, charge_brand=True)["campaign_id"]  # brand 2.000.000
    r = c.put(f"/api/admin/campaigns/{cid}", json={**CAMPAIGN, "budget": 4_000_000}, headers=O)
    assert r.status_code == 400 and "tidak cukup" in r.json()["detail"]
    assert me(c, B)["brand_balance"] == 2_000_000
    assert c.get(f"/api/campaigns/{cid}").json()["budget"] == 1_000_000


def test_update_owner_funded_budget_never_touches_brand(c):
    cid = create(c)["campaign_id"]
    assert c.put(f"/api/admin/campaigns/{cid}", json={**CAMPAIGN, "budget": 9_000_000}, headers=O).status_code == 200
    assert me(c, B)["brand_balance"] == 3_000_000


def test_budget_cannot_go_below_spent_and_closed_is_read_only(c):
    cid = create(c, charge_brand=True)["campaign_id"]
    c.portal.call(server.db.campaigns.update_one, {"campaign_id": cid}, {"$set": {"spent": 300_000}})
    r = c.put(f"/api/admin/campaigns/{cid}", json={**CAMPAIGN, "budget": 200_000}, headers=O)
    assert r.status_code == 422 or (r.status_code == 400 and "terpakai" in r.json()["detail"])
    c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "closed"}, headers=O)
    assert c.put(f"/api/admin/campaigns/{cid}", json=CAMPAIGN, headers=O).status_code == 400


def test_pause_resume_close_refunds_unspent(c):
    cid = create(c, charge_brand=True)["campaign_id"]
    c.portal.call(server.db.campaigns.update_one, {"campaign_id": cid}, {"$set": {"spent": 250_000}})
    assert c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "paused"}, headers=O).status_code == 200
    assert not any(x["campaign_id"] == cid for x in c.get("/api/campaigns").json())
    assert c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "active"}, headers=M).status_code == 200
    r = c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "closed"}, headers=O)
    assert r.json()["refund"] == 750_000 and me(c, B)["brand_balance"] == 2_750_000
    assert [a["action"] for a in audit(c)][:2] == ["campaign.status", "campaign.status"]  # moderator's resume not logged


def test_delete_closes_refunds_and_hides(c):
    cid = create(c, charge_brand=True)["campaign_id"]
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
    cid = create(c, charge_brand=True)["campaign_id"]
    for call in (lambda: c.put(f"/api/admin/campaigns/{cid}", json=CAMPAIGN, headers=O),
                 lambda: c.patch(f"/api/admin/campaigns/{cid}/status", json={"status": "paused"}, headers=O),
                 lambda: c.patch("/api/admin/users/creator", json={"verified": True}, headers=O),
                 lambda: c.post("/api/admin/users/creator/balance", json={"field": "balance", "delta": 1, "note": "abc"}, headers=O),
                 lambda: c.delete(f"/api/admin/campaigns/{cid}", headers=O)):
        assert call().status_code == 200
        nv = c.get("/api/sync").json()["v"]
        assert nv > v
        v = nv
