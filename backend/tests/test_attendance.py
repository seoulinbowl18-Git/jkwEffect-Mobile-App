# Kehadiran Acara: pindai barcode KTA (nomor KTA) untuk verifikasi & pencatatan kehadiran.
#   pytest tests/test_attendance.py -n 0
import pytest

pytest.importorskip("mongomock_motor")
from tests.test_registrations import H, daftar, env, server  # noqa: E402,F401


def approve(c, who="warga_1", jenis="anggota", **over):
    rid = daftar(c, who, **({"jenis": jenis} | over)).json()["registration_id"]
    r = c.patch(f"/api/admin/registrations/{rid}", json={"status": "diterima"}, headers=H["admin_1"])
    assert r.status_code == 200, r.text
    return r.json()


def acara(c, cid="cmp_hadir", targets=("kehadiran",), status="active"):
    c.portal.call(server.db.campaigns.insert_one, {
        "campaign_id": cid, "kind": "aksi", "title": "Konsolidasi Relawan Solo", "category": "Agenda",
        "target_actions": list(targets), "status": status, "platforms": ["tiktok"], "deadline": server.iso()})
    return cid


def test_cek_kta_valid_dan_tidak_terdaftar(env):
    reg = approve(env)
    r = env.get(f"/api/admin/kta/{reg['kta_number'].lower()}", headers=H["admin_1"])  # huruf kecil tetap dikenali
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["valid"] and d["registration"]["nama"] == "Budi Santoso" and "user_id" not in d["registration"]
    assert "nik" not in d["registration"]
    assert env.get("/api/admin/kta/G2029-M-99-999999", headers=H["admin_1"]).status_code == 404
    assert env.get("/api/admin/kta/%3Cscript%3E", headers=H["admin_1"]).status_code == 422
    assert env.get(f"/api/admin/kta/{reg['kta_number']}", headers=H["warga_2"]).status_code == 403


def test_catat_kehadiran_sekali_per_orang(env):
    reg = approve(env)
    cid = acara(env)
    assert [e["campaign_id"] for e in env.get("/api/admin/attendance/events", headers=H["admin_1"]).json()] == [cid]
    r = env.post(f"/api/admin/campaigns/{cid}/attendance", json={"kta_number": reg["kta_number"]}, headers=H["admin_1"])
    assert r.status_code == 200, r.text
    assert r.json()["already"] is False and r.json()["registration"]["nama"] == "Budi Santoso"
    r2 = env.post(f"/api/admin/campaigns/{cid}/attendance", json={"kta_number": f" {reg['kta_number']} "}, headers=H["admin_1"])
    assert r2.json()["already"] is True
    lst = env.get(f"/api/admin/campaigns/{cid}/attendance", headers=H["admin_1"]).json()
    assert lst["total"] == 1 and lst["items"][0]["kta_number"] == reg["kta_number"]
    assert env.get("/api/admin/attendance/events", headers=H["admin_1"]).json()[0]["attendance_count"] == 1
    mine = env.get("/api/attendance/me", headers=H["warga_1"]).json()
    assert [m["campaign_title"] for m in mine] == ["Konsolidasi Relawan Solo"]
    notes = env.get("/api/notifications", headers=H["warga_1"]).json()
    assert any("Kehadiranmu tercatat" in n["body"] for n in (notes.get("items") if isinstance(notes, dict) else notes))
    # Batalkan salah catat
    aid = lst["items"][0]["attendance_id"]
    assert env.delete(f"/api/admin/campaigns/{cid}/attendance/{aid}", headers=H["admin_1"]).status_code == 200
    assert env.get(f"/api/admin/campaigns/{cid}/attendance", headers=H["admin_1"]).json()["total"] == 0
    assert env.get("/api/admin/attendance/events", headers=H["admin_1"]).json()[0]["attendance_count"] == 0


def test_kehadiran_ditolak_untuk_kta_tidak_aktif_dan_acara_salah(env):
    reg = approve(env)
    env.patch(f"/api/admin/registrations/{reg['registration_id']}", json={"status": "ditolak", "note": "data salah"}, headers=H["admin_1"])
    cid = acara(env)
    r = env.post(f"/api/admin/campaigns/{cid}/attendance", json={"kta_number": reg["kta_number"]}, headers=H["admin_1"])
    assert r.status_code == 400 and "tidak aktif" in r.text
    assert env.get(f"/api/admin/kta/{reg['kta_number']}", headers=H["admin_1"]).json()["valid"] is False
    share = acara(env, "cmp_share", targets=("share",))
    assert env.post(f"/api/admin/campaigns/{share}/attendance", json={"kta_number": reg["kta_number"]}, headers=H["admin_1"]).status_code == 400
    paused = acara(env, "cmp_paused", status="paused")
    reg2 = approve(env, "warga_2", jenis="relawan", nik="3372010190000999")
    assert env.post(f"/api/admin/campaigns/{paused}/attendance", json={"kta_number": reg2["kta_number"]}, headers=H["admin_1"]).status_code == 400
    assert env.post(f"/api/admin/campaigns/{cid}/attendance", json={"kta_number": reg2["kta_number"]}, headers=H["warga_1"]).status_code == 403
