# Pemisahan database Gibran for 2029 dari data OurBuzzer lama: konfigurasi koneksi & skrip migrasi.
#   pytest tests/test_db_config.py -n 0
import os
import sys
from pathlib import Path

import pytest

mongomock = pytest.importorskip("mongomock")
os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_db_config")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import server  # noqa: E402
import migrate_to_gibran2029 as mig  # noqa: E402


@pytest.mark.parametrize("env,expected", [
    ({"MONGODB_URI": "mongodb+srv://u:p@c.mongodb.net/?retryWrites=true"}, ("mongodb+srv://u:p@c.mongodb.net/?retryWrites=true", "gibran2029_db")),
    ({"MONGODB_URI": "mongodb+srv://u:p@c.mongodb.net/gibran2029_db?w=majority"}, ("mongodb+srv://u:p@c.mongodb.net/gibran2029_db?w=majority", "gibran2029_db")),
    ({"MONGO_URL": "mongodb://localhost:27017", "DB_NAME": "gibran2029_db"}, ("mongodb://localhost:27017", "gibran2029_db")),
    ({"MONGODB_URI": "mongodb://a/x", "MONGO_URL": "mongodb://b/y", "DB_NAME": "custom"}, ("mongodb://a/x", "custom")),  # MONGODB_URI & DB_NAME menang
])
def test_resolve_mongo_config(env, expected):
    assert server.resolve_mongo_config(env) == expected


def test_resolve_mongo_config_requires_uri():
    with pytest.raises(RuntimeError):
        server.resolve_mongo_config({"DB_NAME": "gibran2029_db"})


def _seed_old_db(db):
    db.users.insert_many([
        {"user_id": "u_reg", "email": "rina@gmail.com", "name": "Rina", "role": "brand", "brand_balance": 50000, "balance": 0,
         "profile": {"brand_name": "Cahaya.Hijab", "bank": "BCA 123"}, "avatar_upload_id": "img_av", "created_at": "2026-11-01"},
        {"user_id": "u_owner", "email": "owner@x.id", "name": "Owner", "role": "admin", "is_owner": True, "phone": "62811"},
        {"user_id": "u_creator_lama", "email": "lama@x.id", "name": "Kreator OurBuzzer", "role": "creator", "balance": 99000},
    ])
    db.registrations.insert_many([
        {"registration_id": "reg_1", "user_id": "u_reg", "jenis": "relawan", "nama": "Rina", "status": "diterima",
         "kta_number": "G2029-R-33-000004", "ktp_upload_id": "ktp_1"},
    ])
    db.uploads.insert_many([{"upload_id": "ktp_1", "kind": "ktp", "data": b"\xff\xd8"}, {"upload_id": "img_av", "kind": "avatar", "data": b"x"},
                            {"upload_id": "img_campaign", "kind": "image", "data": b"y"}])
    db.counters.insert_many([{"_id": "kta_relawan", "seq": 4}, {"_id": "kta_anggota", "seq": 2}])
    db.notifications.insert_many([
        {"notification_id": "n1", "user_id": "u_reg", "title": "Pendaftaran relawan disetujui", "body": "KTA G2029-R-33-000004"},
        {"notification_id": "n2", "user_id": "u_reg", "title": "Campaign ditutup", "body": "OurBuzzer"},
    ])
    db.campaigns.insert_one({"campaign_id": "cmp_lama", "title": "TryBuzzer Threads Campaign"})
    db.withdrawals.insert_one({"withdrawal_id": "wd_1", "amount": 50000})


def test_migrate_copies_only_gibran2029_data():
    client = mongomock.MongoClient()
    old, new = client["ourbuzzer"], client["gibran2029_db"]
    _seed_old_db(old)

    dry = mig.migrate(old, new, apply=False)
    assert dry == {"registrations": 1, "users": 2, "uploads": 2, "counters": 2, "notifications": 1}
    assert new.list_collection_names() == []  # dry run tidak menulis apa pun

    res = mig.migrate(old, new, apply=True)
    assert res["akun_digabung"] == 0 and res["dilewati"] == []
    assert new.registrations.find_one({"registration_id": "reg_1"})["kta_number"] == "G2029-R-33-000004"
    u = new.users.find_one({"user_id": "u_reg"})
    assert u["role"] is None and u["brand_balance"] == 0 and u["profile"] == {}  # data komersial lama dibuang
    assert new.users.find_one({"user_id": "u_owner"})["role"] == "admin"
    assert new.users.find_one({"user_id": "u_creator_lama"}) is None
    assert {x["upload_id"] for x in new.uploads.find()} == {"ktp_1", "img_av"}
    assert new.counters.find_one({"_id": "kta_relawan"})["seq"] == 4
    assert [n["notification_id"] for n in new.notifications.find()] == ["n1"]
    assert "campaigns" not in new.list_collection_names() and "withdrawals" not in new.list_collection_names()
    assert old.users.count_documents({}) == 3 and old.campaigns.count_documents({}) == 1  # database lama utuh

    # Aman dijalankan ulang; urutan KTA di database baru tidak pernah turun.
    new.counters.update_one({"_id": "kta_relawan"}, {"$set": {"seq": 9}})
    mig.migrate(old, new, apply=True)
    assert new.registrations.count_documents({}) == 1 and new.users.count_documents({}) == 2
    assert new.counters.find_one({"_id": "kta_relawan"})["seq"] == 9


def test_migrate_cli_refuses_same_db(monkeypatch):
    monkeypatch.setenv("MONGODB_URI", "mongodb://localhost:27017")
    with pytest.raises(SystemExit):
        mig.main(["--source-db", "gibran2029_db", "--target-db", "gibran2029_db"])


def test_database_baru_tidak_diisi_campaign_demo_lama(monkeypatch):
    from mongomock_motor import AsyncMongoMockClient
    from fastapi.testclient import TestClient
    monkeypatch.delenv("SEED_DEMO_DATA", raising=False)
    server.RECONCILE_SECONDS = 0
    server.db = AsyncMongoMockClient()["gibran2029_db_kosong"]
    with TestClient(server.app) as c:
        assert c.portal.call(server.db.campaigns.count_documents, {}) == 0
        assert c.portal.call(server.db.users.count_documents, {}) == 0


def _new_db_with_indexes(client):
    new = client["gibran2029_db"]
    new.users.create_index("user_id", unique=True)
    new.users.create_index("email", unique=True)
    new.registrations.create_index("registration_id", unique=True)
    new.registrations.create_index([("user_id", 1), ("jenis", 1)], unique=True)
    return new


def test_migrate_gabung_akun_yang_sudah_login_di_database_baru():
    client = mongomock.MongoClient()
    old = client["ourbuzzer"]
    _seed_old_db(old)
    new = _new_db_with_indexes(client)
    # Setelah DB_NAME diganti, Rina & Owner sudah login lagi → akun baru dengan email yang sama.
    new.users.insert_many([{"user_id": "u_rina_baru", "email": "rina@gmail.com", "name": "Rina", "role": None},
                           {"user_id": "u_owner_baru", "email": "owner@x.id", "name": "Owner", "role": "admin", "is_owner": True}])
    res = mig.migrate(old, new, apply=True)
    assert res["akun_digabung"] == 2 and res["dilewati"] == []
    assert new.users.count_documents({}) == 2  # tidak ada akun ganda
    assert new.registrations.find_one({"registration_id": "reg_1"})["user_id"] == "u_rina_baru"
    assert new.notifications.find_one({"notification_id": "n1"})["user_id"] == "u_rina_baru"


def test_migrate_pendaftaran_ulang_di_database_baru_dipertahankan():
    client = mongomock.MongoClient()
    old = client["ourbuzzer"]
    _seed_old_db(old)
    new = _new_db_with_indexes(client)
    new.users.insert_one({"user_id": "u_reg", "email": "rina@gmail.com", "name": "Rina", "role": None})
    new.registrations.insert_one({"registration_id": "reg_baru", "user_id": "u_reg", "jenis": "relawan", "status": "menunggu verifikasi"})
    res = mig.migrate(old, new, apply=True)
    assert res["dilewati"] == ["registration reg_1"]
    assert [r["registration_id"] for r in new.registrations.find()] == ["reg_baru"]


def test_migrasi_di_server_via_env(monkeypatch, caplog):
    import asyncio
    import logging
    import pymongo
    shared = mongomock.MongoClient()
    _seed_old_db(shared["ourbuzzer"])
    monkeypatch.setattr(pymongo, "MongoClient", lambda *a, **k: shared)
    monkeypatch.setattr(server, "DB_NAME", "gibran2029_db")
    monkeypatch.setenv("MIGRATE_FROM_DB", "ourbuzzer")
    caplog.set_level(logging.INFO)
    asyncio.run(server._maybe_migrate_legacy_db())  # tanpa MIGRATE_APPLY → dry run
    assert "DRY RUN" in caplog.text and shared["gibran2029_db"].registrations.count_documents({}) == 0
    monkeypatch.setenv("MIGRATE_APPLY", "true")
    asyncio.run(server._maybe_migrate_legacy_db())
    assert "SELESAI" in caplog.text and shared["gibran2029_db"].registrations.count_documents({}) == 1
    monkeypatch.setenv("MIGRATE_FROM_DB", "gibran2029_db")  # sumber = tujuan → dilewati
    asyncio.run(server._maybe_migrate_legacy_db())
    assert "dilewati" in caplog.text
