# TryBuzzer Mobile — PRD

## Original problem statement
Mobile companion app (Expo) for the existing TryBuzzer-style paid-per-view creator marketing platform: Kreator & Brand manage campaigns, submit video links, check views, claim earnings, top up / withdraw. Architecture, folder structure, Home/Cari Cuan + base API connection first.

## User choices
- Backend: built here (shared FastAPI + MongoDB, same as web); Supabase planned later → schema at /app/backend/supabase/schema.sql
- Auth: Emergent Google Sign-In (same accounts as web)
- Top up: real Komerce sandbox (QRIS / VA)
- Scope v1: full Creator + basic Brand; admin → web
- UI similar to web app (orange #FF5500 + slate)

## Architecture
- /app/backend (FastAPI, shared with web) — auth/session now also returns session_token for Bearer auth
- /app/web — existing React web app (moved, not served in preview). Its old PRD: /app/memory/PRD_web.md
- /app/frontend — Expo Router app; src/api (client + services layer), AuthContext (SecureStore), React Query, screens per role. See /app/memory/ARCHITECTURE.md

## Implemented (2026-11-03)
- Google login, role onboarding (creator/brand), auth gate
- Creator: Cari Cuan (Public/Exclusive, search, category chips, 4 rows, streak banner, balance pill, bell), campaign detail, submit link w/ validation + anti-duplicate, Konten status filters + claim views, Dompet + withdraw (min Rp 50.000), notifications, profile
- Brand: dashboard stats, Komerce top up (QRIS QR / VA, polling), create campaign, pause/resume/close with refund, review content + verify views
- Tested end-to-end (iteration_3) — all flows pass

## Backlog
- P1: Admin panel on mobile (approve withdrawals)
- P1: Migrate data layer to Supabase
- P2: Auto-fetch views via platform APIs, campaign image upload, share/referral campaign links
