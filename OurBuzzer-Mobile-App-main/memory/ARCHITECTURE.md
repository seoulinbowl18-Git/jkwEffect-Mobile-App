# TryBuzzer Mobile — Arsitektur

```
/app
├── backend/            FastAPI (shared by web + mobile) — /api/*
│   ├── server.py       Auth, campaigns, submissions, withdraw, Komerce top-up, notifications
│   └── supabase/schema.sql   Postgres schema siap migrasi ke Supabase
├── web/                Web app (React) — versi web yang sudah jadi
└── frontend/           Mobile app (Expo Router)
    ├── app/            Routes
    │   ├── _layout.tsx         Providers + auth gate (login → onboarding → tabs)
    │   ├── login.tsx, onboarding.tsx
    │   ├── (tabs)/index        Cari Cuan (kreator) / Beranda (brand)
    │   ├── (tabs)/activity     Konten saya (kreator) / Review (brand)
    │   ├── (tabs)/wallet       Dompet + withdraw (kreator) / Saldo + top up (brand)
    │   ├── (tabs)/profile
    │   ├── campaign/[id], submit/[id], withdraw, topup, new-campaign, notifications
    └── src/
        ├── api/client.ts       fetch + Bearer token + 401 handler
        ├── api/services.ts     Semua endpoint (ganti di sini saat pindah ke Supabase)
        ├── api/types.ts
        ├── context/AuthContext Google Sign-In, token di SecureStore
        ├── components/         CampaignCard, StreakBanner, Chips, Sheet, Toast, ui
        ├── screens/            Layar per role
        └── theme.ts            Warna (sama dengan web: #FF5500 / slate)
```

State: React Query (cache + pull-to-refresh). Token: expo-secure-store (mobile), localStorage (web preview).
