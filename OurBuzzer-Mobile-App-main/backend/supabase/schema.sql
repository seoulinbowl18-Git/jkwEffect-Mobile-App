-- TryBuzzer schema for Supabase (Postgres). Mirrors the current MongoDB collections
-- so the FastAPI backend (or Supabase Edge Functions) can be migrated 1:1.
-- Run in Supabase SQL editor. Money is stored in whole Rupiah (bigint).

create table if not exists users (
  user_id text primary key,
  email text unique not null,
  name text not null,
  picture text,
  role text check (role in ('creator','brand','admin')),
  balance bigint not null default 0,          -- creator withdrawable balance
  total_earned bigint not null default 0,
  brand_balance bigint not null default 0,    -- brand top-up balance
  post_dates date[] not null default '{}',    -- daily streak (WIB dates)
  profile jsonb not null default '{}',
  password_hash text,                         -- bcrypt; null = Google-only account
  email_verified boolean not null default false,
  auth_provider text,                         -- 'google' | 'email'
  created_at timestamptz not null default now()
);

create table if not exists user_sessions (
  session_token text primary key,
  user_id text not null references users(user_id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists campaigns (
  campaign_id text primary key,
  brand_id text not null references users(user_id),
  brand_name text not null,
  title text not null,
  category text not null,
  platforms text[] not null,
  rate_per_1k bigint not null check (rate_per_1k >= 500),
  min_views bigint not null,
  budget bigint not null check (budget >= 100000),
  spent bigint not null default 0 check (spent <= budget),
  thumbnail text,
  instructions text not null,
  exclusive boolean not null default false,
  submission_count int not null default 0,
  total_views bigint not null default 0,
  status text not null default 'active' check (status in ('active','paused','closed')),
  deadline timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists campaigns_status_idx on campaigns(status, exclusive);

create table if not exists submissions (
  submission_id text primary key,
  campaign_id text not null references campaigns(campaign_id),
  campaign_title text not null,
  brand_id text not null references users(user_id),
  creator_id text not null references users(user_id),
  creator_name text not null,
  platform text not null check (platform in ('tiktok','instagram','threads','youtube')),
  video_url text not null unique,             -- anti-duplicate (normalized URL)
  status text not null default 'direview'
    check (status in ('direview','menunggu_views','diproses','verifying','disetujui','ditolak')),
  claimed_views bigint not null default 0,
  verified_views bigint not null default 0,
  payout bigint not null default 0,
  rate_per_1k bigint not null,
  min_views bigint not null,
  note text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists submissions_creator_idx on submissions(creator_id, created_at desc);
create index if not exists submissions_brand_idx on submissions(brand_id, status);

create table if not exists withdrawals (
  withdrawal_id text primary key,
  creator_id text not null references users(user_id),
  creator_name text, creator_email text,
  amount bigint not null check (amount >= 50000),
  method text not null, account_number text not null, account_holder text not null,
  status text not null default 'diproses' check (status in ('diproses','disetujui','ditolak')),
  reference text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists topups (
  topup_id text primary key,
  brand_id text not null references users(user_id),
  amount bigint not null,
  payment_type text not null check (payment_type in ('qris','bank_transfer')),
  channel_code text, payment_id text, va_number text, qr_string text, payment_url text,
  callback_key text,
  status text not null default 'pending',
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists notifications (
  notification_id text primary key,
  user_id text not null references users(user_id) on delete cascade,
  title text not null, body text not null, kind text default 'info',
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on notifications(user_id, created_at desc);

create table if not exists ledger (
  entry_id text primary key,
  user_id text not null references users(user_id),
  type text not null,  -- topup | campaign_budget | campaign_refund | earning | withdraw_hold | withdraw_refund | admin_credit
  amount bigint not null,
  ref text, note text,
  created_at timestamptz not null default now()
);

-- Atomic helpers (call via RPC) — same guarantees as the Mongo conditional updates
create or replace function debit_brand(p_user text, p_amount bigint) returns boolean
language sql as $$
  update users set brand_balance = brand_balance - p_amount
  where user_id = p_user and brand_balance >= p_amount returning true;
$$;

create or replace function debit_creator(p_user text, p_amount bigint) returns boolean
language sql as $$
  update users set balance = balance - p_amount
  where user_id = p_user and balance >= p_amount returning true;
$$;

-- RLS: the API server uses the service-role key; block direct client access by default.
alter table users enable row level security;
alter table user_sessions enable row level security;
alter table campaigns enable row level security;
alter table submissions enable row level security;
alter table withdrawals enable row level security;
alter table topups enable row level security;
alter table notifications enable row level security;
alter table ledger enable row level security;
create policy "public read active campaigns" on campaigns for select using (status = 'active');
