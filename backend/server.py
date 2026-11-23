from fastapi import FastAPI, APIRouter, HTTPException, Request, Response, Depends, UploadFile, File, Form
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError
import os
import sys
import re
import asyncio
import time
from collections import defaultdict, deque
import bcrypt
import jwt
import hmac
import hashlib
import secrets
import logging
import uuid
import httpx
from urllib.parse import urlparse
from pathlib import Path
from pydantic import BaseModel, Field, EmailStr, field_validator
from typing import List, Optional, Literal
from datetime import datetime, timezone, timedelta

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# ---------------- Database ----------------
# Gibran for 2029 memakai database MongoDB sendiri, terpisah dari data OurBuzzer lama.
# URI: MONGODB_URI (disarankan) atau MONGO_URL (nama lama, tetap didukung).
# Nama database: DB_NAME; bila kosong diambil dari path URI (…mongodb.net/<nama>?…), lalu default "gibran2029_db".
DEFAULT_DB_NAME = "gibran2029_db"
LEGACY_DB_NAMES = {"ourbuzzer", "trybuzzer"}


def resolve_mongo_config(env=os.environ):
    uri = (env.get("MONGODB_URI") or env.get("MONGO_URL") or "").strip()
    if not uri:
        raise RuntimeError("Set MONGODB_URI (atau MONGO_URL) ke connection string MongoDB.")
    name = (env.get("DB_NAME") or "").strip()
    if not name:
        path = urlparse(uri).path.strip("/")
        name = path.split("/")[0] if path else ""
    return uri, name or DEFAULT_DB_NAME


MONGO_URI, DB_NAME = resolve_mongo_config()
client = AsyncIOMotorClient(MONGO_URI)
db = client[DB_NAME]
ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', '').lower()
EMERGENT_AUTH_URL = "https://demobackend.emergentagent.com/auth/v1/env/oauth/session-data"
MIN_WITHDRAW = 50000
MIN_TOPUP = 10000


def _pct_env(name, default):
    """Persentase fee dari env (mis. "10", "12.5"), dibatasi 0-50%. Disimpan sebagai basis point (1% = 100)."""
    raw = (os.environ.get(name) or "").strip().replace(",", ".").rstrip("%")
    try:
        v = float(raw) if raw else default
    except ValueError:
        v = default
    return int(round(min(max(v, 0.0), 50.0) * 100))


# Fee platform — ubah lewat env Railway tanpa mengubah kode/UI (UI membaca GET /api/config/fees).
BRAND_TOPUP_FEE_BP = _pct_env("BRAND_TOPUP_FEE_PCT", 10)          # ditambahkan ke tagihan top-up brand
CREATOR_WITHDRAW_FEE_BP = _pct_env("CREATOR_WITHDRAW_FEE_PCT", 15)  # dipotong dari penarikan kreator
BRAND_WITHDRAW_FEE_BP = _pct_env("BRAND_WITHDRAW_FEE_PCT", 0)      # dipotong dari penarikan saldo brand
CAMPAIGN_EXPIRY_CHECK_SECONDS = int(os.environ.get("CAMPAIGN_EXPIRY_CHECK_SECONDS", "600") or 0)


def fee_amount(amount: int, bp: int) -> int:
    """Fee rupiah dibulatkan ke rupiah terdekat (setengah ke atas), murni integer."""
    return (int(amount) * bp + 5000) // 10000


def bp_to_pct(bp: int):
    return bp // 100 if bp % 100 == 0 else bp / 100
WIB = timezone(timedelta(hours=7))
SESSION_DAYS = 7
# Projection for any user document returned to clients: never leak the password hash.
USER_PUBLIC = {"_id": 0, "password_hash": 0}

app = FastAPI()
api = APIRouter(prefix="/api")
logger = logging.getLogger("gibran2029")
logging.basicConfig(level=logging.INFO)
# httpx logs every request URL at INFO; Telegram Bot API URLs contain the bot token
# (https://api.telegram.org/bot<TOKEN>/...), so keep httpx/httpcore quiet.
for _noisy in ("httpx", "httpcore"):
    logging.getLogger(_noisy).setLevel(logging.WARNING)

PLATFORM_DOMAINS = {
    "tiktok": ["tiktok.com"],
    "instagram": ["instagram.com"],
    "threads": ["threads.net", "threads.com"],
    "youtube": ["youtube.com", "youtu.be"],
    "facebook": ["facebook.com", "fb.com", "fb.watch"],
}
CATEGORIES = ["Produk", "Beauty", "Lifestyle", "F&B", "Edukasi", "Hiburan", "Fashion", "Tech"]  # campaign brand lama
# Campaign gerakan Gibran for 2029 (dibuat Admin Pusat): tanpa brand, rate, budget, dan minimal views.
GERAKAN_NAME = "Gibran for 2029"
OLD_GERAKAN_NAME = "GIBRAN2029"
GERAKAN_CATEGORIES = ["Agenda", "Sebar Narasi", "Aksi Sosial", "Penggalangan Dukungan"]
TARGET_AKSI = {"share": "Share", "forward": "Forward", "komentar": "Komentar", "kehadiran": "Kehadiran Acara"}
Platform = Literal["tiktok", "instagram", "threads", "youtube", "facebook"]
TargetAksi = Literal["share", "forward", "komentar", "kehadiran"]


def now():
    return datetime.now(timezone.utc)


def iso():
    return now().isoformat()


def gen_id(prefix):
    return f"{prefix}_{uuid.uuid4().hex[:12]}"


# ---------------- Auth ----------------
async def get_user(request: Request):
    token = request.cookies.get("session_token")
    if not token:
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth[7:]
    if not token:
        raise HTTPException(401, "Belum login")
    sess = await db.user_sessions.find_one({"session_token": token}, {"_id": 0})
    if not sess:
        raise HTTPException(401, "Sesi tidak valid")
    exp = sess["expires_at"]
    if isinstance(exp, str):
        exp = datetime.fromisoformat(exp)
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    if exp < now():
        raise HTTPException(401, "Sesi kadaluarsa")
    user = await db.users.find_one({"user_id": sess["user_id"]}, USER_PUBLIC)
    if not user:
        raise HTTPException(401, "User tidak ditemukan")
    if user.get("status") == "suspended":
        raise HTTPException(401, suspended_message(user))
    return user


def suspended_message(user):
    reason = (user.get("suspend_reason") or "").strip()
    return "Akun kamu ditangguhkan" + (f": {reason}" if reason else ". Hubungi admin Gibran for 2029.")


async def require_owner(user=Depends(get_user)):
    """Owner (Admin Pusat, signed in with the WhatsApp OTP). Moderation admins via Google are not owners."""
    if user.get("role") != "admin" or not user.get("is_owner"):
        raise HTTPException(403, "Hanya Owner yang bisa melakukan aksi ini")
    return user


async def audit(actor, action, target, detail=None):
    await db.audit.insert_one({"audit_id": gen_id("aud"), "actor_id": actor["user_id"], "actor_name": actor.get("name", ""),
                               "action": action, "target": target, "detail": detail or {}, "created_at": iso()})


async def audit_if_owner(actor, action, target, detail=None):
    if actor.get("is_owner"):
        await audit(actor, action, target, detail)


def require(*roles):
    async def dep(user=Depends(get_user)):
        if user.get("role") not in roles:
            raise HTTPException(403, "Akses ditolak")
        return user
    return dep


class SessionIn(BaseModel):
    session_id: str


async def start_session(response: Response, user_id: str, token: Optional[str] = None):
    """Create a 7-day session (cookie for web + session_token in body for mobile Bearer auth)."""
    token = token or secrets.token_urlsafe(32)
    target = await db.users.find_one({"user_id": user_id}, {"_id": 0, "status": 1, "suspend_reason": 1})
    if target and target.get("status") == "suspended":
        raise HTTPException(403, suspended_message(target))
    await db.user_sessions.insert_one({
        "user_id": user_id, "session_token": token,
        "expires_at": now() + timedelta(days=SESSION_DAYS), "created_at": now(),
    })
    response.set_cookie("session_token", token, httponly=True, secure=True, samesite="none",
                        path="/", max_age=SESSION_DAYS * 24 * 3600)
    u = await db.users.find_one({"user_id": user_id}, USER_PUBLIC)
    # session_token is included for mobile clients (Bearer auth); web keeps using the cookie
    return {**u, "session_token": token, "user": u}


def new_user_doc(user_id, email, name, picture=None, role=None, **extra):
    return {"user_id": user_id, "email": email, "name": name, "picture": picture, "role": role,
            "balance": 0, "total_earned": 0, "brand_balance": 0, "post_dates": [],
            "profile": {}, "created_at": iso(), **extra}


async def upsert_verified_user(email: str, name: str, picture=None, provider="google", **extra_set):
    """Find-or-create a user whose email an identity provider (Google / Firebase) has verified.
    Returns user_id. Used by every 'Sign in with Google' path so they behave identically."""
    email = email.lower()
    user = await db.users.find_one({"email": email}, {"_id": 0})
    if user:
        upd = {"name": user.get("name") or name, "email_verified": True, **extra_set}
        if picture:
            upd["google_picture"] = picture
        # A photo the user uploaded themselves (POST /users/avatar) wins over the Google photo.
        if not user.get("picture_custom"):
            upd["picture"] = picture or user.get("picture")
        if ADMIN_EMAIL and email == ADMIN_EMAIL:
            upd["role"] = "admin"
        update = {"$set": upd}
        if user.get("password_hash") and not user.get("email_verified"):
            # Pre-account-hijacking defense: an email/password account was never proven to belong to
            # this inbox. Google just proved ownership, so drop the unverified password and its sessions.
            update["$unset"] = {"password_hash": ""}
            await db.user_sessions.delete_many({"user_id": user["user_id"]})
        await db.users.update_one({"email": email}, update)
        return user["user_id"]
    user_id = gen_id("user")
    try:
        await db.users.insert_one(new_user_doc(
            user_id, email, name, picture, role="admin" if ADMIN_EMAIL and email == ADMIN_EMAIL else None,
            email_verified=True, auth_provider=provider, **extra_set))
    except DuplicateKeyError:  # two first logins racing: use the account the other request created
        return (await db.users.find_one({"email": email}, {"user_id": 1}))["user_id"]
    return user_id


@api.post("/auth/session")
async def auth_session(body: SessionIn, response: Response):
    async with httpx.AsyncClient(timeout=15) as c:
        r = await c.get(EMERGENT_AUTH_URL, headers={"X-Session-ID": body.session_id})
    if r.status_code != 200:
        raise HTTPException(401, "Login gagal")
    data = r.json()
    user_id = await upsert_verified_user(data["email"], data["name"], data.get("picture"), "google")
    return await start_session(response, user_id, data["session_token"])


# ---------------- Firebase Authentication (Google Sign-In from the Flutter app) ----------------
# The app signs in with Google through Firebase and sends the Firebase ID token here. We verify it
# ourselves (RS256 against Google's published keys + aud/iss/exp checks), exactly as the Firebase
# Admin SDK does, without needing a service-account key.
FIREBASE_JWKS_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
_firebase_keys = {"keys": {}, "expires": 0.0}


async def _fetch_firebase_jwks():
    """Return ({kid: jwk}, max_age_seconds) from Google."""
    async with httpx.AsyncClient(timeout=10) as c:
        r = await c.get(FIREBASE_JWKS_URL)
    r.raise_for_status()
    m = re.search(r"max-age=(\d+)", r.headers.get("cache-control", ""))
    return {k["kid"]: k for k in r.json().get("keys", []) if k.get("kid")}, int(m.group(1)) if m else 3600


async def firebase_signing_key(kid: str):
    for force in (False, True):  # refetch once if Google rotated keys since we cached them
        if force or time.monotonic() >= _firebase_keys["expires"] or not _firebase_keys["keys"]:
            try:
                keys, max_age = await _fetch_firebase_jwks()
            except (httpx.HTTPError, ValueError, KeyError) as e:
                logger.error("Cannot fetch Firebase signing keys: %r", e)
                raise HTTPException(503, "Tidak bisa memverifikasi login Google saat ini. Coba lagi.")
            _firebase_keys.update(keys=keys, expires=time.monotonic() + max_age)
        if kid in _firebase_keys["keys"]:
            return jwt.PyJWK(_firebase_keys["keys"][kid]).key
    return None


async def verify_firebase_id_token(token: str) -> dict:
    project = (os.environ.get("FIREBASE_PROJECT_ID") or "").strip()
    if not project:
        raise HTTPException(503, "Login Google (Firebase) belum dikonfigurasi di server")
    try:
        header = jwt.get_unverified_header(token)
    except jwt.PyJWTError:
        raise HTTPException(401, "Token login tidak valid")
    if header.get("alg") != "RS256" or not header.get("kid"):
        raise HTTPException(401, "Token login tidak valid")
    key = await firebase_signing_key(header["kid"])
    if key is None:
        raise HTTPException(401, "Token login tidak valid")
    try:
        claims = jwt.decode(token, key, algorithms=["RS256"], audience=project,
                            issuer=f"https://securetoken.google.com/{project}", leeway=60,
                            options={"require": ["exp", "iat", "aud", "iss", "sub"]})
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Sesi login Google sudah kedaluwarsa. Silakan masuk lagi.")
    except jwt.PyJWTError:
        raise HTTPException(401, "Token login tidak valid")
    if not claims.get("sub") or len(claims["sub"]) > 128:
        raise HTTPException(401, "Token login tidak valid")
    if claims.get("auth_time") and claims["auth_time"] > time.time() + 60:
        raise HTTPException(401, "Token login tidak valid")
    return claims


class FirebaseIn(BaseModel):
    id_token: str = Field(min_length=20, max_length=8192)


@api.post("/auth/firebase")
async def auth_firebase(body: FirebaseIn, response: Response):
    claims = await verify_firebase_id_token(body.id_token)
    if (claims.get("firebase") or {}).get("sign_in_provider") != "google.com":
        raise HTTPException(401, "Gunakan login Google")
    email = (claims.get("email") or "").strip().lower()
    if not email or claims.get("email_verified") is not True:
        raise HTTPException(401, "Akun Google ini tidak memiliki email terverifikasi")
    user_id = await upsert_verified_user(
        email, (claims.get("name") or email.split("@")[0])[:80], claims.get("picture"), "google",
        firebase_uid=claims["sub"])
    return await start_session(response, user_id)


# ---------------- Email + password auth ----------------
LOGIN_WINDOW = 15 * 60
MAX_FAILS_PER_EMAIL = 10
MAX_FAILS_PER_IP = 30
_login_fails = defaultdict(deque)  # key -> failure timestamps (in-memory, per worker process)
# Verified against when the account does not exist, so response time doesn't reveal registered emails.
_DUMMY_HASH = bcrypt.hashpw(b"dummy-password", bcrypt.gensalt())


def _recent_fails(key):
    q = _login_fails[key]
    cutoff = time.monotonic() - LOGIN_WINDOW
    while q and q[0] < cutoff:
        q.popleft()
    return len(q)


def _client_ip(request: Request):
    fwd = request.headers.get("x-forwarded-for", "")
    return fwd.split(",")[0].strip() or (request.client.host if request.client else "unknown")


async def hash_password(pw: str) -> str:
    return (await asyncio.to_thread(bcrypt.hashpw, pw.encode(), bcrypt.gensalt())).decode()


async def check_password(pw: str, hashed) -> bool:
    h = hashed.encode() if isinstance(hashed, str) else hashed
    return await asyncio.to_thread(bcrypt.checkpw, pw.encode(), h)


def _password_rules(v: str) -> str:
    if len(v.encode()) > 72:  # bcrypt only uses the first 72 bytes
        raise ValueError("Password maksimal 72 karakter")
    return v


class RegisterIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

    _pw = field_validator("password")(_password_rules)


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


@api.post("/auth/register")
async def auth_register(body: RegisterIn, response: Response):
    email = body.email.lower()
    name = body.name.strip()
    if not name:
        raise HTTPException(400, "Nama wajib diisi")
    if ADMIN_EMAIL and email == ADMIN_EMAIL:
        raise HTTPException(400, "Email ini harus masuk dengan Google")
    existing = await db.users.find_one({"email": email}, {"_id": 0, "user_id": 1, "password_hash": 1})
    if existing:
        if existing.get("password_hash"):
            raise HTTPException(400, "Email sudah terdaftar. Silakan masuk.")
        raise HTTPException(400, "Email ini terdaftar lewat Google. Silakan masuk dengan Google.")
    user_id = gen_id("user")
    try:
        await db.users.insert_one(new_user_doc(
            user_id, email, name[:80], password_hash=await hash_password(body.password),
            email_verified=False, auth_provider="email"))
    except DuplicateKeyError:
        raise HTTPException(400, "Email sudah terdaftar. Silakan masuk.")
    return await start_session(response, user_id)


@api.post("/auth/login")
async def auth_login(body: LoginIn, request: Request, response: Response):
    email = body.email.lower()
    ip_key = "ip:" + _client_ip(request)
    email_key = "email:" + email
    if _recent_fails(email_key) >= MAX_FAILS_PER_EMAIL or _recent_fails(ip_key) >= MAX_FAILS_PER_IP:
        raise HTTPException(429, "Terlalu banyak percobaan login. Coba lagi dalam 15 menit.")
    user = await db.users.find_one({"email": email}, {"_id": 0, "user_id": 1, "password_hash": 1})
    ok = await check_password(body.password, (user or {}).get("password_hash") or _DUMMY_HASH)
    if not user or not user.get("password_hash") or not ok:
        t = time.monotonic()
        _login_fails[email_key].append(t)
        _login_fails[ip_key].append(t)
        if user and not user.get("password_hash"):
            raise HTTPException(401, "Akun ini terdaftar lewat Google. Silakan masuk dengan Google.")
        raise HTTPException(401, "Email atau password salah")
    _login_fails.pop(email_key, None)
    return await start_session(response, user["user_id"])


# ---------------- Admin Pusat (Owner) login: WhatsApp OTP via Fonnte ----------------
# Only for owners listed in OWNER_PHONES. Creators & brands keep using Google Sign-In (Firebase).
FONNTE_SEND_URL = "https://api.fonnte.com/send"
OTP_TTL_MINUTES = 5
OTP_MAX_ATTEMPTS = 5
OTP_RESEND_SECONDS = 60
OTP_MAX_PER_HOUR = 5


def normalize_phone(raw) -> str:
    """'0812-3456 7890' / '+62 812…' / '812…' → '628123456789' (digits only, Indonesian 62 prefix)."""
    digits = re.sub(r"\D", "", raw or "")
    if digits.startswith("0"):
        digits = "62" + digits[1:]
    elif digits.startswith("8"):
        digits = "62" + digits
    return digits


def owner_phones() -> set:
    return {p for p in (normalize_phone(x) for x in re.split(r"[,;\n]+", os.environ.get("OWNER_PHONES", ""))) if p}


def _otp_hash(phone: str, code: str) -> str:
    key = os.environ.get("OTP_SECRET") or os.environ.get("FONNTE_TOKEN", "") or "ourbuzzer-otp"
    return hmac.new(key.encode(), f"{phone}:{code}".encode(), hashlib.sha256).hexdigest()


def _as_utc(dt):
    if isinstance(dt, str):
        dt = datetime.fromisoformat(dt)
    return dt.replace(tzinfo=timezone.utc) if dt and dt.tzinfo is None else dt


def mask_phone(phone: str) -> str:
    return phone[:4] + "•" * max(len(phone) - 7, 0) + phone[-3:] if len(phone) > 7 else phone


async def send_whatsapp(phone: str, message: str):
    """Send a WhatsApp message through Fonnte. Raises 502 if Fonnte does not accept it."""
    try:
        async with httpx.AsyncClient(timeout=20) as c:
            r = await c.post(FONNTE_SEND_URL, headers={"Authorization": os.environ.get("FONNTE_TOKEN", "")},
                             data={"target": phone, "message": message, "countryCode": "62"})
        body = r.json()
    except Exception as e:  # network error / non-JSON reply
        logger.warning("Fonnte send failed: %s", e)
        raise HTTPException(502, "Gagal mengirim OTP lewat WhatsApp. Coba lagi sebentar.")
    if r.status_code != 200 or not body.get("status"):
        logger.warning("Fonnte rejected message: %s", body.get("reason") or body)
        raise HTTPException(502, "Gagal mengirim OTP lewat WhatsApp. Coba lagi sebentar.")


class OtpRequestIn(BaseModel):
    phone: str = Field(min_length=6, max_length=24)


class OtpVerifyIn(BaseModel):
    phone: str = Field(min_length=6, max_length=24)
    code: str = Field(pattern=r"^\d{6}$")


@api.post("/admin/request-otp")
async def admin_request_otp(body: OtpRequestIn, request: Request):
    if not os.environ.get("FONNTE_TOKEN") or not owner_phones():
        raise HTTPException(503, "Login Admin Pusat belum dikonfigurasi")
    ip_key = "otp-ip:" + _client_ip(request)
    if _recent_fails(ip_key) >= MAX_FAILS_PER_IP:
        raise HTTPException(429, "Terlalu banyak percobaan. Coba lagi dalam 15 menit.")
    phone = normalize_phone(body.phone)
    if phone not in owner_phones():
        _login_fails[ip_key].append(time.monotonic())
        raise HTTPException(403, "Nomor ini tidak terdaftar sebagai Admin Pusat")

    t = now()
    doc = await db.admin_otps.find_one({"phone": phone}, {"_id": 0}) or {}
    last = _as_utc(doc.get("last_sent_at"))
    if last and (t - last).total_seconds() < OTP_RESEND_SECONDS:
        wait = OTP_RESEND_SECONDS - int((t - last).total_seconds())
        raise HTTPException(429, f"Tunggu {wait} detik sebelum meminta kode baru")
    window = _as_utc(doc.get("window_start"))
    count = doc.get("window_count", 0) if window and (t - window) < timedelta(hours=1) else 0
    if count >= OTP_MAX_PER_HOUR:
        raise HTTPException(429, "Batas permintaan OTP tercapai. Coba lagi dalam 1 jam.")

    code = f"{secrets.randbelow(1_000_000):06d}"
    await send_whatsapp(phone, (
        f"*Gibran for 2029 Admin Pusat*\n\nKode OTP login kamu: *{code}*\n"
        f"Berlaku {OTP_TTL_MINUTES} menit. Jangan berikan kode ini kepada siapa pun."))
    await db.admin_otps.update_one({"phone": phone}, {"$set": {
        "phone": phone, "code_hash": _otp_hash(phone, code), "expires_at": t + timedelta(minutes=OTP_TTL_MINUTES),
        "attempts": 0, "last_sent_at": t,
        "window_start": window if count else t, "window_count": count + 1,
    }}, upsert=True)
    return {"ok": True, "phone": mask_phone(phone), "expires_in": OTP_TTL_MINUTES * 60,
            "resend_in": OTP_RESEND_SECONDS}


@api.post("/admin/verify-otp")
async def admin_verify_otp(body: OtpVerifyIn, response: Response):
    phone = normalize_phone(body.phone)
    invalid = HTTPException(401, "Kode OTP salah atau sudah kedaluwarsa")
    if phone not in owner_phones():
        raise invalid
    doc = await db.admin_otps.find_one({"phone": phone}, {"_id": 0})
    if not doc or not doc.get("code_hash"):
        raise invalid
    clear = {"$unset": {"code_hash": "", "expires_at": ""}, "$set": {"attempts": 0}}
    if _as_utc(doc["expires_at"]) < now():
        await db.admin_otps.update_one({"phone": phone}, clear)
        raise HTTPException(401, "Kode OTP sudah kedaluwarsa. Minta kode baru.")
    if not hmac.compare_digest(doc["code_hash"], _otp_hash(phone, body.code)):
        attempts = doc.get("attempts", 0) + 1
        if attempts >= OTP_MAX_ATTEMPTS:
            await db.admin_otps.update_one({"phone": phone}, clear)
            raise HTTPException(429, "Terlalu banyak kode salah. Minta kode OTP baru.")
        await db.admin_otps.update_one({"phone": phone}, {"$set": {"attempts": attempts}})
        raise HTTPException(401, f"Kode OTP salah. Sisa {OTP_MAX_ATTEMPTS - attempts} percobaan.")
    await db.admin_otps.update_one({"phone": phone}, clear)  # one-time use

    user = await db.users.find_one({"phone": phone, "auth_provider": "whatsapp_otp"}, {"_id": 0, "user_id": 1})
    if user:
        user_id = user["user_id"]
        await db.users.update_one({"user_id": user_id}, {"$set": {"role": "admin", "is_owner": True}})
    else:
        user_id = gen_id("user")
        await db.users.insert_one(new_user_doc(
            user_id, f"owner+{phone}@owner.ourbuzzer.app", "Admin Pusat", role="admin", is_owner=True,
            phone=phone, auth_provider="whatsapp_otp", email_verified=False))
    return await start_session(response, user_id)


# ---------------- Live sync ----------------
# Web & mobile poll GET /api/sync and refetch when `v` changes. The version is bumped by
# the middleware below after every successful write to the API (web, mobile, or Owner).
SYNC_ID = "sync"


async def bump_sync():
    await db.meta.update_one({"_id": SYNC_ID}, {"$inc": {"v": 1}}, upsert=True)


@api.get("/sync")
async def get_sync():
    doc = await db.meta.find_one({"_id": SYNC_ID})
    if not doc:  # first ever call: start at 1 (clients treat 0 as "not loaded yet")
        await db.meta.update_one({"_id": SYNC_ID}, {"$setOnInsert": {"v": 1}}, upsert=True)
        doc = await db.meta.find_one({"_id": SYNC_ID})
    return {"v": int(doc.get("v", 1))}


@api.get("/auth/me")
async def me(user=Depends(get_user)):
    return user


@api.post("/auth/logout")
async def logout(request: Request, response: Response):
    token = request.cookies.get("session_token")
    auth = request.headers.get("Authorization", "")
    if not token and auth.startswith("Bearer "):
        token = auth[7:]
    if token:
        await db.user_sessions.delete_one({"session_token": token})
    response.delete_cookie("session_token", path="/", secure=True, samesite="none")
    return {"ok": True}


class RoleIn(BaseModel):
    role: Literal["creator", "brand"]
    brand_name: Optional[str] = None


@api.post("/users/role")
async def set_role(body: RoleIn, user=Depends(get_user)):
    if user.get("role"):
        raise HTTPException(400, "Role sudah dipilih")
    upd = {"role": body.role}
    if body.role == "brand":
        upd["profile.brand_name"] = (body.brand_name or user["name"]).strip()[:80]
    await db.users.update_one({"user_id": user["user_id"]}, {"$set": upd})
    return await db.users.find_one({"user_id": user["user_id"]}, USER_PUBLIC)


class ProfileIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    # None = not sent → keep the stored value (the web profile form no longer sends social handles).
    tiktok: Optional[str] = None
    instagram: Optional[str] = None
    brand_name: Optional[str] = None
    bank_method: Optional[str] = None
    bank_account: Optional[str] = None
    bank_holder: Optional[str] = None


@api.put("/users/profile")
async def update_profile(body: ProfileIn, user=Depends(get_user)):
    d = body.model_dump()
    name = d.pop("name").strip()
    upd, unset = {"name": name}, {}
    for k, v in d.items():
        if v is None:
            continue
        v = v.strip()[:120]
        upd[f"profile.{k}"] = v
        if k in SOCIAL_PLATFORMS:  # older app versions still edit TikTok / Instagram here
            handle = parse_social_handle(k, v) if v else None
            if handle:
                upd[f"social.{k}"] = social_entry(k, handle)
            elif not v:
                unset[f"social.{k}"] = ""
    await db.users.update_one({"user_id": user["user_id"]}, {"$set": upd, **({"$unset": unset} if unset else {})})
    return await db.users.find_one({"user_id": user["user_id"]}, USER_PUBLIC)


# ---------------- Social accounts & Telegram community ----------------
# users.social = {
#   tiktok|instagram|threads: {username, url, linked_at},
#   telegram: {id, username, name, linked_at},
# }
SOCIAL_PLATFORMS = ("tiktok", "instagram", "threads")
SOCIAL_URL = {"tiktok": "https://www.tiktok.com/@{}", "instagram": "https://www.instagram.com/{}",
              "threads": "https://www.threads.net/@{}"}
SOCIAL_HOSTS = {"tiktok": ("tiktok.com",), "instagram": ("instagram.com",), "threads": ("threads.net", "threads.com")}
HANDLE_RE = re.compile(r"^(?!.*\.\.)(?!\.)[A-Za-z0-9._]{1,30}(?<!\.)$")


def parse_social_handle(platform: str, raw: str):
    """'@ani.kreator', 'ani.kreator' or a profile URL → 'ani.kreator' (lowercase); None if invalid."""
    s = (raw or "").strip()
    if re.match(r"^https?://", s, re.I) or "/" in s:
        u = urlparse(s if re.match(r"^https?://", s, re.I) else "https://" + s)
        host = (u.hostname or "").lower()
        if not any(host == h or host.endswith("." + h) for h in SOCIAL_HOSTS[platform]):
            return None
        parts = [x for x in u.path.split("/") if x]
        if not parts:
            return None
        s = parts[0]
    s = s.lstrip("@").strip()
    return s.lower() if HANDLE_RE.match(s) else None


def social_entry(platform: str, handle: str):
    return {"username": handle, "url": SOCIAL_URL[platform].format(handle), "linked_at": iso()}


def social_view(user):
    """Social accounts of a user, falling back to the legacy profile.tiktok / profile.instagram fields."""
    social = dict(user.get("social") or {})
    for p in SOCIAL_PLATFORMS:
        if not social.get(p):
            handle = parse_social_handle(p, (user.get("profile") or {}).get(p) or "")
            social[p] = {"username": handle, "url": SOCIAL_URL[p].format(handle)} if handle else None
    tg = social.get("telegram")
    social["telegram"] = {"username": tg.get("username"), "name": tg.get("name"), "linked_at": tg.get("linked_at")} if tg else None
    return {p: social.get(p) for p in (*SOCIAL_PLATFORMS, "telegram")}


class SocialIn(BaseModel):
    handle: str = Field(min_length=1, max_length=200)


@api.get("/users/social")
async def get_social(user=Depends(get_user)):
    return social_view(user)


@api.put("/users/social/{platform}")
async def link_social(platform: Literal["tiktok", "instagram", "threads"], body: SocialIn, user=Depends(get_user)):
    handle = parse_social_handle(platform, body.handle)
    if not handle:
        raise HTTPException(400, f"Username / link {platform.capitalize()} tidak valid")
    other = await db.users.find_one({f"social.{platform}.username": handle, "user_id": {"$ne": user["user_id"]}},
                                    {"_id": 0, "user_id": 1})
    if other:
        raise HTTPException(409, f"Akun {platform.capitalize()} @{handle} sudah terhubung ke pengguna lain")
    await db.users.update_one({"user_id": user["user_id"]}, {"$set": {
        f"social.{platform}": social_entry(platform, handle), f"profile.{platform}": f"@{handle}"}})
    return social_view(await db.users.find_one({"user_id": user["user_id"]}, USER_PUBLIC))


@api.delete("/users/social/{platform}")
async def unlink_social(platform: Literal["tiktok", "instagram", "threads", "telegram"], user=Depends(get_user)):
    unset = {f"social.{platform}": ""}
    if platform in SOCIAL_PLATFORMS:
        unset[f"profile.{platform}"] = ""
    await db.users.update_one({"user_id": user["user_id"]}, {"$unset": unset})
    return social_view(await db.users.find_one({"user_id": user["user_id"]}, USER_PUBLIC))


def telegram_config():
    return {"token": os.environ.get("TELEGRAM_BOT_TOKEN", "").strip(),
            "bot": os.environ.get("TELEGRAM_BOT_USERNAME", "").strip().lstrip("@"),
            "group": clean_link(os.environ.get("TELEGRAM_GROUP_URL", ""))}


def clean_link(raw):
    m = re.search(r"https?://[^\s()\[\]\"'<>]+", raw or "")
    if m:
        return m.group(0)
    s = (raw or "").strip().lstrip("@")
    return f"https://t.me/{s}" if re.fullmatch(r"[A-Za-z0-9_+/-]{3,}", s) else ""


def telegram_webhook_secret(token):
    return hmac.new(token.encode(), b"ourbuzzer-telegram-webhook", hashlib.sha256).hexdigest()[:48]


@api.get("/public/community")
async def public_community():
    """Links for the 'Gabung Komunitas' button and the Telegram connect flow (no secrets)."""
    cfg = telegram_config()
    bot_url = f"https://t.me/{cfg['bot']}" if cfg["bot"] else ""
    return {"telegram_url": cfg["group"] or bot_url, "telegram_bot": cfg["bot"],
            "telegram_connect_enabled": bool(cfg["token"] and cfg["bot"])}


@api.post("/users/social/telegram/link")
async def telegram_link_start(user=Depends(get_user)):
    """One-time deep link to the Gibran for 2029 bot. Opening it (t.me/<bot>?start=<code>) links the
    Telegram account to this user and the bot replies with the community group invite."""
    cfg = telegram_config()
    if not (cfg["token"] and cfg["bot"]):
        raise HTTPException(503, "Integrasi Telegram belum dikonfigurasi")
    code = secrets.token_urlsafe(18)[:24].replace("-", "x")
    await db.telegram_links.insert_one({"code": code, "user_id": user["user_id"], "created_at": now(),
                                        "expires_at": now() + timedelta(minutes=15)})
    return {"url": f"https://t.me/{cfg['bot']}?start={code}", "expires_in": 900}


async def telegram_send(chat_id, text, button=None):
    cfg = telegram_config()
    payload = {"chat_id": chat_id, "text": text, "parse_mode": "HTML", "disable_web_page_preview": True}
    if button:
        payload["reply_markup"] = {"inline_keyboard": [[{"text": button[0], "url": button[1]}]]}
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            await c.post(f"https://api.telegram.org/bot{cfg['token']}/sendMessage", json=payload)
    except Exception as e:
        logger.warning("Telegram sendMessage failed: %s", e)


@api.post("/telegram/webhook")
async def telegram_webhook(request: Request):
    cfg = telegram_config()
    if not cfg["token"]:
        raise HTTPException(404, "Not found")
    if not hmac.compare_digest(request.headers.get("x-telegram-bot-api-secret-token", ""),
                               telegram_webhook_secret(cfg["token"])):
        raise HTTPException(403, "Forbidden")
    update = await request.json()
    msg = update.get("message") or {}
    text = (msg.get("text") or "").strip()
    sender = msg.get("from") or {}
    chat_id = (msg.get("chat") or {}).get("id")
    if not chat_id or (msg.get("chat") or {}).get("type") != "private" or not text.startswith("/start"):
        return {"ok": True}
    group = ("Masuk grup komunitas", cfg["group"]) if cfg["group"] else None
    code = text.split(maxsplit=1)[1].strip() if " " in text else ""
    if not code:
        await telegram_send(chat_id, "Halo! Ini bot resmi <b>Gibran for 2029</b>. Hubungkan akunmu dari halaman Profil "
                                     "di web atau aplikasi Gibran for 2029.", group)
        return {"ok": True}
    link = await db.telegram_links.find_one_and_delete({"code": code})
    if not link or _as_utc(link["expires_at"]) < now():
        await telegram_send(chat_id, "Link sudah kedaluwarsa atau sudah dipakai. Klik lagi <b>Hubungkan Telegram</b> "
                                     "di halaman Profil Gibran for 2029.")
        return {"ok": True}
    tg_id = sender.get("id")
    other = await db.users.find_one({"social.telegram.id": tg_id, "user_id": {"$ne": link["user_id"]}}, {"_id": 0, "user_id": 1})
    if other:
        await telegram_send(chat_id, "Akun Telegram ini sudah terhubung ke akun Gibran for 2029 lain.")
        return {"ok": True}
    name = " ".join(x for x in (sender.get("first_name"), sender.get("last_name")) if x)
    await db.users.update_one({"user_id": link["user_id"]}, {"$set": {"social.telegram": {
        "id": tg_id, "username": sender.get("username") or "", "name": name, "linked_at": iso()}}})
    await bump_sync()
    await notify(link["user_id"], "Telegram terhubung", f"Akun Telegram {('@' + sender['username']) if sender.get('username') else name} "
                                                        "sudah terhubung ke Gibran for 2029.", "success")
    await telegram_send(chat_id, "✅ Akun Telegram kamu sudah terhubung ke <b>Gibran for 2029</b>."
                                 + ("\nKetuk tombol di bawah untuk masuk ke grup komunitas kreator." if group else ""), group)
    return {"ok": True}


async def setup_telegram_webhook(base_url):
    cfg = telegram_config()
    if not cfg["token"] or not base_url:
        return {"ok": False, "reason": "TELEGRAM_BOT_TOKEN / URL publik belum diatur"}
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            r = await c.post(f"https://api.telegram.org/bot{cfg['token']}/setWebhook", json={
                "url": f"{base_url}/api/telegram/webhook", "secret_token": telegram_webhook_secret(cfg["token"]),
                "allowed_updates": ["message"]})
        data = r.json()
        logger.info("Telegram setWebhook: %s", data.get("description") or data.get("ok"))
        return {"ok": bool(data.get("ok")), "description": data.get("description", "")}
    except Exception as e:
        logger.warning("Telegram setWebhook failed: %s", e)
        return {"ok": False, "reason": str(e)}


@api.post("/admin/telegram/setup")
async def owner_setup_telegram(request: Request, owner=Depends(require_owner)):
    return await setup_telegram_webhook(callback_base_url(request))


# ---------------- Ledger (mutasi saldo) & pendapatan platform ----------------
LEDGER_LABELS = {
    "topup": "Top up saldo", "campaign_budget": "Budget campaign dikunci", "campaign_refund": "Sisa budget dikembalikan",
    "earning": "Pendapatan views", "withdraw_hold": "Penarikan saldo", "withdraw_refund": "Penarikan dibatalkan",
    "admin_credit": "Saldo ditambahkan admin", "owner_adjust": "Penyesuaian saldo",
}


async def add_ledger(user_id, type_, amount, ref, note="", **extra):
    await db.ledger.insert_one({"entry_id": gen_id("led"), "user_id": user_id, "type": type_, "amount": int(amount),
                                "ref": ref, "note": note, **extra, "created_at": iso()})


async def add_revenue(type_, amount, ref, user_id, fee_bp, base_amount):
    if amount > 0:
        await db.platform_revenue.insert_one({"revenue_id": gen_id("rev"), "type": type_, "amount": int(amount),
                                              "ref": ref, "user_id": user_id, "fee_pct": bp_to_pct(fee_bp),
                                              "base_amount": int(base_amount), "created_at": iso()})


@api.get("/config/fees")
async def fees_config():
    """Persentase fee untuk UI web & mobile (tanpa login, nilai publik)."""
    return {"brand_topup_fee_pct": bp_to_pct(BRAND_TOPUP_FEE_BP),
            "creator_withdraw_fee_pct": bp_to_pct(CREATOR_WITHDRAW_FEE_BP),
            "brand_withdraw_fee_pct": bp_to_pct(BRAND_WITHDRAW_FEE_BP),
            "min_topup": MIN_TOPUP, "min_withdraw": MIN_WITHDRAW}


@api.get("/ledger")
async def my_ledger(limit: int = 100, user=Depends(get_user)):
    """Riwayat mutasi saldo milik user yang login (kreator: saldo, brand: saldo brand)."""
    items = await db.ledger.find({"user_id": user["user_id"]}, {"_id": 0}).sort("created_at", -1).to_list(max(1, min(limit, 300)))
    for e in items:
        e.setdefault("note", "")
        e["label"] = LEDGER_LABELS.get(e["type"], e["type"])
    return items


# ---------------- Notifications ----------------
async def notify(user_id, title, body, kind="info"):
    await db.notifications.insert_one({
        "notification_id": gen_id("ntf"), "user_id": user_id, "title": title, "body": body,
        "kind": kind, "read": False, "created_at": iso(),
    })


# Review konten & klaim views hanya ditangani Admin Pusat (Owner). Notifikasi review lama yang
# dulu dikirim ke brand disaring dari kotak masuk brand (datanya tidak dihapus).
REVIEW_NOTIFICATION_TITLES = ["Submission baru", "Klaim views baru"]


async def notify_owners(title, body, kind="info"):
    owners = await db.users.find({"role": "admin", "is_owner": True}, {"_id": 0, "user_id": 1}).to_list(50)
    for o in owners:
        await notify(o["user_id"], title, body, kind)


def notification_filter(user):
    f = {"user_id": user["user_id"]}
    if user.get("role") == "brand":
        f["title"] = {"$nin": REVIEW_NOTIFICATION_TITLES}
    return f


@api.get("/notifications")
async def list_notifications(user=Depends(get_user)):
    f = notification_filter(user)
    items = await db.notifications.find(f, {"_id": 0}).sort("created_at", -1).to_list(30)
    unread = await db.notifications.count_documents({**f, "read": False})
    return {"items": items, "unread": unread}


@api.post("/notifications/read-all")
async def read_all(user=Depends(get_user)):
    await db.notifications.update_many({"user_id": user["user_id"]}, {"$set": {"read": True}})
    return {"ok": True}


# ---------------- Streak ----------------
def streak_info(post_dates):
    dates = set(post_dates or [])
    today = datetime.now(WIB).date()
    start = today if today.isoformat() in dates else today - timedelta(days=1)
    count = 0
    d = start
    while d.isoformat() in dates:
        count += 1
        d -= timedelta(days=1)
    days_id = ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
    week = []
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        week.append({"date": day.isoformat(), "label": "Hari ini" if i == 0 else days_id[day.weekday()],
                     "posted": day.isoformat() in dates})
    return {"streak": count, "posted_today": today.isoformat() in dates, "week": week}


# ---------------- Campaigns ----------------
class CampaignIn(BaseModel):
    title: str = Field(min_length=3, max_length=120)
    category: str
    platforms: List[Platform] = Field(min_length=1)
    rate_per_1k: int = Field(ge=500, le=1000000)
    min_views: int = Field(ge=100, le=100000000)
    budget: int = Field(ge=100000)
    thumbnail: Optional[str] = Field(default="", max_length=500)
    instructions: str = Field(min_length=10, max_length=5000)
    exclusive: bool = False
    deadline_days: int = Field(default=30, ge=1, le=180)


def campaign_view(c):
    c["budget_left_pct"] = round(100 * max(c["budget"] - c["spent"], 0) / c["budget"]) if c["budget"] else 0
    return c


@api.get("/campaigns")
async def list_campaigns(q: str = "", category: str = "", exclusive: bool = False, sort: str = "new"):
    f = {"status": "active", "exclusive": exclusive}
    if q:
        f["title"] = {"$regex": re.escape(q), "$options": "i"}
    if category and category != "Semua":
        f["category"] = category
    sort_key = {"new": ("created_at", -1), "rate": ("rate_per_1k", -1), "deadline": ("deadline", 1)}.get(sort, ("created_at", -1))
    items = await db.campaigns.find(f, {"_id": 0}).sort(*sort_key).to_list(200)
    return [campaign_view(c) for c in items]


@api.get("/campaigns/sections")
async def campaign_sections():
    base = {"status": "active", "exclusive": False}
    week_ago = (now() - timedelta(days=7)).isoformat()
    agg = await db.submissions.aggregate([
        {"$match": {"created_at": {"$gte": week_ago}}},
        {"$group": {"_id": "$campaign_id", "n": {"$sum": 1}}}, {"$sort": {"n": -1}}, {"$limit": 10},
    ]).to_list(10)
    ids = [a["_id"] for a in agg]
    trending = await db.campaigns.find({**base, "campaign_id": {"$in": ids}}, {"_id": 0}).to_list(10)
    trending.sort(key=lambda c: ids.index(c["campaign_id"]))
    if len(trending) < 6:
        extra = await db.campaigns.find({**base, "campaign_id": {"$nin": ids}}, {"_id": 0}).sort("submission_count", -1).to_list(6 - len(trending))
        trending += extra
    top_rate = await db.campaigns.find(base, {"_id": 0}).sort("rate_per_1k", -1).to_list(10)
    newest = await db.campaigns.find(base, {"_id": 0}).sort("created_at", -1).to_list(10)
    closing = await db.campaigns.find(base, {"_id": 0}).sort("deadline", 1).to_list(10)
    total = await db.campaigns.count_documents(base)
    total_ex = await db.campaigns.count_documents({"status": "active", "exclusive": True})
    m = lambda arr: [campaign_view(c) for c in arr]
    return {"trending": m(trending), "top_rate": m(top_rate), "newest": m(newest), "closing": m(closing),
            "total": total, "total_exclusive": total_ex}


@api.get("/campaigns/{cid}")
async def get_campaign(cid: str):
    c = await db.campaigns.find_one({"campaign_id": cid, "deleted": {"$ne": True}}, {"_id": 0})
    if not c:
        raise HTTPException(404, "Campaign tidak ditemukan")
    return campaign_view(c)


@api.post("/campaigns")
async def create_campaign(body: CampaignIn, user=Depends(require("brand"))):
    if body.category not in CATEGORIES:
        raise HTTPException(400, "Kategori tidak valid")
    res = await db.users.find_one_and_update(
        {"user_id": user["user_id"], "brand_balance": {"$gte": body.budget}},
        {"$inc": {"brand_balance": -body.budget}}, return_document=ReturnDocument.AFTER)
    if not res:
        raise HTTPException(400, "Saldo brand tidak cukup. Silakan top up terlebih dahulu.")
    d = body.model_dump()
    days = d.pop("deadline_days")
    c = {**d, "campaign_id": gen_id("cmp"), "brand_id": user["user_id"],
         "brand_name": user.get("profile", {}).get("brand_name") or user["name"],
         "spent": 0, "submission_count": 0, "total_views": 0, "status": "active",
         "deadline": (now() + timedelta(days=days)).isoformat(), "created_at": iso()}
    await db.campaigns.insert_one(c)
    await add_ledger(user["user_id"], "campaign_budget", -body.budget, c["campaign_id"], c["title"])
    c.pop("_id", None)
    return campaign_view(c)


class StatusIn(BaseModel):
    status: Literal["active", "paused", "closed"]


async def change_campaign_status(c, status, actor):
    """Pause / resume / close. Closing rejects open submissions and refunds the unspent budget to the
    brand (not for Owner-funded campaigns, whose budget never came from the brand)."""
    if c["status"] == "closed":
        raise HTTPException(400, "Campaign sudah ditutup")
    upd = await db.campaigns.find_one_and_update({"campaign_id": c["campaign_id"], "status": {"$ne": "closed"}},
                                                 {"$set": {"status": status, "updated_at": iso()}},
                                                 return_document=ReturnDocument.AFTER)
    if not upd:
        raise HTTPException(400, "Campaign sudah ditutup")
    refund = 0
    if status == "closed":
        await reject_open_submissions(c["campaign_id"])
        if upd.get("funded_by", "brand") != "owner":
            refund = max(upd["budget"] - upd["spent"], 0)
            if refund:
                await db.users.update_one({"user_id": c["brand_id"]}, {"$inc": {"brand_balance": refund}})
                await add_ledger(c["brand_id"], "campaign_refund", refund, c["campaign_id"], c["title"])
    await audit_if_owner(actor, "campaign.status", c["title"], {"campaign_id": c["campaign_id"], "status": status,
                                                                **({"refund": refund} if refund else {})})
    return refund


SYSTEM_ACTOR = {"user_id": "system", "name": "Sistem", "role": "admin", "is_owner": False}


async def close_expired_campaigns():
    """Tutup otomatis campaign yang deadline-nya lewat; sisa budget langsung kembali ke saldo brand."""
    expired = await db.campaigns.find({"status": {"$in": ["active", "paused"]}, "deadline": {"$lt": iso()},
                                       "deleted": {"$ne": True}}, {"_id": 0}).to_list(200)
    closed = 0
    for c in expired:
        try:
            refund = await change_campaign_status(c, "closed", SYSTEM_ACTOR)
        except HTTPException:
            continue  # sudah ditutup oleh proses lain
        closed += 1
        await notify(c["brand_id"], "Campaign selesai", c["title"] + " berakhir (masa berlaku habis)."
                     + (f" Sisa budget {rupiah(refund)} dikembalikan ke saldo brand." if refund else ""), "info")
    if closed:
        await bump_sync()
    return closed


async def _campaign_expiry_loop():
    while True:
        try:
            await close_expired_campaigns()
        except Exception:
            logger.exception("Auto-close campaign gagal")
        await asyncio.sleep(CAMPAIGN_EXPIRY_CHECK_SECONDS)


@api.patch("/campaigns/{cid}/status")
async def campaign_status(cid: str, body: StatusIn, user=Depends(require("brand", "admin"))):
    c = await db.campaigns.find_one({"campaign_id": cid, "deleted": {"$ne": True}}, {"_id": 0})
    if not c or (user["role"] == "brand" and c["brand_id"] != user["user_id"]):
        raise HTTPException(404, "Campaign tidak ditemukan")
    refund = await change_campaign_status(c, body.status, user)
    return {"ok": True, "refund": refund}


OPEN_STATUSES = ["direview", "menunggu_views", "diproses", "verifying"]


async def reject_open_submissions(cid, exclude=None):
    f = {"campaign_id": cid, "status": {"$in": OPEN_STATUSES}}
    if exclude:
        f["submission_id"] = {"$ne": exclude}
    pend = await db.submissions.find(f, {"_id": 0}).to_list(5000)
    await db.submissions.update_many(f, {"$set": {"status": "ditolak", "note": "Campaign ditutup", "updated_at": iso()}})
    for p in pend:
        await notify(p["creator_id"], p["campaign_title"], "Campaign ditutup, submission dibatalkan.", "error")


@api.get("/brand/campaigns")
async def brand_campaigns(user=Depends(require("brand"))):
    items = await db.campaigns.find({"brand_id": user["user_id"], "deleted": {"$ne": True}}, {"_id": 0}).sort("created_at", -1).to_list(200)
    counts = await creator_counts([c["campaign_id"] for c in items])
    return [{**campaign_view(c), "creator_count": counts.get(c["campaign_id"], 0)} for c in items]


async def creator_counts(campaign_ids):
    """Jumlah kreator unik per campaign (agregat saja — brand tidak melihat data submission)."""
    if not campaign_ids:
        return {}
    rows = await db.submissions.aggregate([
        {"$match": {"campaign_id": {"$in": campaign_ids}}},
        {"$group": {"_id": {"c": "$campaign_id", "u": "$creator_id"}}},
        {"$group": {"_id": "$_id.c", "n": {"$sum": 1}}},
    ]).to_list(1000)
    return {r["_id"]: r["n"] for r in rows}


# ---------------- Submissions ----------------
class SubmissionIn(BaseModel):
    campaign_id: str
    platform: Platform
    video_url: str = Field(max_length=500)


def normalize_url(url):
    m = re.match(r"^(https?)://([^/?#]+)([^?#]*)", url.strip())
    if not m:
        return url.strip()
    host = m.group(2).lower().split(":")[0]
    for pre in ("www.", "m.", "vm.", "vt."):
        if host.startswith(pre):
            host = host[len(pre):]
            break
    path = m.group(3).rstrip('/')
    if host == "youtube.com" and path == "/watch":
        v = re.search(r"[?&]v=([\w-]+)", url)
        if v:
            return f"https://youtube.com/shorts/{v.group(1)}"
    if host == "youtu.be":
        return f"https://youtube.com/shorts{path}"
    return f"https://{host}{path}"


def valid_url(url, platform):
    m = re.match(r"^https?://([^/]+)/\S+$", url.strip())
    if not m:
        return False
    host = m.group(1).lower().split(":")[0]
    return any(host == d or host.endswith("." + d) for d in PLATFORM_DOMAINS[platform])


@api.post("/submissions")
async def create_submission(body: SubmissionIn, user=Depends(require("creator"))):
    c = await db.campaigns.find_one({"campaign_id": body.campaign_id}, {"_id": 0})
    if not c or c["status"] != "active":
        raise HTTPException(400, "Campaign tidak aktif")
    if body.platform not in c["platforms"]:
        raise HTTPException(400, "Platform tidak diterima di campaign ini")
    if not valid_url(body.video_url, body.platform):
        raise HTTPException(400, f"Link bukan link {body.platform} yang valid")
    url = normalize_url(body.video_url)
    if await db.submissions.find_one({"video_url": url}):
        raise HTTPException(400, "Video ini sudah pernah didaftarkan")
    s = {"submission_id": gen_id("sub"), "campaign_id": c["campaign_id"], "campaign_title": c["title"],
         "brand_id": c["brand_id"], "creator_id": user["user_id"], "creator_name": user["name"],
         "platform": body.platform, "video_url": url, "status": "direview", "claimed_views": 0,
         "verified_views": 0, "payout": 0, "rate_per_1k": c["rate_per_1k"], "min_views": c["min_views"],
         "note": "", "created_at": iso(), "updated_at": iso()}
    await db.submissions.insert_one(s)
    await db.campaigns.update_one({"campaign_id": c["campaign_id"]}, {"$inc": {"submission_count": 1}})
    today = datetime.now(WIB).date().isoformat()
    await db.users.update_one({"user_id": user["user_id"]}, {"$addToSet": {"post_dates": today}})
    await notify_owners("Submission baru", f"{user['name']} submit video ke {c['title']}")
    await notify(user["user_id"], c["title"], "Video terkirim dan sedang direview Admin Gibran for 2029.")
    s.pop("_id", None)
    return s


@api.get("/creator/submissions")
async def creator_submissions(user=Depends(require("creator"))):
    return with_proof_urls(await db.submissions.find({"creator_id": user["user_id"]}, {"_id": 0}).sort("created_at", -1).to_list(500))


@api.get("/creator/stats")
async def creator_stats(user=Depends(require("creator"))):
    subs = await db.submissions.find({"creator_id": user["user_id"]}, {"_id": 0}).to_list(1000)
    pending = sum(int(s["claimed_views"] / 1000 * s["rate_per_1k"]) for s in subs if s["status"] == "diproses")
    return {"balance": user.get("balance", 0), "total_earned": user.get("total_earned", 0), "pending": pending,
            "videos": len(subs), "campaigns": len({s["campaign_id"] for s in subs}),
            "streak": streak_info(user.get("post_dates"))}


@api.get("/streak")
async def my_streak(user=Depends(get_user)):
    return streak_info(user.get("post_dates"))


class ClaimIn(BaseModel):
    views: int = Field(ge=1, le=10_000_000_000)


@api.post("/submissions/{sid}/claim")
async def claim_views(sid: str, body: ClaimIn, user=Depends(require("creator"))):
    """Klaim tanpa bukti sudah tidak diterima: kreator wajib melampirkan rekaman layar/screenshot
    analitik lewat POST /submissions/{sid}/claim-proof (aplikasi versi lama mendapat pesan ini)."""
    raise HTTPException(400, "Klaim sekarang wajib melampirkan bukti rekaman layar/screenshot analitik. "
                             "Perbarui aplikasi Gibran for 2029 lalu klaim lewat tombol Klaim.")


# ---------------- Bukti klaim (screenshot / rekaman layar analitik) ----------------
MAX_PROOF_FILES = 3
MAX_PROOF_IMAGE_BYTES = 3 * 1024 * 1024
MAX_PROOF_VIDEO_BYTES = 15 * 1024 * 1024
PROOF_URL_TTL = 6 * 3600
_PROOF_SECRET = (os.environ.get("PROOF_URL_SECRET") or os.environ.get("OTP_SECRET") or secrets.token_hex(32)).encode()


def sniff_video(b: bytes):
    if b[4:8] == b"ftyp":
        return "video/quicktime" if b[8:10] == b"qt" else "video/mp4"
    if b[:4] == b"\x1a\x45\xdf\xa3":
        return "video/webm"
    return None


def proof_sig(pid: str, exp: int) -> str:
    return hmac.new(_PROOF_SECRET, f"{pid}.{exp}".encode(), hashlib.sha256).hexdigest()[:32]


def proof_url(pid: str) -> str:
    """Path relatif bertanda tangan (berlaku >= 6 jam, stabil per jam supaya bisa di-cache)."""
    exp = (int(time.time()) // 3600 + 1) * 3600 + PROOF_URL_TTL
    return f"/api/proofs/{pid}?exp={exp}&sig={proof_sig(pid, exp)}"


def with_proof_urls(subs):
    """Tambahkan `url` ke tiap bukti. Hanya dipanggil di endpoint yang sudah membatasi siapa yang
    boleh melihat submission tersebut (kreator pemilik, brand pemilik campaign, admin)."""
    for s in subs:
        for p in s.get("proofs") or []:
            p["url"] = proof_url(p["proof_id"])
    return subs


async def read_proof_file(f: UploadFile):
    data = await f.read(MAX_PROOF_VIDEO_BYTES + 1)
    ctype = sniff_image(data)
    if ctype:
        if len(data) > MAX_PROOF_IMAGE_BYTES:
            raise HTTPException(413, "Ukuran screenshot maksimal 3 MB")
        return data, ctype, "image"
    ctype = sniff_video(data)
    if ctype:
        if len(data) > MAX_PROOF_VIDEO_BYTES:
            raise HTTPException(413, "Ukuran rekaman layar maksimal 15 MB. Potong videonya jadi lebih pendek.")
        return data, ctype, "video"
    raise HTTPException(400, "Bukti harus gambar (JPG/PNG/WebP) atau video (MP4/MOV/WebM)")


@api.post("/submissions/{sid}/claim-proof")
async def claim_with_proof(sid: str, views: int = Form(...), note: str = Form(""),
                           files: List[UploadFile] = File(...), user=Depends(require("creator"))):
    """Klaim views + unggah bukti analitik (1-3 file). Brand/admin memverifikasi manual dari bukti ini."""
    if not 1 <= views <= 10_000_000_000:
        raise HTTPException(400, "Jumlah views tidak valid")
    files = [f for f in files if f is not None and (f.filename or f.size)]
    if not files:
        raise HTTPException(400, "Lampirkan minimal 1 screenshot atau rekaman layar analitik")
    if len(files) > MAX_PROOF_FILES:
        raise HTTPException(400, f"Maksimal {MAX_PROOF_FILES} file bukti")
    s = await db.submissions.find_one({"submission_id": sid, "creator_id": user["user_id"]}, {"_id": 0})
    if not s:
        raise HTTPException(404, "Submission tidak ditemukan")
    if s["status"] != "menunggu_views":
        raise HTTPException(400, "Submission belum bisa diklaim")
    c = await db.campaigns.find_one({"campaign_id": s["campaign_id"]}, {"_id": 0, "status": 1})
    if not c or c["status"] == "closed":
        raise HTTPException(400, "Campaign sudah ditutup")
    if views < s["min_views"]:
        raise HTTPException(400, f"Views minimal {s['min_views']}")
    parsed = [await read_proof_file(f) for f in files]  # validasi semua dulu, baru simpan
    proofs = []
    for data, ctype, kind in parsed:
        pid = gen_id("prf")
        await db.uploads.insert_one({"upload_id": pid, "owner_id": user["user_id"], "content_type": ctype,
                                     "kind": "proof", "submission_id": sid, "size": len(data), "data": data,
                                     "created_at": iso()})
        proofs.append({"proof_id": pid, "kind": kind, "content_type": ctype, "size": len(data)})
    r = await db.submissions.update_one(
        {"submission_id": sid, "status": "menunggu_views"},
        {"$set": {"status": "diproses", "claimed_views": views, "proofs": proofs,
                  "claim_note": (note or "").strip()[:500], "claimed_at": iso(), "updated_at": iso()}})
    if not r.modified_count:
        await db.uploads.delete_many({"upload_id": {"$in": [p["proof_id"] for p in proofs]}})
        raise HTTPException(400, "Status submission sudah berubah")
    await notify_owners("Klaim views baru",
                        f"{user['name']} klaim {views:,} views + {len(proofs)} bukti analitik".replace(",", "."))
    await notify(user["user_id"], s["campaign_title"],
                 "Klaim & bukti diterima. Views sedang dicek Admin Gibran for 2029.")
    return {"ok": True, "proofs": with_proof_urls([{"proofs": proofs}])[0]["proofs"]}


@api.get("/proofs/{pid}")
async def get_proof(pid: str, request: Request, exp: int = 0, sig: str = ""):
    if exp < time.time() or not hmac.compare_digest(sig, proof_sig(pid, exp)):
        raise HTTPException(403, "Link bukti kedaluwarsa, muat ulang halaman")
    d = await db.uploads.find_one({"upload_id": pid, "kind": "proof"}, {"_id": 0, "data": 1, "content_type": 1})
    if not d:
        raise HTTPException(404, "Bukti tidak ditemukan")
    data = bytes(d["data"])
    headers = {"Cache-Control": "private, max-age=3600", "X-Content-Type-Options": "nosniff",
               "Accept-Ranges": "bytes"}
    m = re.match(r"bytes=(\d*)-(\d*)$", request.headers.get("range", "").strip())
    if m and (m.group(1) or m.group(2)):
        n = len(data)
        if m.group(1):
            start, end = int(m.group(1)), int(m.group(2)) if m.group(2) else n - 1
        else:
            start, end = max(n - int(m.group(2)), 0), n - 1
        end = min(end, n - 1)
        if start >= n or start > end:
            return Response(status_code=416, headers={"Content-Range": f"bytes */{n}"})
        headers["Content-Range"] = f"bytes {start}-{end}/{n}"
        return Response(content=data[start:end + 1], status_code=206, media_type=d["content_type"], headers=headers)
    return Response(content=data, media_type=d["content_type"], headers=headers)


class ReviewIn(BaseModel):
    action: Literal["approve", "reject"]
    note: Optional[str] = ""


@api.post("/submissions/{sid}/review")
async def review_content(sid: str, body: ReviewIn, user=Depends(require_owner)):
    """Setujui/tolak konten. Hanya Admin Pusat (Owner) — brand tidak ikut me-review."""
    s = await db.submissions.find_one({"submission_id": sid}, {"_id": 0})
    if not s:
        raise HTTPException(404, "Submission tidak ditemukan")
    new = "menunggu_views" if body.action == "approve" else "ditolak"
    c = await db.campaigns.find_one({"campaign_id": s["campaign_id"]}, {"_id": 0, "status": 1})
    if new == "menunggu_views" and (not c or c["status"] == "closed"):
        raise HTTPException(400, "Campaign sudah ditutup")
    r = await db.submissions.update_one({"submission_id": sid, "status": "direview"},
                                        {"$set": {"status": new, "note": body.note or "", "updated_at": iso()}})
    if not r.modified_count:
        raise HTTPException(400, "Status submission sudah berubah")
    msg = ("Konten disetujui & siap diklaim. Kirim rekaman layar analitik saat views sudah mencapai target."
           if new == "menunggu_views" else f"Konten ditolak. {body.note or ''}".strip())
    await notify(s["creator_id"], s["campaign_title"], msg, "success" if new != "ditolak" else "error")
    await audit_if_owner(user, f"submission.review.{body.action}", s["campaign_title"],
                         {"submission_id": sid, "creator": s["creator_name"]})
    return {"ok": True}


class VerifyIn(BaseModel):
    action: Literal["approve", "reject"]
    verified_views: int = Field(default=0, ge=0)
    note: Optional[str] = ""


@api.post("/submissions/{sid}/verify")
async def verify_views(sid: str, body: VerifyIn, user=Depends(require_owner)):
    """Cek views & bukti klaim lalu bayar kreator. Hanya Admin Pusat (Owner)."""
    s = await db.submissions.find_one({"submission_id": sid}, {"_id": 0})
    if not s:
        raise HTTPException(404, "Submission tidak ditemukan")
    lock = await db.submissions.find_one_and_update({"submission_id": sid, "status": "diproses"},
                                                    {"$set": {"status": "verifying"}})
    if not lock:
        raise HTTPException(400, "Submission tidak dalam status diproses")
    if body.action == "reject" or body.verified_views < s["min_views"]:
        note = body.note or ("Views di bawah minimum" if body.action == "approve" else "")
        await db.submissions.update_one({"submission_id": sid}, {"$set": {
            "status": "ditolak", "verified_views": body.verified_views, "note": note, "updated_at": iso()}})
        await notify(s["creator_id"], s["campaign_title"], f"Klaim views ditolak. {note}", "error")
        await audit_if_owner(user, "submission.verify.reject", s["campaign_title"],
                             {"submission_id": sid, "creator": s["creator_name"], **({"note": note} if note else {})})
        return {"ok": True, "payout": 0}
    payout = int(body.verified_views / 1000 * s["rate_per_1k"])
    amount = None
    try:
        for _ in range(5):
            c = await db.campaigns.find_one({"campaign_id": s["campaign_id"]}, {"_id": 0})
            if not c or c["status"] == "closed":
                break
            amt = min(payout, max(c["budget"] - c["spent"], 0))
            r = await db.campaigns.update_one({"campaign_id": c["campaign_id"], "spent": c["spent"], "status": {"$ne": "closed"}},
                                              {"$inc": {"spent": amt, "total_views": body.verified_views}})
            if r.modified_count:
                amount = amt
                break
    except Exception:
        await db.submissions.update_one({"submission_id": sid}, {"$set": {"status": "diproses"}})
        raise
    if amount is None:
        c = await db.campaigns.find_one({"campaign_id": s["campaign_id"]}, {"_id": 0, "status": 1})
        if not c or c["status"] == "closed":
            await db.submissions.update_one({"submission_id": sid}, {"$set": {"status": "ditolak", "note": "Campaign ditutup", "updated_at": iso()}})
            raise HTTPException(400, "Campaign sudah ditutup")
        await db.submissions.update_one({"submission_id": sid}, {"$set": {"status": "diproses"}})
        raise HTTPException(409, "Campaign sudah ditutup atau sedang sibuk, coba lagi")
    await db.submissions.update_one({"submission_id": sid}, {"$set": {
        "status": "disetujui", "verified_views": body.verified_views, "payout": amount,
        "note": body.note or "", "updated_at": iso()}})
    if amount:
        await db.users.update_one({"user_id": s["creator_id"]}, {"$inc": {"balance": amount, "total_earned": amount}})
        await add_ledger(s["creator_id"], "earning", amount, sid,
                         f"{s['campaign_title']} · {body.verified_views:,} views".replace(",", "."))
    c = await db.campaigns.find_one({"campaign_id": s["campaign_id"]}, {"_id": 0})
    # Tutup otomatis hanya untuk campaign berbudget (campaign aksi gerakan tidak punya budget).
    if c.get("budget", 0) > 0 and c["spent"] >= c["budget"] and c["status"] == "active":
        await db.campaigns.update_one({"campaign_id": c["campaign_id"]}, {"$set": {"status": "closed"}})
        await reject_open_submissions(c["campaign_id"], exclude=sid)
    await notify(s["creator_id"], s["campaign_title"], f"Views terverifikasi! +Rp {amount:,}".replace(",", "."), "success")
    await audit_if_owner(user, "submission.verify.approve", s["campaign_title"],
                         {"submission_id": sid, "creator": s["creator_name"], "views": body.verified_views, "payout": amount})
    return {"ok": True, "payout": amount}


@api.get("/brand/submissions")
async def brand_submissions(user=Depends(require("brand"))):
    """Brand tidak lagi melihat/menangani submission kreator; cukup ringkasan di /brand/stats
    dan /brand/campaigns. Endpoint dipertahankan agar aplikasi lama mendapat pesan yang jelas."""
    raise HTTPException(403, "Review konten kreator kini dikelola Admin Pusat Gibran for 2029. "
                             "Lihat ringkasan campaign di dashboard brand.")


# ---------------- Withdrawals (kreator & brand) ----------------
class WithdrawIn(BaseModel):
    amount: int = Field(ge=MIN_WITHDRAW)
    method: str = Field(min_length=2, max_length=30)
    account_number: str = Field(min_length=5, max_length=30)
    account_holder: str = Field(min_length=2, max_length=80)


BALANCE_FIELD = {"creator": "balance", "brand": "brand_balance"}


def withdraw_quote(amount: int, role: str):
    bp = CREATOR_WITHDRAW_FEE_BP if role == "creator" else BRAND_WITHDRAW_FEE_BP
    fee = fee_amount(amount, bp)
    return {"amount": amount, "fee": fee, "fee_pct": bp_to_pct(bp), "net_amount": amount - fee}, bp


async def _create_withdrawal(body: WithdrawIn, user):
    """Saldo dipotong penuh (Rp Y) saat diajukan; admin mentransfer net = Y - fee. Ditolak → Y kembali."""
    role = user["role"]
    field = BALANCE_FIELD[role]
    q, bp = withdraw_quote(body.amount, role)
    res = await db.users.find_one_and_update({"user_id": user["user_id"], field: {"$gte": body.amount}},
                                             {"$inc": {field: -body.amount}})
    if not res:
        raise HTTPException(400, "Saldo tidak cukup")
    name = (user.get("profile") or {}).get("brand_name") or user["name"] if role == "brand" else user["name"]
    w = {"withdrawal_id": gen_id("wd"), "role": role, "creator_id": user["user_id"], "creator_name": name,
         "creator_email": user["email"], **body.model_dump(), **q, "status": "diproses", "reference": "",
         "created_at": iso(), "updated_at": iso()}
    await db.withdrawals.insert_one(w)
    await add_ledger(user["user_id"], "withdraw_hold", -body.amount, w["withdrawal_id"],
                     f"{body.method} · diterima {rupiah(q['net_amount'])}" + (f" (biaya {q['fee_pct']}% {rupiah(q['fee'])})" if q["fee"] else ""),
                     fee=q["fee"], net_amount=q["net_amount"])
    w.pop("_id", None)
    return w


@api.get("/withdrawals/quote")
async def quote_withdrawal(amount: int, user=Depends(require("creator", "brand"))):
    return withdraw_quote(max(int(amount), 0), user["role"])[0]


@api.post("/withdrawals")
async def create_withdrawal(body: WithdrawIn, user=Depends(require("creator"))):
    return await _create_withdrawal(body, user)


@api.get("/creator/withdrawals")
async def my_withdrawals(user=Depends(require("creator"))):
    return await db.withdrawals.find({"creator_id": user["user_id"]}, {"_id": 0}).sort("created_at", -1).to_list(200)


@api.post("/brand/withdrawals")
async def create_brand_withdrawal(body: WithdrawIn, user=Depends(require("brand"))):
    """Brand mencairkan saldo mengendap (termasuk sisa budget yang sudah di-refund) ke rekening."""
    return await _create_withdrawal(body, user)


@api.get("/brand/withdrawals")
async def brand_withdrawals(user=Depends(require("brand"))):
    return await db.withdrawals.find({"creator_id": user["user_id"]}, {"_id": 0}).sort("created_at", -1).to_list(200)


# ---------------- Brand top-up (Komerce) ----------------
class TopupIn(BaseModel):
    amount: int = Field(ge=MIN_TOPUP, le=10_000_000_000)  # saldo yang masuk ke dompet brand (Rp X)
    payment_type: Literal["qris", "bank_transfer"]
    channel_code: Optional[str] = "BCA"
    phone: Optional[str] = "081200000000"


def komerce_config():
    """Read at call time so a changed .env / host env var only needs a restart, never a code change."""
    base = (os.environ.get('KOMERCE_BASE_URL') or '').strip().rstrip('/')
    key = (os.environ.get('KOMERCE_API_KEY') or '').strip()
    return base, key


def komerce_configured():
    base, key = komerce_config()
    return bool(base and key)


def komerce_headers():
    base, key = komerce_config()
    if not base or not key:
        raise HTTPException(503, "Pembayaran Komerce belum dikonfigurasi")
    return {"x-api-key": key, "Content-Type": "application/json"}


def komerce_url(path):
    return komerce_config()[0] + path


def clean_base_url(raw) -> str:
    """Turn whatever was pasted into an env var into 'https://host[:port]', or '' if unusable.
    Accepts 'host.app', ' "https://host.app/" ', 'https://host.app/api', '[https://host.app](https://host.app)'."""
    s = (raw or "").strip().strip("\"'").strip()
    if not s:
        return ""
    m = re.search(r"https?://[^\s()\[\]\"'<>]+", s)
    s = m.group(0) if m else "https://" + s.lstrip("/")
    p = urlparse(s)
    host = (p.hostname or "").lower()
    if p.scheme not in ("http", "https") or "." not in host or not re.fullmatch(r"[a-z0-9.-]+", host):
        return ""
    return f"{p.scheme}://{host}" + (f":{p.port}" if p.port else "")


def callback_base_url(request: Request) -> str:
    """Base URL Komerce calls back. Must be a public URL that reaches this backend:
    PUBLIC_BASE_URL (cleaned) → Railway's own public domain → the web origin (proxied /api) → headers."""
    for raw in (os.environ.get("PUBLIC_BASE_URL"), os.environ.get("RAILWAY_PUBLIC_DOMAIN")):
        base = clean_base_url(raw)
        if base:
            return base
    return public_base_url(request, prefer_origin=True)


def public_base_url(request: Request, prefer_origin=False):
    """Public URL of this backend (for Komerce callback_url and uploaded image URLs).
    PUBLIC_BASE_URL wins; otherwise derived from proxy headers (Railway/Render/etc. set X-Forwarded-*)."""
    env = clean_base_url(os.environ.get('PUBLIC_BASE_URL'))
    if env:
        return env
    if prefer_origin and request.headers.get("origin"):
        return request.headers["origin"].rstrip('/')
    proto = (request.headers.get("x-forwarded-proto") or request.url.scheme).split(",")[0].strip()
    host = request.headers.get("x-forwarded-host") or request.headers.get("host") or request.url.netloc
    return f"{proto}://{host}"


def komerce_error(r, data):
    meta_msg = (data.get("meta") or {}).get("message") if isinstance(data, dict) else None
    if r.status_code in (401, 403):
        return "API key Komerce ditolak. Periksa KOMERCE_API_KEY."
    if r.status_code == 404 and not meta_msg:
        return "Endpoint Komerce tidak ditemukan. Periksa KOMERCE_BASE_URL."
    return meta_msg or "Gagal membuat pembayaran"


async def mark_topup_paid(topup):
    r = await db.topups.update_one({"topup_id": topup["topup_id"], "status": "pending"},
                                   {"$set": {"status": "paid", "paid_at": iso()}})
    if r.modified_count:
        fee = int(topup.get("fee") or 0)  # top-up lama (sebelum ada fee) tidak punya field fee
        total = int(topup.get("total") or topup["amount"] + fee)
        await db.users.update_one({"user_id": topup["brand_id"]}, {"$inc": {"brand_balance": topup["amount"]}})
        await add_ledger(topup["brand_id"], "topup", topup["amount"], topup["topup_id"],
                         f"Dibayar {rupiah(total)}" + (f" (termasuk biaya layanan {rupiah(fee)})" if fee else ""),
                         fee=fee, total=total)
        await add_revenue("topup_fee", fee, topup["topup_id"], topup["brand_id"],
                          int(round(float(topup.get("fee_pct") or 0) * 100)), topup["amount"])
        await notify(topup["brand_id"], "Top up berhasil", f"Saldo brand +Rp {topup['amount']:,}".replace(",", "."), "success")
        await bump_sync()  # may run from the background reconciler, outside any request


def topup_quote(amount: int):
    fee = fee_amount(amount, BRAND_TOPUP_FEE_BP)
    return {"amount": amount, "fee": fee, "fee_pct": bp_to_pct(BRAND_TOPUP_FEE_BP), "total": amount + fee}


@api.get("/brand/topups/quote")
async def quote_topup(amount: int, user=Depends(require("brand"))):
    return topup_quote(max(int(amount), 0))


@api.post("/brand/topups")
async def create_topup(body: TopupIn, request: Request, user=Depends(require("brand"))):
    """Tagihan = saldo masuk (X) + biaya layanan platform. Setelah lunas, hanya X yang masuk saldo brand."""
    headers = komerce_headers()
    q = topup_quote(body.amount)
    topup_id = gen_id("TOP").upper()
    cb_key = secrets.token_hex(16)
    callback_url = f"{callback_base_url(request)}/api/payments/komerce/callback"
    items = [{"name": "Top up saldo campaign", "quantity": 1, "price": q["amount"]}]
    if q["fee"]:
        items.append({"name": f"Biaya layanan platform ({q['fee_pct']}%)", "quantity": 1, "price": q["fee"]})
    payload = {"order_id": topup_id, "payment_type": body.payment_type, "amount": q["total"],
               "customer": {"name": user["name"], "email": user["email"], "phone": body.phone or "081200000000"},
               "items": items,
               "callback_url": callback_url, "callback_api_key": cb_key}
    if body.payment_type == "bank_transfer":
        payload["channel_code"] = body.channel_code or "BCA"
        payload["expiry_duration"] = 86400
    try:
        async with httpx.AsyncClient(timeout=30) as c:
            r = await c.post(komerce_url("/api/v1/user/payment/create"), json=payload, headers=headers)
    except httpx.HTTPError as e:
        logger.error("Komerce create unreachable: %r", e)
        raise HTTPException(502, "Tidak bisa menghubungi Komerce. Coba lagi sebentar.")
    try:
        data = r.json()
    except ValueError:
        data = {}
    if r.status_code >= 300 or not isinstance(data, dict) or not data.get("data"):
        logger.error("Komerce create failed %s %s (callback_url=%s)", r.status_code, r.text[:500], callback_url)
        raise HTTPException(502, komerce_error(r, data if isinstance(data, dict) else {}))
    d = data["data"]
    t = {"topup_id": topup_id, "brand_id": user["user_id"], **q, "payment_type": body.payment_type,
         "channel_code": payload.get("channel_code", ""), "payment_id": d.get("payment_id"),
         "va_number": d.get("va_number", ""), "qr_string": d.get("qr_string", ""),
         "payment_url": d.get("payment_url") or d.get("url") or "", "callback_key": cb_key,
         "callback_url": callback_url, "status": "pending", "created_at": iso()}
    await db.topups.insert_one(t)
    t.pop("_id", None)
    t.pop("callback_key", None)
    t.pop("callback_url", None)
    return t


@api.get("/brand/topups")
async def list_topups(user=Depends(require("brand"))):
    return await db.topups.find({"brand_id": user["user_id"]}, {"_id": 0, "callback_key": 0, "callback_url": 0}).sort("created_at", -1).to_list(100)


async def sync_topup(t):
    """Ask Komerce for the real status and apply it. Never trusts callback bodies directly."""
    if not t.get("payment_id"):
        return ""
    try:
        async with httpx.AsyncClient(timeout=20) as c:
            r = await c.get(komerce_url(f"/api/v1/user/payment/status/{t['payment_id']}"), headers=komerce_headers())
        data = r.json() if r.status_code == 200 else {}
    except (httpx.HTTPError, ValueError) as e:
        logger.warning("Komerce status check failed for %s: %r", t["topup_id"], e)
        return ""
    status = (((data or {}).get("data") or {}).get("status") or "").upper()
    if status in ("PAID", "SUCCESS", "SETTLED", "COMPLETED"):
        await mark_topup_paid(t)
    elif status in ("EXPIRED", "CANCELED", "CANCELLED", "FAILED"):
        await db.topups.update_one({"topup_id": t["topup_id"], "status": "pending"},
                                   {"$set": {"status": "canceled" if status.startswith("CANCEL") else status.lower()}})
    return status


# Background reconciliation: credits paid top-ups even when the Komerce callback never reaches
# this server (wrong PUBLIC_BASE_URL, local dev, outage) and the brand closed the app.
RECONCILE_SECONDS = int(os.environ.get("KOMERCE_RECONCILE_SECONDS", "60") or 0)


async def reconcile_pending_topups_once(limit=20, pause=3.5):
    if not komerce_configured():
        return 0
    cutoff = (now() - timedelta(hours=25)).isoformat()
    pending = await db.topups.find({"status": "pending", "created_at": {"$gte": cutoff}},
                                   {"_id": 0}).sort("created_at", -1).to_list(limit)
    for i, t in enumerate(pending):
        await sync_topup(t)
        if i < len(pending) - 1:
            await asyncio.sleep(pause)  # Komerce allows max 1 request / 3s
    return len(pending)


async def _reconcile_loop():
    while True:
        try:
            await reconcile_pending_topups_once()
        except Exception:
            logger.exception("Top-up reconciliation failed")
        await asyncio.sleep(RECONCILE_SECONDS)


@api.get("/payments/config")
async def payments_config(user=Depends(get_user)):
    """Lets the app show 'not configured' / 'sandbox' before the brand fills the top-up form."""
    base, _ = komerce_config()
    return {"komerce_configured": komerce_configured(), "sandbox": "sandbox" in base.lower()}


@api.post("/brand/topups/{tid}/check")
async def check_topup(tid: str, user=Depends(require("brand"))):
    t = await db.topups.find_one({"topup_id": tid, "brand_id": user["user_id"]}, {"_id": 0})
    if not t:
        raise HTTPException(404, "Top up tidak ditemukan")
    if t["status"] == "pending":
        await sync_topup(t)
    return await db.topups.find_one({"topup_id": tid}, {"_id": 0, "callback_key": 0, "callback_url": 0})


@api.post("/payments/komerce/callback")
async def komerce_callback(request: Request):
    raw = await request.body()
    try:
        data = await request.json()
    except Exception:
        raise HTTPException(400, "Bad payload")
    d = data.get("data", data)
    t = await db.topups.find_one({"$or": [{"payment_id": d.get("payment_id")}, {"topup_id": d.get("order_id")}]}, {"_id": 0})
    if not t:
        raise HTTPException(404, "Unknown payment")
    sig = request.headers.get("X-Callback-Api-Key", "")
    expected = hmac.new(t["callback_key"].encode(), raw, hashlib.sha256).hexdigest()
    if not (hmac.compare_digest(sig, expected) or hmac.compare_digest(sig, t["callback_key"])):
        raise HTTPException(401, "Invalid signature")
    # Re-confirm status directly with Komerce before crediting
    await sync_topup(t)
    return {"ok": True}


# ---------------- Brand stats ----------------
@api.get("/brand/stats")
async def brand_stats(user=Depends(require("brand"))):
    """Data umum campaign brand saja: saldo, campaign aktif, kreator terdaftar, views, budget."""
    cs = await db.campaigns.find({"brand_id": user["user_id"], "deleted": {"$ne": True}}, {"_id": 0}).to_list(500)
    creators = await db.submissions.distinct("creator_id", {"brand_id": user["user_id"]})
    return {"brand_balance": user.get("brand_balance", 0), "active": sum(1 for c in cs if c["status"] == "active"),
            "spent": sum(c["spent"] for c in cs), "views": sum(c.get("total_views", 0) for c in cs),
            "creators": len(creators),
            "budget_left": sum(max(c["budget"] - c["spent"], 0) for c in cs if c["status"] != "closed")}


# ---------------- Admin ----------------
@api.get("/admin/stats")
async def admin_stats(user=Depends(require("admin"))):
    paid = await db.withdrawals.aggregate([{"$match": {"status": "disetujui"}}, {"$group": {"_id": None, "s": {"$sum": "$amount"}}}]).to_list(1)
    views = await db.campaigns.aggregate([{"$group": {"_id": None, "s": {"$sum": "$total_views"}}}]).to_list(1)
    return {"creators": await db.users.count_documents({"role": "creator"}),
            "brands": await db.users.count_documents({"role": "brand"}),
            "active_campaigns": await db.campaigns.count_documents({"status": "active"}),
            "pending_withdrawals": await db.withdrawals.count_documents({"status": "diproses"}),
            "pending_submissions": await db.submissions.count_documents({"status": {"$in": ["direview", "diproses"]}}),
            "total_paid": paid[0]["s"] if paid else 0, "total_views": views[0]["s"] if views else 0,
            **(await revenue_summary())}


async def revenue_summary():
    rows = await db.platform_revenue.aggregate([{"$group": {"_id": "$type", "s": {"$sum": "$amount"}}}]).to_list(10)
    by = {r["_id"]: r["s"] for r in rows}
    return {"revenue_topup_fee": by.get("topup_fee", 0), "revenue_withdraw_fee": by.get("withdraw_fee", 0),
            "platform_revenue": sum(by.values())}


@api.get("/admin/revenue")
async def admin_revenue(owner=Depends(require_owner)):
    """Pendapatan platform: fee top-up brand & fee penarikan kreator, beserta rinciannya."""
    items = await db.platform_revenue.find({}, {"_id": 0}).sort("created_at", -1).to_list(300)
    return {**(await revenue_summary()), "items": items,
            "fees": {"brand_topup_fee_pct": bp_to_pct(BRAND_TOPUP_FEE_BP),
                     "creator_withdraw_fee_pct": bp_to_pct(CREATOR_WITHDRAW_FEE_BP),
                     "brand_withdraw_fee_pct": bp_to_pct(BRAND_WITHDRAW_FEE_BP)}}


@api.get("/admin/users")
async def admin_users(user=Depends(require("admin"))):
    return await db.users.find({}, {"_id": 0, "post_dates": 0, "password_hash": 0}).sort("created_at", -1).to_list(1000)


@api.get("/admin/submissions")
async def admin_submissions(status: str = "", user=Depends(require_owner)):
    f = {"status": status} if status else {}
    return with_proof_urls(await db.submissions.find(f, {"_id": 0}).sort("created_at", -1).to_list(500))


@api.get("/admin/campaigns")
async def admin_campaigns(user=Depends(require("admin"))):
    return [campaign_view(c) for c in await db.campaigns.find({"deleted": {"$ne": True}}, {"_id": 0}).sort("created_at", -1).to_list(500)]


@api.get("/admin/withdrawals")
async def admin_withdrawals(user=Depends(require("admin"))):
    return await db.withdrawals.find({}, {"_id": 0}).sort("created_at", -1).to_list(500)


class WdActionIn(BaseModel):
    action: Literal["approve", "reject"]
    reference: Optional[str] = ""


@api.post("/admin/withdrawals/{wid}")
async def admin_withdraw_action(wid: str, body: WdActionIn, user=Depends(require("admin"))):
    new = "disetujui" if body.action == "approve" else "ditolak"
    w = await db.withdrawals.find_one_and_update({"withdrawal_id": wid, "status": "diproses"},
                                                 {"$set": {"status": new, "reference": body.reference or "", "updated_at": iso()}})
    if not w:
        raise HTTPException(400, "Penarikan sudah diproses")
    amt = rupiah(w["amount"])
    net = int(w.get("net_amount", w["amount"]))  # penarikan lama tanpa fee: net = amount
    fee = int(w.get("fee") or 0)
    if new == "ditolak":
        field = BALANCE_FIELD.get(w.get("role", "creator"), "balance")
        await db.users.update_one({"user_id": w["creator_id"]}, {"$inc": {field: w["amount"]}})
        await add_ledger(w["creator_id"], "withdraw_refund", w["amount"], wid, (body.reference or "").strip())
        await notify(w["creator_id"], "Penarikan ditolak", f"{amt} dikembalikan ke saldo. {body.reference or ''}".strip(), "error")
    else:
        await add_revenue("withdraw_fee", fee, wid, w["creator_id"], int(round(float(w.get("fee_pct") or 0) * 100)), w["amount"])
        await notify(w["creator_id"], "Penarikan berhasil",
                     f"{rupiah(net)} via {w['method']} sudah ditransfer" + (f" (biaya platform {rupiah(fee)})" if fee else ""),
                     "success")
    await audit_if_owner(user, f"withdrawal.{body.action}", w.get("creator_name") or w["creator_id"],
                         {"withdrawal_id": wid, "amount": w["amount"], **({"reference": body.reference} if body.reference else {})})
    return {"ok": True}


class CreditIn(BaseModel):
    amount: int = Field(ge=1000)
    note: Optional[str] = ""


@api.post("/admin/users/{uid}/brand-credit")
async def admin_brand_credit(uid: str, body: CreditIn, user=Depends(require("admin"))):
    r = await db.users.update_one({"user_id": uid, "role": "brand"}, {"$inc": {"brand_balance": body.amount}})
    if not r.modified_count:
        raise HTTPException(404, "Brand tidak ditemukan")
    await db.ledger.insert_one({"entry_id": gen_id("led"), "user_id": uid, "type": "admin_credit", "amount": body.amount,
                                "ref": user["user_id"], "note": body.note, "created_at": iso()})
    await notify(uid, "Saldo brand ditambahkan", f"Admin menambahkan Rp {body.amount:,}".replace(",", "."), "success")
    return {"ok": True}


# ---------------- Owner Control Center ----------------
# Owner-only actions (role admin + is_owner, i.e. signed in with the WhatsApp OTP). Every action is
# written to the audit log; every write bumps /api/sync through the middleware.
def rupiah(n):
    return f"Rp {int(n):,}".replace(",", ".")


class OwnerCampaignIn(BaseModel):
    """Campaign gerakan (aksi relawan) buatan Admin Pusat."""
    title: str = Field(min_length=3, max_length=120)
    category: str
    platforms: List[Platform] = Field(min_length=1)
    target_actions: List[TargetAksi] = Field(min_length=1)
    thumbnail: Optional[str] = Field(default="", max_length=500)
    instructions: str = Field(min_length=10, max_length=5000)
    exclusive: bool = False
    deadline_days: int = Field(default=30, ge=1, le=180)


@api.post("/admin/campaigns")
async def owner_create_campaign(body: OwnerCampaignIn, owner=Depends(require_owner)):
    if body.category not in GERAKAN_CATEGORIES:
        raise HTTPException(400, "Kategori tidak valid")
    d = body.model_dump()
    days = d.pop("deadline_days")
    d["target_actions"] = list(dict.fromkeys(d["target_actions"]))
    c = {**d, "campaign_id": gen_id("cmp"), "kind": "aksi", "brand_id": "gibran2029", "brand_name": GERAKAN_NAME,
         # Tidak ada sistem bayar per views: field lama diisi 0 agar aplikasi versi lama tetap bisa membaca campaign.
         "rate_per_1k": 0, "min_views": 0, "budget": 0, "spent": 0,
         "submission_count": 0, "total_views": 0, "status": "active", "funded_by": "owner",
         "created_by": owner["user_id"], "deadline": (now() + timedelta(days=days)).isoformat(), "created_at": iso()}
    await db.campaigns.insert_one(c)
    await audit(owner, "campaign.create", c["title"], {"campaign_id": c["campaign_id"], "category": c["category"],
                                                         "target_actions": c["target_actions"]})
    c.pop("_id", None)
    return campaign_view(c)


class OwnerCampaignUpdate(BaseModel):
    title: str = Field(min_length=3, max_length=120)
    category: str
    platforms: List[Platform] = Field(min_length=1)
    target_actions: Optional[List[TargetAksi]] = None
    thumbnail: Optional[str] = Field(default="", max_length=500)
    instructions: str = Field(min_length=10, max_length=5000)
    exclusive: bool = False
    deadline: Optional[str] = None  # ISO datetime


@api.put("/admin/campaigns/{cid}")
async def owner_update_campaign(cid: str, body: OwnerCampaignUpdate, owner=Depends(require_owner)):
    """Ubah judul, kategori, platform, target aksi, banner, instruksi, exclusive, tanggal tutup.
    Rate, budget, dan minimal views (campaign brand lama) tidak lagi diubah dari sini."""
    c = await db.campaigns.find_one({"campaign_id": cid, "deleted": {"$ne": True}}, {"_id": 0})
    if not c:
        raise HTTPException(404, "Campaign tidak ditemukan")
    aksi = c.get("kind") == "aksi"
    if body.category not in (GERAKAN_CATEGORIES if aksi else GERAKAN_CATEGORIES + CATEGORIES):
        raise HTTPException(400, "Kategori tidak valid")
    if aksi and not body.target_actions:
        raise HTTPException(422, "Pilih minimal satu target aksi")
    if c["status"] == "closed":
        raise HTTPException(400, "Campaign sudah ditutup dan tidak bisa diubah")
    upd = body.model_dump(exclude={"deadline", "target_actions"})
    if body.target_actions:
        upd["target_actions"] = list(dict.fromkeys(body.target_actions))
    if body.deadline:
        try:
            dl = _as_utc(datetime.fromisoformat(body.deadline.replace("Z", "+00:00")))
        except ValueError:
            raise HTTPException(400, "Format tanggal tutup tidak valid")
        upd["deadline"] = dl.isoformat()
    await db.campaigns.update_one({"campaign_id": cid}, {"$set": {**upd, "updated_at": iso()}})
    if body.title != c["title"]:
        await db.submissions.update_many({"campaign_id": cid}, {"$set": {"campaign_title": body.title}})
    changed = {k: {"from": c.get(k), "to": v} for k, v in upd.items() if c.get(k) != v and k not in ("instructions", "thumbnail")}
    for k in ("instructions", "thumbnail"):
        if c.get(k) != upd.get(k):
            changed[k] = "diubah"
    await audit(owner, "campaign.edit", body.title, {"campaign_id": cid, **changed})
    return campaign_view(await db.campaigns.find_one({"campaign_id": cid}, {"_id": 0}))


@api.patch("/admin/campaigns/{cid}/status")
async def owner_campaign_status(cid: str, body: StatusIn, user=Depends(require("admin"))):
    """Pause / resume / close any brand's campaign (same rules as PATCH /campaigns/{cid}/status)."""
    c = await db.campaigns.find_one({"campaign_id": cid, "deleted": {"$ne": True}}, {"_id": 0})
    if not c:
        raise HTTPException(404, "Campaign tidak ditemukan")
    return {"ok": True, "refund": await change_campaign_status(c, body.status, user)}


@api.delete("/admin/campaigns/{cid}")
async def owner_delete_campaign(cid: str, owner=Depends(require_owner)):
    """Close (refunding the unspent budget to the brand) and hide from web & app. Submissions stay."""
    c = await db.campaigns.find_one({"campaign_id": cid, "deleted": {"$ne": True}}, {"_id": 0})
    if not c:
        raise HTTPException(404, "Campaign tidak ditemukan")
    refund = await change_campaign_status(c, "closed", {**owner, "is_owner": False}) if c["status"] != "closed" else 0
    await db.campaigns.update_one({"campaign_id": cid}, {"$set": {"deleted": True, "deleted_at": iso(),
                                                                  "deleted_by": owner["user_id"]}})
    await notify(c["brand_id"], "Campaign dihapus Owner",
                 c["title"] + (f". Sisa budget {rupiah(refund)} dikembalikan ke saldo brand." if refund else ""))
    await audit(owner, "campaign.delete", c["title"], {"campaign_id": cid, **({"refund": refund} if refund else {})})
    return {"ok": True, "refund": refund}


class OwnerUserPatch(BaseModel):
    status: Optional[Literal["active", "suspended"]] = None
    suspend_reason: Optional[str] = Field(default=None, max_length=300)
    verified: Optional[bool] = None


@api.patch("/admin/users/{uid}")
async def owner_update_user(uid: str, body: OwnerUserPatch, owner=Depends(require_owner)):
    target = await db.users.find_one({"user_id": uid}, {"_id": 0})
    if not target:
        raise HTTPException(404, "Pengguna tidak ditemukan")
    if target.get("is_owner") or uid == owner["user_id"]:
        raise HTTPException(400, "Akun Owner tidak bisa diubah dari sini")
    upd, unset, detail = {}, {}, {}
    if body.status == "suspended":
        reason = (body.suspend_reason or "").strip()
        if len(reason) < 3:
            raise HTTPException(400, "Alasan penangguhan wajib diisi (min. 3 karakter)")
        upd.update({"status": "suspended", "suspend_reason": reason, "suspended_at": iso(), "suspended_by": owner["user_id"]})
        detail.update({"status": "suspended", "reason": reason})
    elif body.status == "active":
        upd["status"] = "active"
        unset.update({"suspend_reason": "", "suspended_at": "", "suspended_by": ""})
        detail["status"] = "active"
    if body.verified is not None:
        upd["verified"] = body.verified
        detail["verified"] = body.verified
    if not detail:
        raise HTTPException(400, "Tidak ada perubahan")
    await db.users.update_one({"user_id": uid}, {"$set": upd, **({"$unset": unset} if unset else {})})
    if body.status == "suspended":
        await db.user_sessions.delete_many({"user_id": uid})  # signs the account out of web and app now
    elif body.status == "active":
        await notify(uid, "Akun aktif kembali", "Akun kamu sudah diaktifkan kembali oleh Owner.", "success")
    if body.verified:
        await notify(uid, "Akun terverifikasi", "Akun kamu sudah diverifikasi oleh Gibran for 2029.", "success")
    await audit(owner, "user.edit", target.get("profile", {}).get("brand_name") or target["name"], {"user_id": uid, **detail})
    return await db.users.find_one({"user_id": uid}, {"_id": 0, "post_dates": 0, "password_hash": 0})


class BalanceAdjustIn(BaseModel):
    field: Literal["balance", "brand_balance"]
    delta: int = Field(ge=-10_000_000_000, le=10_000_000_000)
    note: str = Field(min_length=3, max_length=300)


@api.post("/admin/users/{uid}/balance")
async def owner_adjust_balance(uid: str, body: BalanceAdjustIn, owner=Depends(require_owner)):
    if body.delta == 0:
        raise HTTPException(400, "Nominal tidak boleh 0")
    target = await db.users.find_one({"user_id": uid}, {"_id": 0})
    if not target:
        raise HTTPException(404, "Pengguna tidak ditemukan")
    expected = {"creator": "balance", "brand": "brand_balance"}.get(target.get("role"))
    if body.field != expected:
        raise HTTPException(400, "Saldo hanya bisa diubah untuk kreator (saldo) atau brand (saldo brand)")
    cond = {"user_id": uid}
    if body.delta < 0:
        cond[body.field] = {"$gte": -body.delta}  # never below zero, even with concurrent spending
    res = await db.users.find_one_and_update(cond, {"$inc": {body.field: body.delta}}, return_document=ReturnDocument.AFTER)
    if not res:
        raise HTTPException(400, f"Saldo tidak boleh minus. Saldo saat ini {rupiah(target.get(body.field, 0))}")
    note = body.note.strip()
    await db.ledger.insert_one({"entry_id": gen_id("led"), "user_id": uid, "type": "owner_adjust", "amount": body.delta,
                                "field": body.field, "note": note, "ref": owner["user_id"], "created_at": iso()})
    await notify(uid, "Saldo disesuaikan Owner",
                 f"{'+' if body.delta > 0 else '−'}{rupiah(abs(body.delta))}. {note}", "success" if body.delta > 0 else "info")
    await audit(owner, "user.balance", target.get("profile", {}).get("brand_name") or target["name"],
                {"user_id": uid, "field": body.field, "delta": body.delta, "after": res[body.field], "note": note})
    return {"ok": True, body.field: res[body.field]}


@api.get("/admin/users/{uid}/ledger")
async def admin_user_ledger(uid: str, user=Depends(require("admin"))):
    return await db.ledger.find({"user_id": uid}, {"_id": 0}).sort("created_at", -1).to_list(300)


@api.get("/admin/audit")
async def owner_audit_log(limit: int = 200, owner=Depends(require_owner)):
    return await db.audit.find({}, {"_id": 0}).sort("created_at", -1).to_list(max(1, min(limit, 500)))


# ---------------- Image uploads (campaign thumbnails) ----------------
MAX_UPLOAD_BYTES = 2 * 1024 * 1024


def sniff_image(b: bytes):
    if b[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if b[:4] == b"RIFF" and b[8:12] == b"WEBP":
        return "image/webp"
    return None


async def store_image(request: Request, file: UploadFile, owner_id: str, kind: str = "image"):
    """Validate (size + sniffed type) and store an uploaded image. Returns (upload_id, url, ctype, size)."""
    data = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Ukuran gambar maksimal 2 MB")
    ctype = sniff_image(data)  # trust the bytes, not the client-supplied content type
    if not ctype:
        raise HTTPException(400, "Format gambar harus JPG, PNG, atau WebP")
    uid = gen_id("img")
    await db.uploads.insert_one({"upload_id": uid, "owner_id": owner_id, "content_type": ctype, "kind": kind,
                                 "size": len(data), "data": data, "created_at": iso()})
    return uid, f"{public_base_url(request)}/api/uploads/{uid}", ctype, len(data)


@api.post("/uploads")
async def upload_image(request: Request, file: UploadFile = File(...), user=Depends(require("brand", "admin"))):
    uid, url, ctype, size = await store_image(request, file, user["user_id"])
    return {"upload_id": uid, "url": url, "content_type": ctype, "size": size}


@api.post("/users/avatar")
async def upload_avatar(request: Request, file: UploadFile = File(...), user=Depends(get_user)):
    """Any signed-in user can replace their profile photo (JPG/PNG/WebP, max 2 MB)."""
    uid, url, _, _ = await store_image(request, file, user["user_id"], kind="avatar")
    await db.users.update_one({"user_id": user["user_id"]},
                              {"$set": {"picture": url, "picture_custom": True, "avatar_upload_id": uid}})
    old = user.get("avatar_upload_id")
    if old:
        await db.uploads.delete_one({"upload_id": old, "owner_id": user["user_id"]})
    return await db.users.find_one({"user_id": user["user_id"]}, USER_PUBLIC)


@api.delete("/users/avatar")
async def delete_avatar(user=Depends(get_user)):
    """Remove the uploaded photo and fall back to the Google photo (or initials)."""
    await db.users.update_one({"user_id": user["user_id"]},
                              {"$set": {"picture": user.get("google_picture"), "picture_custom": False},
                               "$unset": {"avatar_upload_id": ""}})
    old = user.get("avatar_upload_id")
    if old:
        await db.uploads.delete_one({"upload_id": old, "owner_id": user["user_id"]})
    return await db.users.find_one({"user_id": user["user_id"]}, USER_PUBLIC)


@api.get("/uploads/{uid}")
async def get_upload(uid: str):
    # Bukti klaim & foto KTP tidak publik: bukti lewat /api/proofs/{id} bertanda tangan, KTP hanya untuk admin.
    d = await db.uploads.find_one({"upload_id": uid, "kind": {"$nin": ["proof", "ktp"]}}, {"_id": 0, "data": 1, "content_type": 1})
    if not d:
        raise HTTPException(404, "Gambar tidak ditemukan")
    return Response(content=bytes(d["data"]), media_type=d["content_type"],
                    headers={"Cache-Control": "public, max-age=31536000, immutable",
                             "X-Content-Type-Options": "nosniff"})


# ---------------- Pendaftaran Member (jenis "anggota") / Relawan Gibran for 2029 ----------------
# Formulir web /daftar/{anggota|relawan}. Wajib login Google (sesi biasa, tanpa peran kreator/brand).
# NIK & foto KTP data pribadi: foto disimpan di db.uploads (kind "ktp") dan TIDAK lewat /api/uploads/{id};
# hanya admin yang bisa melihatnya lewat /api/admin/registrations/{id}/ktp.
KTP_MAX_BYTES = 3 * 1024 * 1024
REG_JENIS = ("anggota", "relawan")
REG_LABEL = {"anggota": "member", "relawan": "relawan"}  # nama yang tampil ke pengguna
REG_STATUS = ("menunggu verifikasi", "diterima", "ditolak")
REG_GENDER = ("Laki-laki", "Perempuan")
REG_NIKAH = ("Belum Kawin", "Kawin", "Cerai Hidup", "Cerai Mati")
REG_PUBLIC = {"_id": 0, "registration_id": 1, "jenis": 1, "nama": 1, "telepon": 1, "status": 1, "created_at": 1,
              "updated_at": 1, "nik": 1, "status_note": 1, "kta_number": 1, "kta_issued_at": 1,
              "kabupaten": 1, "provinsi": 1, "kecamatan": 1, "kelurahan": 1}
KTA_PREFIX = {"anggota": "M", "relawan": "R"}  # Member / Relawan


async def _issue_kta_number(reg: dict) -> str:
    """Nomor KTA unik: G2029-<M|R>-<kode provinsi 2 digit>-<urutan 6 digit>, mis. G2029-M-33-000001.
    Urutan berjalan per jenis (atomik lewat db.counters), tidak pernah dipakai ulang."""
    c = await db.counters.find_one_and_update({"_id": f"kta_{reg['jenis']}"}, {"$inc": {"seq": 1}},
                                              upsert=True, return_document=ReturnDocument.AFTER)
    prov = ((reg.get("wilayah_id") or {}).get("provinsi") or "")[:2]
    prov = prov if re.fullmatch(r"\d{2}", prov) else "00"
    return f"G2029-{KTA_PREFIX[reg['jenis']]}-{prov}-{c['seq']:06d}"


def _mask_nik(nik: str) -> str:
    return nik[:6] + "******" + nik[-4:] if len(nik) == 16 else ""


def _reg_out(d: dict) -> dict:
    out = {k: v for k, v in d.items() if k not in ("_id", "nik", "ktp_upload_id")}
    if "nik" in d:
        out["nik_masked"] = _mask_nik(d["nik"])
    return out


def _clean(v: str, field: str, max_len: int, min_len: int = 1) -> str:
    v = re.sub(r"\s+", " ", (v or "").strip())
    if len(v) < min_len or len(v) > max_len:
        raise HTTPException(422, f"{field} tidak valid")
    return v


@api.post("/registrations")
async def create_registration(
    request: Request,
    jenis: str = Form(...), nama: str = Form(...), telepon: str = Form(...), persetujuan: str = Form(...),
    kabupaten: str = Form(""), provinsi: str = Form(""), provinsi_id: str = Form(""), kabupaten_id: str = Form(""),
    email: str = Form(""), referral: str = Form(""),
    # Wajib untuk Member (KTA resmi); tidak diminta di formulir Relawan.
    nik: str = Form(""), kota_lahir: str = Form(""), tanggal_lahir: str = Form(""), jenis_kelamin: str = Form(""),
    kecamatan: str = Form(""), kelurahan: str = Form(""), kecamatan_id: str = Form(""), kelurahan_id: str = Form(""),
    alamat: str = Form(""), status_pernikahan: str = Form(""),
    ktp: Optional[UploadFile] = File(None),
    user=Depends(get_user),
):
    """Member: data lengkap sesuai KTP + foto KTP wajib. Relawan: cukup nama, WhatsApp, kab/kota (foto KTP opsional)."""
    if jenis not in REG_JENIS:
        raise HTTPException(422, "Jenis pendaftaran tidak dikenal")
    member = jenis == "anggota"
    if persetujuan.lower() not in ("true", "1", "ya", "on"):
        raise HTTPException(422, "Pernyataan persetujuan wajib dicentang")
    if member:
        if not re.fullmatch(r"\d{16}", nik or ""):
            raise HTTPException(422, "NIK harus 16 digit angka")
        try:
            lahir = datetime.strptime(tanggal_lahir, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            raise HTTPException(422, "Tanggal lahir tidak valid")
        umur = (now() - lahir).days / 365.25
        if umur < 17 or umur > 120:
            raise HTTPException(422, "Usia pendaftar minimal 17 tahun")
        if jenis_kelamin not in REG_GENDER:
            raise HTTPException(422, "Jenis kelamin tidak valid")
        if status_pernikahan not in REG_NIKAH:
            raise HTTPException(422, "Status pernikahan tidak valid")
    tel = re.sub(r"[\s-]", "", telepon or "")
    if not re.fullmatch(r"(\+62|62|0)8\d{7,12}", tel):
        raise HTTPException(422, "Nomor WhatsApp tidak valid")
    tel = "62" + re.sub(r"^(\+62|62|0)", "", tel)
    email = (email or user.get("email") or "").strip().lower()
    if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email) or len(email) > 120:
        raise HTTPException(422, "Email tidak valid")
    referral = (referral or "").strip()
    if referral and not re.fullmatch(r"[A-Za-z0-9_-]{3,32}", referral):
        raise HTTPException(422, "Kode referral tidak valid")
    doc = {
        "jenis": jenis, "nama": _clean(nama, "Nama", 100, 3),
        "kabupaten": _clean(kabupaten, "Kabupaten/Kota", 80),
        "provinsi": _clean(provinsi, "Provinsi", 80) if (member or provinsi.strip()) else "",
        "wilayah_id": {"provinsi": provinsi_id[:16], "kabupaten": kabupaten_id[:16]},
        "telepon": tel, "email": email, "referral": referral.upper(),
    }
    if member:
        # NIK hanya disimpan untuk Member (tanpa field `nik` untuk Relawan → indeks unik parsial tidak bentrok).
        doc.update({
            "nik": nik, "kota_lahir": _clean(kota_lahir, "Kota kelahiran", 60),
            "tanggal_lahir": tanggal_lahir, "jenis_kelamin": jenis_kelamin,
            "kecamatan": _clean(kecamatan, "Kecamatan", 80), "kelurahan": _clean(kelurahan, "Kelurahan/Desa", 80),
            "alamat": _clean(alamat, "Alamat lengkap", 300, 10), "status_pernikahan": status_pernikahan,
        })
        doc["wilayah_id"].update({"kecamatan": kecamatan_id[:16], "kelurahan": kelurahan_id[:16]})
    if member and not ktp:
        raise HTTPException(422, "Foto KTP wajib diunggah untuk pendaftaran member")
    # Pendaftaran yang ditolak boleh dikirim ulang: data lama milik akun ini (dan foto KTP-nya) diganti.
    mine = await db.registrations.find_one({"user_id": user["user_id"], "jenis": jenis},
                                           {"_id": 0, "registration_id": 1, "status": 1, "ktp_upload_id": 1})
    if mine and mine.get("status") != "ditolak":
        raise HTTPException(409, f"Akun ini sudah mendaftar sebagai {REG_LABEL[jenis]}")
    if member:
        other = await db.registrations.find_one({"nik": nik, "jenis": jenis}, {"_id": 0, "registration_id": 1})
        if other and (not mine or other["registration_id"] != mine["registration_id"]):
            raise HTTPException(409, f"NIK ini sudah terdaftar sebagai {REG_LABEL[jenis]}")

    upload_id = None
    ts = iso()
    if ktp is not None and (ktp.filename or member):
        data = await ktp.read(KTP_MAX_BYTES + 1)
        if member or data:
            if len(data) > KTP_MAX_BYTES:
                raise HTTPException(413, "Ukuran foto KTP maksimal 3 MB")
            ctype = sniff_image(data)
            if not ctype:
                raise HTTPException(400, "Foto KTP harus JPG, PNG, atau WebP")
            upload_id = gen_id("ktp")
            await db.uploads.insert_one({"upload_id": upload_id, "owner_id": user["user_id"], "content_type": ctype,
                                         "kind": "ktp", "size": len(data), "data": data, "created_at": ts})
    rid = gen_id("reg")
    doc.update({"registration_id": rid, "user_id": user["user_id"], "account_email": user.get("email"),
                "status": "menunggu verifikasi", "persetujuan_at": ts, "created_at": ts, "updated_at": ts})
    if upload_id:
        doc["ktp_upload_id"] = upload_id
    if mine:
        await db.registrations.delete_one({"registration_id": mine["registration_id"], "status": "ditolak"})
        if mine.get("ktp_upload_id"):
            await db.uploads.delete_one({"upload_id": mine["ktp_upload_id"], "kind": "ktp"})
    try:
        await db.registrations.insert_one(doc)
    except DuplicateKeyError:
        if upload_id:
            await db.uploads.delete_one({"upload_id": upload_id})
        raise HTTPException(409, "Data ini sudah terdaftar")
    return _reg_out({k: v for k, v in doc.items() if k in REG_PUBLIC})


@api.get("/registrations/me")
async def my_registrations(user=Depends(get_user)):
    docs = await db.registrations.find({"user_id": user["user_id"]}, REG_PUBLIC).sort("created_at", -1).to_list(10)
    return [_reg_out(d) for d in docs]


@api.get("/admin/registrations")
async def admin_registrations(jenis: Optional[str] = None, status: Optional[str] = None, q: Optional[str] = None,
                              limit: int = 100, skip: int = 0, user=Depends(require("admin"))):
    flt = {}
    if jenis in REG_JENIS:
        flt["jenis"] = jenis
    if status in REG_STATUS:
        flt["status"] = status
    if q:
        rx = {"$regex": re.escape(q.strip()[:60]), "$options": "i"}
        flt["$or"] = [{"nama": rx}, {"nik": rx}, {"telepon": rx}, {"email": rx}, {"kabupaten": rx}]
    limit = max(1, min(limit, 500))
    docs = await db.registrations.find(flt, {"_id": 0}).sort("created_at", -1).skip(max(0, skip)).to_list(limit)
    total = await db.registrations.count_documents(flt)
    base = {k: v for k, v in flt.items() if k != "status"}
    counts = {st: await db.registrations.count_documents({**base, "status": st}) for st in REG_STATUS}
    # Admin melihat NIK lengkap untuk verifikasi; foto KTP lewat endpoint terpisah.
    return {"total": total, "counts": counts, "items": [{**{k: v for k, v in d.items() if k != "ktp_upload_id"},
                                       "has_ktp": bool(d.get("ktp_upload_id"))} for d in docs]}


@api.get("/admin/registrations/{rid}/ktp")
async def admin_registration_ktp(rid: str, user=Depends(require("admin"))):
    reg = await db.registrations.find_one({"registration_id": rid}, {"_id": 0, "ktp_upload_id": 1})
    if not reg or not reg.get("ktp_upload_id"):
        raise HTTPException(404, "Foto KTP tidak ditemukan")
    d = await db.uploads.find_one({"upload_id": reg["ktp_upload_id"], "kind": "ktp"}, {"_id": 0, "data": 1, "content_type": 1})
    if not d:
        raise HTTPException(404, "Foto KTP tidak ditemukan")
    return Response(content=bytes(d["data"]), media_type=d["content_type"],
                    headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"})


class RegistrationStatusIn(BaseModel):
    status: Literal["menunggu verifikasi", "diterima", "ditolak"]
    note: str = Field("", max_length=300)


@api.patch("/admin/registrations/{rid}")
async def admin_set_registration_status(rid: str, body: RegistrationStatusIn, user=Depends(require("admin"))):
    reg = await db.registrations.find_one_and_update(
        {"registration_id": rid}, {"$set": {"status": body.status, "status_note": body.note.strip(), "updated_at": iso(),
                                            "reviewed_by": user["user_id"], "reviewed_at": iso()}},
        projection={"_id": 0, "ktp_upload_id": 0}, return_document=ReturnDocument.AFTER)
    if not reg:
        raise HTTPException(404, "Pendaftaran tidak ditemukan")
    label = REG_LABEL[reg["jenis"]]
    if body.status == "diterima" and not reg.get("kta_number"):
        # Nomor KTA dibuat sekali saja (persetujuan ulang tidak membuat nomor baru).
        number = await _issue_kta_number(reg)
        upd = await db.registrations.find_one_and_update(
            {"registration_id": rid, "kta_number": {"$exists": False}},
            {"$set": {"kta_number": number, "kta_issued_at": iso()}},
            projection={"_id": 0, "ktp_upload_id": 0}, return_document=ReturnDocument.AFTER)
        reg = upd or await db.registrations.find_one({"registration_id": rid}, {"_id": 0, "ktp_upload_id": 0})
    if body.status == "diterima":
        await notify(reg["user_id"], f"Pendaftaran {label} disetujui",
                     f"Selamat! Nomor KTA digital kamu: {reg['kta_number']}. Lihat & unduh kartumu di halaman KTA.", "success")
    elif body.status == "ditolak":
        await notify(reg["user_id"], f"Pendaftaran {label} ditolak",
                     (f"Alasan: {body.note.strip()}. " if body.note.strip() else "") + "Perbaiki data lalu kirim ulang pendaftaran.",
                     "error")
    await audit_if_owner(user, "registration_status", rid, {"status": body.status, "jenis": reg["jenis"],
                                                            "kta_number": reg.get("kta_number")})
    return reg


# ---------------- Public ----------------
@api.get("/public/stats")
async def public_stats():
    paid = await db.submissions.aggregate([{"$match": {"status": "disetujui"}}, {"$group": {"_id": None, "s": {"$sum": "$payout"}}}]).to_list(1)
    return {"creators": await db.users.count_documents({"role": "creator"}),
            "campaigns": await db.campaigns.count_documents({"status": "active"}),
            "total_paid": paid[0]["s"] if paid else 0}


@api.get("/public/payouts")
async def public_payouts():
    subs = await db.submissions.find({"status": "disetujui", "payout": {"$gt": 0}},
                                     {"_id": 0, "creator_name": 1, "payout": 1}).sort("updated_at", -1).to_list(20)
    out = []
    for s in subs:
        parts = s["creator_name"].split()
        out.append({"name": parts[0] + (f" {parts[1][0]}." if len(parts) > 1 else ""), "amount": s["payout"]})
    return out


# ---------------- Seed ----------------
SEED = [
    ("Glow Serum Vitamin C x Kreator Skincare", "Beauty", ["tiktok", "instagram"], 10000, 10000, 15000000, "https://images.unsplash.com/photo-1615396899839-c99c121888b0?w=800&q=80"),
    ("Face Oil Natural - Review Jujur", "Beauty", ["tiktok"], 8000, 5000, 8000000, "https://images.unsplash.com/photo-1600428853876-fb5a850b444f?w=800&q=80"),
    ("Moisturizer Daun Hijau (YC)", "Beauty", ["tiktok", "instagram"], 6000, 5000, 6000000, "https://images.unsplash.com/photo-1748543668676-ea8241cb3886?w=800&q=80"),
    ("Sate Nusantara - Kuliner Malam", "F&B", ["tiktok", "threads"], 5000, 1000, 5000000, "https://images.unsplash.com/photo-1568882041008-c0954e91caba?w=800&q=80"),
    ("Jajanan Gerobak Viral", "F&B", ["tiktok"], 3000, 1000, 3000000, "https://images.unsplash.com/photo-1545830016-b441e357919d?w=800&q=80"),
    ("Sneakers Lokal Drop Terbaru", "Fashion", ["tiktok", "instagram"], 7000, 10000, 12000000, "https://images.unsplash.com/photo-1595341888016-a392ef81b7de?w=800&q=80"),
    ("Streetwear Lookbook Challenge", "Fashion", ["instagram", "tiktok"], 4000, 5000, 4000000, "https://images.unsplash.com/photo-1556906781-9a412961c28c?w=800&q=80"),
    ("Unboxing Smartphone Murah Spek Dewa", "Tech", ["youtube", "tiktok"], 12000, 10000, 20000000, "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800&q=80"),
    ("Tips Aplikasi Produktif", "Edukasi", ["tiktok", "youtube"], 4000, 2000, 3000000, "https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=800&q=80"),
    ("TryBuzzer Threads Campaign", "Produk", ["threads"], 3000, 5000, 5000000, "https://images.unsplash.com/photo-1523206489230-c012c64b2b48?w=800&q=80"),
    ("Koleksi Sepatu Warna Pastel", "Produk", ["tiktok"], 2000, 5000, 2000000, "https://images.unsplash.com/photo-1689830570678-956587526e75?w=800&q=80"),
    ("Street Food Tour Jakarta", "Hiburan", ["tiktok", "instagram", "youtube"], 5000, 3000, 7000000, "https://images.unsplash.com/photo-1622572771591-6ca7813cc39d?w=800&q=80"),
]
SEED_INSTR = ("1. Buat video 15-60 detik yang menampilkan produk secara natural.\n2. Sebutkan nama brand di 3 detik pertama.\n"
              "3. Wajib pakai hashtag #TryBuzzer dan tag akun brand.\n4. Dilarang konten SARA, kekerasan, atau beli views/bot.\n"
              "5. Video harus tetap tayang minimal 30 hari.")


async def _maybe_migrate_legacy_db():
    """Migrasi sekali jalan di server: salin data Gibran for 2029 dari database lama ke DB_NAME.
    Aktif hanya bila MIGRATE_FROM_DB diisi (mis. ourbuzzer). Tanpa MIGRATE_APPLY=true hanya dry run.
    Hapus kedua variabel setelah selesai. Kegagalan migrasi tidak menghentikan server."""
    source = (os.environ.get("MIGRATE_FROM_DB") or "").strip()
    if not source:
        return
    if source == DB_NAME:
        logger.warning("MIGRATE_FROM_DB sama dengan DB_NAME (%s) — migrasi dilewati.", DB_NAME)
        return
    apply = os.environ.get("MIGRATE_APPLY", "").lower() in ("1", "true", "yes")
    try:
        sys.path.insert(0, str(ROOT_DIR / "scripts"))
        from migrate_to_gibran2029 import migrate
        from pymongo import MongoClient
        sync_client = MongoClient(MONGO_URI)
        summary = await asyncio.to_thread(migrate, sync_client[source], sync_client[DB_NAME], apply)
        sync_client.close()
        logger.warning("MIGRASI %s: %s -> %s %s", "SELESAI" if apply else "DRY RUN", source, DB_NAME, summary)
    except Exception:
        logger.exception("Migrasi dari %s gagal", source)


def _rename_text(v):
    return v.replace("#" + OLD_GERAKAN_NAME, "#GibranFor2029").replace(OLD_GERAKAN_NAME, GERAKAN_NAME)


async def rename_old_gerakan_name() -> int:
    """Sekali jalan (idempoten): campaign lama bertuliskan "GIBRAN2029" diganti menjadi "Gibran for 2029"
    (nama penyelenggara, judul, instruksi; hashtag menjadi #GibranFor2029), termasuk judul di setoran."""
    fields = ("brand_name", "title", "instructions")
    changed = 0
    async for c in db.campaigns.find({"$or": [{f: {"$regex": OLD_GERAKAN_NAME}} for f in fields]}, {"_id": 0}):
        upd = {f: _rename_text(c[f]) for f in fields if isinstance(c.get(f), str) and OLD_GERAKAN_NAME in c[f]}
        await db.campaigns.update_one({"campaign_id": c["campaign_id"]}, {"$set": upd})
        if "title" in upd:
            await db.submissions.update_many({"campaign_id": c["campaign_id"]}, {"$set": {"campaign_title": upd["title"]}})
        changed += 1
    if changed:
        logger.info("Nama gerakan diperbarui ke '%s' pada %d campaign lama", GERAKAN_NAME, changed)
    return changed


@app.on_event("startup")
async def startup():
    if DB_NAME.lower() in LEGACY_DB_NAMES:
        logger.warning("Database '%s' adalah database lama OurBuzzer. Set DB_NAME=%s agar data Gibran for 2029 terpisah.",
                       DB_NAME, DEFAULT_DB_NAME)
    else:
        logger.info("Database MongoDB: %s", DB_NAME)
    await db.users.create_index("user_id", unique=True)
    await db.users.create_index("email", unique=True)
    await db.admin_otps.create_index("phone", unique=True)
    await db.audit.create_index("created_at")
    await db.telegram_links.create_index("code", unique=True)
    await db.telegram_links.create_index("expires_at", expireAfterSeconds=0)
    base = clean_base_url(os.environ.get("PUBLIC_BASE_URL")) or clean_base_url(os.environ.get("RAILWAY_PUBLIC_DOMAIN"))
    if telegram_config()["token"] and base:
        asyncio.create_task(setup_telegram_webhook(base))
    if os.environ.get("PUBLIC_BASE_URL") and not clean_base_url(os.environ.get("PUBLIC_BASE_URL")):
        logger.warning("PUBLIC_BASE_URL is not a valid URL (%r); using RAILWAY_PUBLIC_DOMAIN / request host instead",
                       os.environ.get("PUBLIC_BASE_URL")[:80])
    await db.ledger.create_index([("user_id", 1), ("created_at", -1)])
    await db.user_sessions.create_index("session_token")
    await db.campaigns.create_index("campaign_id", unique=True)
    await db.submissions.create_index("submission_id", unique=True)
    await db.submissions.create_index("video_url", unique=True)
    await db.withdrawals.create_index("withdrawal_id", unique=True)
    await db.topups.create_index("topup_id", unique=True)
    await db.topups.create_index("payment_id")
    await db.topups.create_index([("status", 1), ("created_at", -1)])
    await db.uploads.create_index("upload_id", unique=True)
    await db.registrations.create_index("registration_id", unique=True)
    await db.registrations.create_index([("user_id", 1), ("jenis", 1)], unique=True)
    # NIK unik per jenis, hanya untuk dokumen yang punya NIK (Relawan tidak menyimpan NIK).
    # Indeks lama (non-parsial) dihapus sekali agar Relawan tanpa NIK tidak saling bentrok.
    idx = await db.registrations.index_information()
    if "jenis_1_nik_1" in idx and not idx["jenis_1_nik_1"].get("partialFilterExpression"):
        await db.registrations.drop_index("jenis_1_nik_1")
    await db.registrations.create_index([("jenis", 1), ("nik", 1)], unique=True, name="jenis_1_nik_1",
                                        partialFilterExpression={"nik": {"$type": "string"}})
    await db.registrations.create_index([("status", 1), ("created_at", -1)])
    await db.registrations.create_index("kta_number", unique=True, sparse=True)
    await _maybe_migrate_legacy_db()
    await rename_old_gerakan_name()
    if RECONCILE_SECONDS > 0 and komerce_configured():
        app.state.reconciler = asyncio.create_task(_reconcile_loop())
        logger.info("Komerce configured (%s); reconciling pending top-ups every %ss",
                    komerce_config()[0], RECONCILE_SECONDS)
    elif not komerce_configured():
        logger.warning("Komerce NOT configured: set KOMERCE_BASE_URL and KOMERCE_API_KEY")
    await db.notifications.create_index([("user_id", 1), ("created_at", -1)])
    await db.platform_revenue.create_index("created_at")
    if CAMPAIGN_EXPIRY_CHECK_SECONDS > 0:
        app.state.expiry = asyncio.create_task(_campaign_expiry_loop())
    # Campaign demo lama (OurBuzzer/TryBuzzer) TIDAK lagi diisi otomatis ke database baru.
    # Aktifkan hanya untuk pengembangan lokal: SEED_DEMO_DATA=true.
    if os.environ.get("SEED_DEMO_DATA", "").lower() in ("1", "true", "yes") and await db.campaigns.count_documents({}) == 0:
        brand_id = "user_demobrand"
        await db.users.update_one({"user_id": brand_id}, {"$setOnInsert": {
            "user_id": brand_id, "email": "demo-brand@trybuzzer.local", "name": "Demo Brand", "picture": None,
            "role": "brand", "balance": 0, "total_earned": 0, "brand_balance": 0, "post_dates": [],
            "profile": {"brand_name": "Demo Brand"}, "created_at": iso()}}, upsert=True)
        for i, (title, cat, plats, rate, mv, budget, img) in enumerate(SEED):
            await db.campaigns.insert_one({
                "campaign_id": gen_id("cmp"), "brand_id": brand_id, "brand_name": "Demo Brand", "title": title,
                "category": cat, "platforms": plats, "rate_per_1k": rate, "min_views": mv, "budget": budget,
                "spent": int(budget * (i % 4) * 0.2), "thumbnail": img, "instructions": SEED_INSTR,
                "exclusive": i == 5, "submission_count": 12 - i, "total_views": 0, "status": "active",
                "deadline": (now() + timedelta(days=3 + i * 2)).isoformat(),
                "created_at": (now() - timedelta(hours=i * 7)).isoformat()})


@app.middleware("http")
async def sync_version_middleware(request: Request, call_next):
    response = await call_next(request)
    if (request.method in ("POST", "PUT", "PATCH", "DELETE") and request.url.path.startswith("/api/")
            and response.status_code < 400):
        try:
            await bump_sync()
        except Exception as e:  # never fail a request because of the sync counter
            logger.warning("sync bump failed: %s", e)
    return response


app.include_router(api)
app.add_middleware(CORSMiddleware, allow_credentials=True,
                   allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
                   allow_methods=["*"], allow_headers=["*"])


@app.on_event("shutdown")
async def shutdown_db_client():
    for name in ("reconciler", "expiry"):
        task = getattr(app.state, name, None)
        if task:
            task.cancel()
    client.close()
