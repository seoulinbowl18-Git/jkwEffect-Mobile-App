# Mobile companion app API smoke tests using seeded tokens (test_session_creator / test_session_brand)
import os
import uuid
import pytest
import requests

BASE_URL = os.environ.get("EXPO_PUBLIC_BACKEND_URL").rstrip("/")
API = f"{BASE_URL}/api"


def s(tok):
    x = requests.Session()
    x.headers.update({"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})
    return x


C = s("test_session_creator")
B = s("test_session_brand")
STATE = {}


# Auth
def test_me_creator_and_brand():
    assert C.get(f"{API}/auth/me").json()["role"] == "creator"
    assert B.get(f"{API}/auth/me").json()["role"] == "brand"


def test_auth_firebase_invalid_returns_401():
    r = requests.post(f"{API}/auth/firebase", json={"id_token": "bogus"})
    assert r.status_code in (400, 401)


# Discovery
def test_sections_and_exclusive_filter():
    d = requests.get(f"{API}/campaigns/sections").json()
    assert d["total"] >= 1
    r = C.get(f"{API}/campaigns", params={"exclusive": "true"})
    assert r.status_code == 200 and isinstance(r.json(), list)


# Brand campaign -> creator submit -> review -> claim -> verify -> close refund
def test_full_flow():
    bal_b0 = B.get(f"{API}/auth/me").json()["brand_balance"]
    r = B.post(f"{API}/campaigns", json={"title": "TEST_MobileCamp", "category": "Beauty", "platforms": ["tiktok"],
                                         "rate_per_1k": 10000, "min_views": 1000, "budget": 100000,
                                         "instructions": "Buat video jujur tentang produk ini.", "exclusive": False,
                                         "deadline_days": 7})
    assert r.status_code == 200, r.text
    cid = r.json()["campaign_id"]
    STATE["cid"] = cid
    assert B.get(f"{API}/auth/me").json()["brand_balance"] == bal_b0 - 100000
    url = f"https://www.tiktok.com/@test_{uuid.uuid4().hex[:6]}/video/{uuid.uuid4().int % 10**12}"
    r = C.post(f"{API}/submissions", json={"campaign_id": cid, "platform": "tiktok", "video_url": url})
    assert r.status_code == 200, r.text
    sid = r.json()["submission_id"]
    dup = C.post(f"{API}/submissions", json={"campaign_id": cid, "platform": "tiktok", "video_url": url})
    assert dup.status_code == 400
    bad = C.post(f"{API}/submissions", json={"campaign_id": cid, "platform": "tiktok", "video_url": "https://youtube.com/x"})
    assert bad.status_code == 400
    assert B.post(f"{API}/submissions/{sid}/review", json={"action": "approve"}).status_code == 200
    assert C.post(f"{API}/submissions/{sid}/claim", json={"views": 500}).status_code == 400
    assert C.post(f"{API}/submissions/{sid}/claim", json={"views": 2000}).status_code == 200
    bal_c0 = C.get(f"{API}/auth/me").json()["balance"]
    r = B.post(f"{API}/submissions/{sid}/verify", json={"action": "approve", "verified_views": 2000})
    assert r.status_code == 200 and r.json()["payout"] == 20000
    assert C.get(f"{API}/auth/me").json()["balance"] == bal_c0 + 20000
    # pause/resume/close
    assert B.patch(f"{API}/campaigns/{cid}/status", json={"status": "paused"}).status_code == 200
    assert B.patch(f"{API}/campaigns/{cid}/status", json={"status": "active"}).status_code == 200
    r = B.patch(f"{API}/campaigns/{cid}/status", json={"status": "closed"})
    assert r.status_code == 200, r.text
    assert B.get(f"{API}/auth/me").json()["brand_balance"] == bal_b0 - 20000
    # revert creator balance for clean seed
    STATE["earned"] = 20000


def test_withdraw_min_validation():
    r = C.post(f"{API}/withdrawals", json={"amount": 10000, "method": "BCA", "account_number": "12345678",
                                           "account_holder": "Test"})
    assert r.status_code == 422


def test_topup_qris():
    r = B.post(f"{API}/brand/topups", json={"amount": 100000, "payment_type": "qris"})
    print(r.status_code, r.text[:300])
    assert r.status_code in (200, 502)
    h = B.get(f"{API}/brand/topups")
    assert h.status_code == 200 and isinstance(h.json(), list)


def test_notifications():
    r = C.get(f"{API}/notifications")
    assert r.status_code == 200
