# GIBRAN2029 — Aplikasi Mobile & Backend

*Bergerak Bersama, Menuju Indonesia Maju 2029.*

- `flutter_app/` — aplikasi Android/iOS (Flutter). Lihat `flutter_app/README.md`.
- `backend/` — API FastAPI (MongoDB) yang dipakai aplikasi dan web; di-deploy ke Railway (Root Directory: `/backend`).
- Web (pendaftaran Member/Relawan, KTA digital, panel admin) ada di repo `jkwEffect-Web`.

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
