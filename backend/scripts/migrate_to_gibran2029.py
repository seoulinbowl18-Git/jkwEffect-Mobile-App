"""Salin data GIBRAN2029 dari database lama (OurBuzzer) ke database baru yang terpisah.

Yang disalin (upsert, aman dijalankan berulang; database lama TIDAK diubah/dihapus):
  - registrations   : semua pendaftaran Member & Relawan (termasuk nomor KTA)
  - uploads         : foto KTP pendaftar + foto profil akun yang disalin
  - counters        : urutan nomor KTA (kta_anggota, kta_relawan) agar nomor tidak terulang
  - users           : akun para pendaftar + akun admin, TANPA data komersial lama
                      (saldo, saldo brand, total pendapatan, profil bank/brand, peran kreator/brand)
  - notifications   : notifikasi pendaftaran (judul diawali "Pendaftaran")
Tidak disalin: campaign, submission, ledger, top up, penarikan, sesi login (pengguna cukup login ulang).

Pemakaian (jalankan dari folder backend/):
  MONGODB_URI="mongodb+srv://..." python scripts/migrate_to_gibran2029.py --source-db ourbuzzer            # uji coba (dry run)
  MONGODB_URI="mongodb+srv://..." python scripts/migrate_to_gibran2029.py --source-db ourbuzzer --apply    # salin sungguhan
"""
import argparse
import os
import sys

from pymongo import MongoClient

TARGET_DEFAULT = "gibran2029_db"
USER_FIELDS = ("user_id", "email", "name", "picture", "google_picture", "picture_custom", "avatar_upload_id",
               "email_verified", "auth_provider", "status", "suspend_reason", "created_at", "phone", "is_owner")


def clean_user(u: dict) -> dict:
    """Akun tanpa data komersial OurBuzzer. Peran hanya dipertahankan untuk admin."""
    out = {k: u[k] for k in USER_FIELDS if k in u}
    out["role"] = "admin" if u.get("role") == "admin" else None
    out.update({"balance": 0, "total_earned": 0, "brand_balance": 0, "post_dates": [], "profile": {}})
    return out


def migrate(src, dst, apply: bool = False) -> dict:
    regs = list(src.registrations.find({}, {"_id": 0}))
    reg_user_ids = {r["user_id"] for r in regs if r.get("user_id")}
    admins = list(src.users.find({"role": "admin"}, {"_id": 0}))
    users = list(src.users.find({"user_id": {"$in": sorted(reg_user_ids)}}, {"_id": 0})) + \
        [a for a in admins if a["user_id"] not in reg_user_ids]
    cleaned = [clean_user(u) for u in users]
    upload_ids = {r["ktp_upload_id"] for r in regs if r.get("ktp_upload_id")} | \
        {u["avatar_upload_id"] for u in cleaned if u.get("avatar_upload_id")}
    uploads = list(src.uploads.find({"upload_id": {"$in": sorted(upload_ids)}}, {"_id": 0}))
    counters = list(src.counters.find({"_id": {"$in": ["kta_anggota", "kta_relawan"]}}))
    notifs = list(src.notifications.find({"user_id": {"$in": sorted(reg_user_ids)}, "title": {"$regex": "^Pendaftaran"}}, {"_id": 0}))
    summary = {"registrations": len(regs), "users": len(cleaned), "uploads": len(uploads),
               "counters": len(counters), "notifications": len(notifs)}
    if not apply:
        return summary
    for r in regs:
        dst.registrations.replace_one({"registration_id": r["registration_id"]}, r, upsert=True)
    for u in cleaned:
        dst.users.replace_one({"user_id": u["user_id"]}, u, upsert=True)
    for up in uploads:
        dst.uploads.replace_one({"upload_id": up["upload_id"]}, up, upsert=True)
    for c in counters:  # jangan pernah menurunkan urutan KTA yang sudah ada di database baru
        dst.counters.update_one({"_id": c["_id"]}, {"$max": {"seq": c.get("seq", 0)}}, upsert=True)
    for n in notifs:
        dst.notifications.replace_one({"notification_id": n["notification_id"]}, n, upsert=True)
    return summary


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source-db", required=True, help="nama database lama, mis. ourbuzzer")
    ap.add_argument("--target-db", default=TARGET_DEFAULT, help=f"nama database baru (default {TARGET_DEFAULT})")
    ap.add_argument("--apply", action="store_true", help="benar-benar menyalin (tanpa ini hanya dry run)")
    args = ap.parse_args(argv)
    uri = os.environ.get("MONGODB_URI") or os.environ.get("MONGO_URL")
    if not uri:
        sys.exit("Set MONGODB_URI (atau MONGO_URL) terlebih dahulu.")
    if args.source_db == args.target_db:
        sys.exit("--source-db dan --target-db tidak boleh sama.")
    client = MongoClient(uri)
    summary = migrate(client[args.source_db], client[args.target_db], apply=args.apply)
    mode = "DISALIN" if args.apply else "DRY RUN (belum ada yang disalin; tambahkan --apply)"
    print(f"{mode}: {args.source_db} -> {args.target_db}")
    for k, v in summary.items():
        print(f"  {k:14s} {v}")


if __name__ == "__main__":
    main()
