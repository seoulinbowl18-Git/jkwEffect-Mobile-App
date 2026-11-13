# Logika finansial: fee top-up brand 10%, fee penarikan kreator 15%, penarikan saldo brand,
# escrow budget campaign + auto-refund (manual & otomatis saat deadline), mutasi saldo, pendapatan platform.
#   pytest tests/test_finance.py -n 0
import os
import sys
from datetime import timedelta
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_finance")
os.environ["KOMERCE_RECONCILE_SECONDS"] = "0"
os.environ["CAMPAIGN_EXPIRY_CHECK_SECONDS"] = "0"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

server.RECONCILE_SECONDS = 0
server.CAMPAIGN_EXPIRY_CHECK_SECONDS = 0
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
USERS = (("brand_1", "brand", {"brand_balance": 0}), ("creator_1", "creator", {"balance": 500_000}),
         ("owner_1", "admin", {"is_owner": True}))
H = {u: {"Authorization": f"Bearer tok_{u}"} for u, _, _ in USERS}
BANK = {"method": "BCA", "account_number": "1234567890", "account_holder": "Ani"}


@pytest.fixture()
def env():
    server.db = AsyncMongoMockClient()["test_finance"]
    with TestClient(server.app) as c:
        for uid, role, extra in USERS:
            c.portal.call(server.db.users.insert_one, server.new_user_doc(uid, f"{uid}@x.id", uid, role=role, **extra))
            c.portal.call(server.db.user_sessions.insert_one, {
                "user_id": uid, "session_token": f"tok_{uid}",
                "expires_at": server.now() + timedelta(days=1), "created_at": server.now()})
        yield c


def me(c, who):
    return c.get("/api/auth/me", headers=H[who]).json()


def ledger(c, who):
    return c.get("/api/ledger", headers=H[who]).json()


def pay_topup(c, amount):
    """Simulasikan top-up yang dibuat lewat Komerce lalu lunas (tanpa memanggil Komerce)."""
    q = server.topup_quote(amount)
    t = {"topup_id": f"TOP_{amount}", "brand_id": "brand_1", **q, "payment_type": "qris", "status": "pending",
         "created_at": server.iso()}
    c.portal.call(server.db.topups.insert_one, dict(t))
    c.portal.call(server.mark_topup_paid, t)
    c.portal.call(server.mark_topup_paid, t)  # callback ganda tidak boleh mengkredit dua kali
    return q


# ------------------------------------------------------------------ konfigurasi & pembulatan
def test_fee_config_is_public_and_defaults(env):
    assert env.get("/api/config/fees").json() == {"brand_topup_fee_pct": 10, "creator_withdraw_fee_pct": 15,
                                                  "brand_withdraw_fee_pct": 0, "min_topup": 10000, "min_withdraw": 50000}


@pytest.mark.parametrize("amount,bp,fee", [
    (1_000_000, 1000, 100_000), (250_000, 1000, 25_000), (333_333, 1000, 33_333), (10_005, 1000, 1_001),
    (100_000, 1500, 15_000), (66_667, 1500, 10_000), (50_003, 1500, 7_500), (123_456, 1250, 15_432), (0, 1500, 0),
])
def test_fee_rounding_is_integer_and_exact(amount, bp, fee):
    assert server.fee_amount(amount, bp) == fee


def test_fee_pct_from_env(monkeypatch):
    monkeypatch.setenv("X_FEE", "12,5%")
    assert server._pct_env("X_FEE", 10) == 1250
    monkeypatch.setenv("X_FEE", "abc")
    assert server._pct_env("X_FEE", 10) == 1000
    monkeypatch.setenv("X_FEE", "90")
    assert server._pct_env("X_FEE", 10) == 5000  # dibatasi 50%


def test_changed_fee_config_flows_to_quotes(env, monkeypatch):
    monkeypatch.setattr(server, "BRAND_TOPUP_FEE_BP", 1250)
    monkeypatch.setattr(server, "CREATOR_WITHDRAW_FEE_BP", 2000)
    assert env.get("/api/config/fees").json()["brand_topup_fee_pct"] == 12.5
    assert env.get("/api/brand/topups/quote?amount=1000000", headers=H["brand_1"]).json() == \
        {"amount": 1_000_000, "fee": 125_000, "fee_pct": 12.5, "total": 1_125_000}
    assert env.get("/api/withdrawals/quote?amount=100000", headers=H["creator_1"]).json() == \
        {"amount": 100_000, "fee": 20_000, "fee_pct": 20, "net_amount": 80_000}


# ------------------------------------------------------------------ top-up brand + fee 10%
def test_topup_quote_and_paid_topup_credits_only_net_amount(env):
    assert env.get("/api/brand/topups/quote?amount=1000000", headers=H["brand_1"]).json() == \
        {"amount": 1_000_000, "fee": 100_000, "fee_pct": 10, "total": 1_100_000}
    pay_topup(env, 1_000_000)
    assert me(env, "brand_1")["brand_balance"] == 1_000_000  # hanya Rp X, bukan X + 10%
    [entry] = ledger(env, "brand_1")
    assert (entry["type"], entry["amount"], entry["fee"], entry["total"]) == ("topup", 1_000_000, 100_000, 1_100_000)
    assert entry["label"] == "Top up saldo" and "Rp 1.100.000" in entry["note"]
    rev = env.get("/api/admin/revenue", headers=H["owner_1"]).json()
    assert rev["revenue_topup_fee"] == 100_000 and rev["platform_revenue"] == 100_000
    assert [(i["type"], i["amount"], i["base_amount"], i["fee_pct"]) for i in rev["items"]] == \
        [("topup_fee", 100_000, 1_000_000, 10)]


def test_legacy_topup_without_fee_still_credits(env):
    t = {"topup_id": "TOP_OLD", "brand_id": "brand_1", "amount": 200_000, "payment_type": "qris", "status": "pending",
         "created_at": server.iso()}
    env.portal.call(server.db.topups.insert_one, dict(t))
    env.portal.call(server.mark_topup_paid, t)
    assert me(env, "brand_1")["brand_balance"] == 200_000
    assert env.get("/api/admin/revenue", headers=H["owner_1"]).json()["platform_revenue"] == 0


def test_topup_minimum(env):
    r = env.post("/api/brand/topups", json={"amount": 5000, "payment_type": "qris"}, headers=H["brand_1"])
    assert r.status_code == 422


# ------------------------------------------------------------------ penarikan kreator + fee 15%
def test_creator_withdraw_fee_and_approve(env):
    r = env.post("/api/withdrawals", json={"amount": 200_000, **BANK}, headers=H["creator_1"])
    assert r.status_code == 200, r.text
    w = r.json()
    assert (w["amount"], w["fee"], w["fee_pct"], w["net_amount"], w["role"]) == (200_000, 30_000, 15, 170_000, "creator")
    assert me(env, "creator_1")["balance"] == 300_000  # dipotong penuh Rp Y
    [hold] = ledger(env, "creator_1")
    assert (hold["type"], hold["amount"], hold["fee"], hold["net_amount"]) == ("withdraw_hold", -200_000, 30_000, 170_000)
    assert env.post(f"/api/admin/withdrawals/{w['withdrawal_id']}", json={"action": "approve", "reference": "TRX1"},
                    headers=H["owner_1"]).status_code == 200
    rev = env.get("/api/admin/revenue", headers=H["owner_1"]).json()
    assert rev["revenue_withdraw_fee"] == 30_000
    note = env.get("/api/notifications", headers=H["creator_1"]).json()["items"][0]
    assert note["title"] == "Penarikan berhasil" and "Rp 170.000" in note["body"] and "Rp 30.000" in note["body"]


def test_creator_withdraw_reject_refunds_full_amount_without_revenue(env):
    w = env.post("/api/withdrawals", json={"amount": 100_000, **BANK}, headers=H["creator_1"]).json()
    env.post(f"/api/admin/withdrawals/{w['withdrawal_id']}", json={"action": "reject", "reference": "Rekening salah"},
             headers=H["owner_1"])
    assert me(env, "creator_1")["balance"] == 500_000
    assert [e["type"] for e in ledger(env, "creator_1")] == ["withdraw_refund", "withdraw_hold"]
    assert env.get("/api/admin/revenue", headers=H["owner_1"]).json()["platform_revenue"] == 0


def test_creator_withdraw_limits(env):
    assert env.post("/api/withdrawals", json={"amount": 40_000, **BANK}, headers=H["creator_1"]).status_code == 422
    r = env.post("/api/withdrawals", json={"amount": 600_000, **BANK}, headers=H["creator_1"])
    assert r.status_code == 400 and r.json()["detail"] == "Saldo tidak cukup"
    assert env.post("/api/withdrawals", json={"amount": 100_000, **BANK}, headers=H["brand_1"]).status_code == 403


# ------------------------------------------------------------------ penarikan saldo brand
def test_brand_withdraw_from_brand_balance(env):
    pay_topup(env, 300_000)
    r = env.post("/api/brand/withdrawals", json={"amount": 120_000, **BANK}, headers=H["brand_1"])
    assert r.status_code == 200, r.text
    w = r.json()
    assert (w["role"], w["fee"], w["net_amount"]) == ("brand", 0, 120_000)
    assert me(env, "brand_1")["brand_balance"] == 180_000
    assert env.get("/api/brand/withdrawals", headers=H["brand_1"]).json()[0]["withdrawal_id"] == w["withdrawal_id"]
    # Ditolak → kembali ke saldo BRAND (bukan saldo kreator).
    env.post(f"/api/admin/withdrawals/{w['withdrawal_id']}", json={"action": "reject"}, headers=H["owner_1"])
    u = me(env, "brand_1")
    assert u["brand_balance"] == 300_000 and u["balance"] == 0
    assert env.post("/api/brand/withdrawals", json={"amount": 400_000, **BANK}, headers=H["brand_1"]).status_code == 400
    assert env.post("/api/brand/withdrawals", json={"amount": 60_000, **BANK}, headers=H["creator_1"]).status_code == 403


# ------------------------------------------------------------------ escrow & auto-refund
def make_campaign(c, budget=500_000, days=30):
    r = c.post("/api/campaigns", json={"title": "Kopi", "category": "F&B", "platforms": ["tiktok"], "rate_per_1k": 10_000,
                                       "min_views": 1000, "budget": budget, "instructions": "Buat video 30 detik ya",
                                       "deadline_days": days}, headers=H["brand_1"])
    assert r.status_code == 200, r.text
    return r.json()


def pay_creator(c, cid, views):
    r = c.post("/api/submissions", json={"campaign_id": cid, "platform": "tiktok",
                                         "video_url": f"https://tiktok.com/@ani/video/{views}"}, headers=H["creator_1"])
    sid = r.json()["submission_id"]
    c.post(f"/api/submissions/{sid}/review", json={"action": "approve"}, headers=H["owner_1"])
    c.post(f"/api/submissions/{sid}/claim-proof", data={"views": str(views)},
           files=[("files", ("a.png", PNG, "image/png"))], headers=H["creator_1"])
    return c.post(f"/api/submissions/{sid}/verify", json={"action": "approve", "verified_views": views},
                  headers=H["owner_1"]).json()["payout"]


def test_escrow_spend_then_manual_close_refunds_rest(env):
    pay_topup(env, 1_000_000)
    c = make_campaign(env, budget=500_000)
    assert me(env, "brand_1")["brand_balance"] == 500_000  # budget dikunci
    assert pay_creator(env, c["campaign_id"], 12_000) == 120_000  # dipakai bertahap saat klaim disetujui
    assert me(env, "brand_1")["brand_balance"] == 500_000  # saldo utama tidak berubah, yang terpakai budget escrow
    r = env.patch(f"/api/campaigns/{c['campaign_id']}/status", json={"status": "closed"}, headers=H["brand_1"])
    assert r.json()["refund"] == 380_000
    assert me(env, "brand_1")["brand_balance"] == 880_000
    types = [(e["type"], e["amount"]) for e in ledger(env, "brand_1")]
    assert types == [("campaign_refund", 380_000), ("campaign_budget", -500_000), ("topup", 1_000_000)]
    assert ledger(env, "brand_1")[0]["label"] == "Sisa budget dikembalikan"
    # Sisa saldo bisa langsung dipakai lagi atau ditarik.
    assert env.post("/api/brand/withdrawals", json={"amount": 880_000, **BANK}, headers=H["brand_1"]).status_code == 200


def test_expired_campaign_auto_closes_and_refunds(env):
    pay_topup(env, 1_000_000)
    old = make_campaign(env, budget=400_000)
    new = make_campaign(env, budget=100_000)
    env.portal.call(server.db.campaigns.update_one, {"campaign_id": old["campaign_id"]},
                    {"$set": {"deadline": (server.now() - timedelta(minutes=1)).isoformat(), "status": "paused"}})
    assert env.portal.call(server.close_expired_campaigns) == 1
    assert env.portal.call(server.close_expired_campaigns) == 0  # idempoten
    camps = {c["campaign_id"]: c["status"] for c in env.get("/api/brand/campaigns", headers=H["brand_1"]).json()}
    assert camps == {old["campaign_id"]: "closed", new["campaign_id"]: "active"}
    assert me(env, "brand_1")["brand_balance"] == 500_000 + 400_000
    note = env.get("/api/notifications", headers=H["brand_1"]).json()["items"][0]
    assert note["title"] == "Campaign selesai" and "Rp 400.000" in note["body"]


def test_owner_funded_campaign_expiry_does_not_refund_brand(env):
    env.portal.call(server.db.campaigns.insert_one, {
        "campaign_id": "cmp_own", "brand_id": "brand_1", "title": "Owner", "status": "active", "budget": 300_000,
        "spent": 0, "funded_by": "owner", "deadline": (server.now() - timedelta(days=1)).isoformat()})
    assert env.portal.call(server.close_expired_campaigns) == 1
    assert me(env, "brand_1")["brand_balance"] == 0


def test_ledger_is_private_per_user(env):
    pay_topup(env, 100_000)
    assert ledger(env, "creator_1") == []
    assert len(ledger(env, "brand_1")) == 1
    assert env.get("/api/admin/revenue", headers=H["brand_1"]).status_code == 403
