# TryBuzzer Clone — PRD

## Original problem statement
"https://www.trybuzzer.com/ saya ingin membuat website seperti try buzzer" — pay-per-performance creator marketing platform (Brand vs Creator), campaign system, video submission tracking, balance/payout, security & scalability.

## User choices
- Login: Emergent-managed Google login only. Admin = hari.jp.insta2016@gmail.com (ADMIN_EMAIL)
- Views: creator claims, brand/admin verifies manually
- Payments: Komerce (brand top-up QRIS / Virtual Account), sandbox key in KOMERCE_API_KEY
- Payout: creator withdrawal request (min Rp 50.000), admin approves manually
- Extras: daily streak, admin panel, in-app notifications

## Architecture
FastAPI + MongoDB (users, user_sessions, campaigns, submissions, withdrawals, topups, notifications, ledger) + React (Tailwind, shadcn). Atomic balance ops via conditional find_one_and_update; ledger entries for every money movement.

## Implemented (2026-11-03)
- Landing (hero, role toggle, earnings calculator, FAQ, trending), /bounty browse (rows, search, categories, exclusive), /cara-kerja, /untuk-brand
- Onboarding role choice (creator/brand)
- Creator dashboard: stats, streak, submissions w/ status filters, claim views, withdrawals, profile
- Brand dashboard: Komerce top-up (QRIS QR / VA), create campaign (budget deducted), pause/close+refund, review content, verify views & pay
- Admin panel: stats, verify submissions, approve/reject withdrawals, manage campaigns, users + manual brand credit
- Notifications bell; Komerce callback (signature check + status re-confirm)
- Security fixes: no over-payout after close, URL normalization dedup, open submissions auto-rejected when campaign closes

## Backlog
- P1: Auto-fetch views via TikTok/YouTube APIs; Komerce callback signature confirmation with live callbacks
- P1: Exclusive campaign invite system
- P2: Buzz Poin / rewards, leaderboard, campaign image upload (object storage), email notifications
