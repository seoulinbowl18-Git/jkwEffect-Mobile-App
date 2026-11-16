# GIBRAN2029 — Aplikasi Mobile & Backend

*Bergerak Bersama, Menuju Indonesia Maju 2029.*

- `flutter_app/` — aplikasi Android/iOS (Flutter). Lihat `flutter_app/README.md`.
- `backend/` — API FastAPI (MongoDB) yang dipakai aplikasi dan web; di-deploy ke Railway (Root Directory: `/backend`).
- Web (pendaftaran Member/Relawan, KTA digital, panel admin) ada di repo `jkwEffect-Web`.

## Database terpisah (GIBRAN2029)
Semua koleksi (`users`, `registrations`, `counters` untuk nomor KTA, `notifications`, `uploads`, dst.) disimpan di
database **`gibran2029_db`**, terpisah dari database lama OurBuzzer. Backend membaca:
`MONGODB_URI` (atau `MONGO_URL`) dan `DB_NAME` (default `gibran2029_db`). Log startup menulis database yang dipakai,
dan memberi peringatan bila masih memakai `ourbuzzer`/`trybuzzer`.

### Pindah database di Railway (sekali saja)
1. **Salin data GIBRAN2029** (pendaftaran, foto KTP, urutan KTA, akun pendaftar & admin) dari database lama:
   ```bash
   cd backend
   MONGODB_URI="<connection string>" python scripts/migrate_to_gibran2029.py --source-db <DB_NAME lama>          # cek dulu (dry run)
   MONGODB_URI="<connection string>" python scripts/migrate_to_gibran2029.py --source-db <DB_NAME lama> --apply  # salin
   ```
   Database lama tidak diubah. Data komersial OurBuzzer (campaign, saldo, penarikan) tidak ikut.
2. **Railway → service backend → Variables**: ubah `DB_NAME` menjadi `gibran2029_db` (biarkan `MONGO_URL`), lalu Deploy.
3. Cek **Deploy Logs**: harus muncul `Database MongoDB: gibran2029_db`. Pengguna perlu login ulang sekali (sesi lama tidak disalin).

## Menjalankan backend lokal
```bash
cd backend && cp .env.example .env   # isi MONGO_URL, FIREBASE_PROJECT_ID, dst.
pip install -r requirements.txt && uvicorn server:app --reload --port 8001
```

## Tes
```bash
cd backend && pytest -n 0
cd flutter_app && flutter analyze && flutter test
```
Detail login & OTP admin: `auth_testing.md`. Catatan produk: `memory/`.
