# Auth Testing (Emergent Google Auth)
Create test user + session in mongo (db from backend/.env DB_NAME), set `role` to creator/brand/admin:
```
mongosh --eval "use('test_database'); db.users.insertOne({user_id:'user_test1', email:'creator.test@example.com', name:'Test Creator', role:'creator', balance:0, total_earned:0, brand_balance:0, post_dates:[], profile:{}, created_at:new Date().toISOString()}); db.user_sessions.insertOne({user_id:'user_test1', session_token:'test_session_creator', expires_at:new Date(Date.now()+7*864e5), created_at:new Date()})"
```
Use `Authorization: Bearer <token>` for curl, or cookie `session_token` (secure, sameSite None) in browser.

# Auth Email + Password
```
curl -X POST $API/api/auth/register -H 'Content-Type: application/json' -d '{"name":"Ani","email":"ani@example.com","password":"rahasia123"}'
curl -X POST $API/api/auth/login    -H 'Content-Type: application/json' -d '{"email":"ani@example.com","password":"rahasia123"}'
```
Both return the user + `session_token` (same shape as `/auth/session`); new users have `role: null` → POST /users/role.
Rules: password 8–72 chars (bcrypt), ADMIN_EMAIL cannot self-register, Google-only emails must use Google,
10 failed logins per email (30 per IP) in 15 min → 429. Google sign-in on an account whose email was never
verified removes its password and sessions (pre-account-hijacking defense).
Offline tests: `cd backend && pytest tests/test_email_auth.py -n 0` (uses mongomock-motor, no live server).
