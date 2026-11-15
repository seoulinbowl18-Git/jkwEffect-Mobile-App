# Pendaftaran Anggota / Relawan GIBRAN2029 (form web /daftar/{jenis}).
#   pytest tests/test_registrations.py -n 0
import os
import sys
from datetime import timedelta
from pathlib import Path

import pytest

pytest.importorskip("mongomock_motor")
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_registrations")
os.environ["KOMERCE_RECONCILE_SECONDS"] = "0"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

server.RECONCILE_SECONDS = 0
JPG = b"\xff\xd8\xff\xe0" + b"\x00" * 128
H = {u: {"Authorization": f"Bearer tok_{u}"} for u in ("warga_1", "warga_2", "admin_1", "creator_1")}
FORM = {
    "jenis": "anggota", "nik": "3372010190000123", "nama": "Budi Santoso", "kota_lahir": "Surakarta",
    "tanggal_lahir": "1990-05-17", "jenis_kelamin": "Laki-laki", "provinsi": "JAWA TENGAH", "provinsi_id": "33",
    "kabupaten": "KOTA SURAKARTA", "kecamatan": "LAWEYAN", "kelurahan": "PAJANG",
    "alamat": "Jl. Slamet Riyadi No. 12, RT 03/RW 05", "status_pernikahan": "Kawin", "telepon": "0812-3456-7890",
    "email": "Budi@Gmail.com", "referral": "", "persetujuan": "true",
}


@pytest.fixture()
def env():
    server.db = AsyncMongoMockClient()["test_registrations"]
    with TestClient(server.app) as c:
        for uid, role in (("warga_1", None), ("warga_2", None), ("admin_1", "admin"), ("creator_1", "creator")):
            c.portal.call(server.db.users.insert_one, server.new_user_doc(uid, f"{uid}@x.id", uid, role=role))
            c.portal.call(server.db.user_sessions.insert_one, {
                "user_id": uid, "session_token": f"tok_{uid}",
                "expires_at": server.now() + timedelta(days=1), "created_at": server.now()})
        yield c


def daftar(c, who="warga_1", file=("ktp.jpg", JPG, "image/jpeg"), **over):
    return c.post("/api/registrations", data={**FORM, **over}, files={"ktp": file}, headers=H[who])


def test_register_without_role_and_masks_nik(env):
    r = daftar(env)
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["jenis"] == "anggota" and d["status"] == "menunggu verifikasi"
    assert "nik" not in d and d["nik_masked"] == "337201******0123"
    mine = env.get("/api/registrations/me", headers=H["warga_1"]).json()
    assert len(mine) == 1 and "nik" not in mine[0] and "ktp_upload_id" not in mine[0]
    saved = env.portal.call(server.db.registrations.find_one, {"registration_id": d["registration_id"]})
    assert saved["telepon"] == "6281234567890" and saved["email"] == "budi@gmail.com"


def test_login_required(env):
    r = env.post("/api/registrations", data=FORM, files={"ktp": ("k.jpg", JPG, "image/jpeg")})
    assert r.status_code == 401


@pytest.mark.parametrize("over,msg", [
    ({"nik": "12345"}, "NIK"), ({"tanggal_lahir": "2015-01-01"}, "17 tahun"), ({"jenis_kelamin": "X"}, "Jenis kelamin"),
    ({"telepon": "12345"}, "WhatsApp"), ({"email": "bukan-email"}, "Email"), ({"persetujuan": "false"}, "persetujuan"),
    ({"jenis": "pengurus"}, "Jenis"), ({"alamat": "pendek"}, "Alamat"),
])
def test_validation(env, over, msg):
    r = daftar(env, **over)
    assert r.status_code == 422 and msg in r.json()["detail"]


def test_ktp_must_be_image_and_max_3mb(env):
    assert daftar(env, file=("ktp.pdf", b"%PDF-1.4 xxx", "application/pdf")).status_code == 400
    big = b"\xff\xd8\xff\xe0" + b"\x00" * (3 * 1024 * 1024)
    assert daftar(env, file=("big.jpg", big, "image/jpeg")).status_code == 413
    assert env.portal.call(server.db.registrations.count_documents, {}) == 0


def test_duplicates(env):
    assert daftar(env).status_code == 200
    assert daftar(env).status_code == 409  # akun sama, jenis sama
    assert daftar(env, who="warga_2").status_code == 409  # NIK sama, jenis sama
    assert daftar(env, jenis="relawan").status_code == 200  # boleh jadi anggota sekaligus relawan


def test_ktp_private_admin_only(env):
    rid = daftar(env).json()["registration_id"]
    reg = env.portal.call(server.db.registrations.find_one, {"registration_id": rid})
    assert env.get(f"/api/uploads/{reg['ktp_upload_id']}").status_code == 404  # tidak publik
    assert env.get(f"/api/admin/registrations/{rid}/ktp", headers=H["warga_1"]).status_code == 403
    assert env.get(f"/api/admin/registrations/{rid}/ktp", headers=H["creator_1"]).status_code == 403
    r = env.get(f"/api/admin/registrations/{rid}/ktp", headers=H["admin_1"])
    assert r.status_code == 200 and r.content == JPG and "no-store" in r.headers["cache-control"]


def test_admin_list_and_status(env):
    rid = daftar(env).json()["registration_id"]
    lst = env.get("/api/admin/registrations?jenis=anggota&q=budi", headers=H["admin_1"]).json()
    assert lst["total"] == 1 and lst["items"][0]["nik"] == FORM["nik"] and lst["items"][0]["has_ktp"]
    assert env.get("/api/admin/registrations", headers=H["warga_1"]).status_code == 403
    r = env.patch(f"/api/admin/registrations/{rid}", json={"status": "diterima"}, headers=H["admin_1"])
    assert r.status_code == 200 and r.json()["status"] == "diterima"
    assert env.get("/api/registrations/me", headers=H["warga_1"]).json()[0]["status"] == "diterima"


def test_duplicate_message_uses_member_label(env):
    assert daftar(env).status_code == 200
    r = daftar(env)
    assert r.status_code == 409 and "sebagai member" in r.json()["detail"]


def _approve(env, rid, status="diterima", note=""):
    return env.patch(f"/api/admin/registrations/{rid}", json={"status": status, "note": note}, headers=H["admin_1"])


def test_approve_issues_unique_kta_number_once(env):
    rid = daftar(env).json()["registration_id"]
    r = _approve(env, rid)
    assert r.status_code == 200
    kta = r.json()["kta_number"]
    assert kta == "G2029-M-33-000001" and r.json()["kta_issued_at"]
    assert _approve(env, rid).json()["kta_number"] == kta  # disetujui ulang: nomor tetap
    me = env.get("/api/registrations/me", headers=H["warga_1"]).json()[0]
    assert me["kta_number"] == kta and me["kabupaten"] == "KOTA SURAKARTA" and me["nik_masked"].endswith("0123")
    # Relawan punya urutan sendiri; provinsi manual (tanpa kode) -> 00
    rid2 = daftar(env, who="warga_2", jenis="relawan", nik="3172010190000999", provinsi_id="").json()["registration_id"]
    assert _approve(env, rid2).json()["kta_number"] == "G2029-R-00-000001"
    rid3 = daftar(env, who="warga_2", nik="3172010190000999").json()["registration_id"]
    assert _approve(env, rid3).json()["kta_number"] == "G2029-M-33-000002"
    notes = env.portal.call(lambda: server.db.notifications.find({"user_id": "warga_1"}).to_list(10))
    assert any(kta in n["body"] for n in notes)


def test_rejected_can_resubmit_and_others_cannot_approve(env):
    rid = daftar(env).json()["registration_id"]
    assert env.patch(f"/api/admin/registrations/{rid}", json={"status": "diterima"}, headers=H["creator_1"]).status_code == 403
    r = _approve(env, rid, "ditolak", "Foto KTP buram")
    assert r.status_code == 200 and "kta_number" not in r.json()
    me = env.get("/api/registrations/me", headers=H["warga_1"]).json()[0]
    assert me["status"] == "ditolak" and me["status_note"] == "Foto KTP buram"
    r2 = daftar(env)  # kirim ulang
    assert r2.status_code == 200 and r2.json()["registration_id"] != rid
    assert env.portal.call(server.db.registrations.count_documents, {"user_id": "warga_1"}) == 1
    assert env.portal.call(server.db.uploads.count_documents, {"kind": "ktp"}) == 1
    lst = env.get("/api/admin/registrations", headers=H["admin_1"]).json()
    assert lst["counts"] == {"menunggu verifikasi": 1, "diterima": 0, "ditolak": 0}
