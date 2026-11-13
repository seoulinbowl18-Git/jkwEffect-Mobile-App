# Klaim views dengan bukti (screenshot / rekaman layar analitik) dan akses bukti bertanda tangan.
#   pytest tests/test_claim_proof.py -n 0
import os
import sys
from datetime import timedelta
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_claim_proof")
os.environ["KOMERCE_RECONCILE_SECONDS"] = "0"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

server.RECONCILE_SECONDS = 0
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
MP4 = b"\x00\x00\x00\x18ftypmp42" + bytes(range(256)) * 4
H = {u: {"Authorization": f"Bearer tok_{u}"} for u in ("brand_1", "brand_2", "creator_1", "creator_2", "admin_1", "owner_1")}


@pytest.fixture()
def env():
    server.db = AsyncMongoMockClient()["test_claim_proof"]
    with TestClient(server.app) as c:
        for uid, role in (("brand_1", "brand"), ("brand_2", "brand"), ("creator_1", "creator"),
                          ("creator_2", "creator"), ("admin_1", "admin"), ("owner_1", "admin")):
            c.portal.call(server.db.users.insert_one,
                          server.new_user_doc(uid, f"{uid}@x.id", uid, role=role, is_owner=uid == "owner_1"))
            c.portal.call(server.db.user_sessions.insert_one, {
                "user_id": uid, "session_token": f"tok_{uid}",
                "expires_at": server.now() + timedelta(days=1), "created_at": server.now()})
        c.portal.call(server.db.campaigns.insert_one, {
            "campaign_id": "cmp_1", "brand_id": "brand_1", "title": "Kopi", "status": "active", "budget": 1_000_000,
            "spent": 0, "rate_per_1k": 10_000, "min_views": 1000, "platforms": ["tiktok"], "total_views": 0})
        c.portal.call(server.db.submissions.insert_one, {
            "submission_id": "sub_1", "campaign_id": "cmp_1", "campaign_title": "Kopi", "brand_id": "brand_1",
            "creator_id": "creator_1", "creator_name": "creator_1", "platform": "tiktok",
            "video_url": "https://tiktok.com/@a/video/1", "status": "menunggu_views", "claimed_views": 0,
            "verified_views": 0, "payout": 0, "rate_per_1k": 10_000, "min_views": 1000, "note": ""})
        yield c


def claim(c, files, views=5000, who="creator_1", note=""):
    return c.post("/api/submissions/sub_1/claim-proof", data={"views": str(views), "note": note},
                  files=[("files", f) for f in files], headers=H[who])


def test_old_claim_without_proof_is_refused(env):
    r = env.post("/api/submissions/sub_1/claim", json={"views": 5000}, headers=H["creator_1"])
    assert r.status_code == 400 and "bukti" in r.json()["detail"]


def test_claim_with_image_and_video(env):
    r = claim(env, [("a.png", PNG, "image/png"), ("rec.mp4", MP4, "video/mp4")], note="views per hari ini")
    assert r.status_code == 200, r.text
    kinds = [p["kind"] for p in r.json()["proofs"]]
    assert kinds == ["image", "video"]
    s = env.get("/api/creator/submissions", headers=H["creator_1"]).json()[0]
    assert s["status"] == "diproses" and s["claimed_views"] == 5000 and s["claim_note"] == "views per hari ini"
    assert len(s["proofs"]) == 2 and all(p["url"].startswith("/api/proofs/prf_") for p in s["proofs"])
    # Admin Pusat (Owner) mendapat URL bukti; brand & admin non-owner tidak bisa melihat daftar.
    a = env.get("/api/admin/submissions", headers=H["owner_1"]).json()[0]
    assert a["proofs"][0]["url"] and a["proofs"][1]["url"]
    assert env.get("/api/brand/submissions", headers=H["brand_1"]).status_code == 403
    assert env.get("/api/admin/submissions", headers=H["admin_1"]).status_code == 403
    img = env.get(s["proofs"][0]["url"])
    assert img.status_code == 200 and img.content == PNG and img.headers["content-type"] == "image/png"
    vid = env.get(s["proofs"][1]["url"], headers={"Range": "bytes=0-9"})
    assert vid.status_code == 206 and vid.content == MP4[:10]
    assert vid.headers["content-range"] == f"bytes 0-9/{len(MP4)}"


def test_proof_links_need_valid_signature(env):
    s = claim(env, [("a.png", PNG, "image/png")]).json()["proofs"][0]
    pid = s["proof_id"]
    assert env.get(f"/api/proofs/{pid}").status_code == 403
    assert env.get(s["url"].replace("sig=", "sig=0")).status_code == 403
    exp = 1000  # sudah lewat
    assert env.get(f"/api/proofs/{pid}?exp={exp}&sig={server.proof_sig(pid, exp)}").status_code == 403
    # Bukti tidak bocor lewat endpoint gambar publik.
    assert env.get(f"/api/uploads/{pid}").status_code == 404


@pytest.mark.parametrize("files,status,msg", [
    ([], 400, None),
    ([("x.txt", b"hello world", "text/plain")], 400, "gambar"),
    ([("a.png", PNG, "image/png")] * 4, 400, "Maksimal"),
    ([("big.png", PNG + b"\x00" * server.MAX_PROOF_IMAGE_BYTES, "image/png")], 413, "3 MB"),
])
def test_claim_rejects_bad_proofs(env, files, status, msg):
    r = claim(env, files)
    assert r.status_code in (status, 422), r.text
    if msg:
        assert msg in r.json()["detail"]
    s = env.get("/api/creator/submissions", headers=H["creator_1"]).json()[0]
    assert s["status"] == "menunggu_views"  # tidak berubah


def test_claim_rules(env):
    assert claim(env, [("a.png", PNG, "image/png")], views=10).json()["detail"] == "Views minimal 1000"
    assert claim(env, [("a.png", PNG, "image/png")], who="creator_2").status_code == 404
    assert claim(env, [("a.png", PNG, "image/png")]).status_code == 200
    again = claim(env, [("a.png", PNG, "image/png")])
    assert again.status_code == 400 and "belum bisa diklaim" in again.json()["detail"]


def test_verify_after_proof_claim_pays_creator(env):
    claim(env, [("a.png", PNG, "image/png")])
    r = env.post("/api/submissions/sub_1/verify", json={"action": "approve", "verified_views": 4000},
                 headers=H["owner_1"])
    assert r.status_code == 200 and r.json()["payout"] == 40_000
