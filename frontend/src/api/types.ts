export type Platform = "tiktok" | "instagram" | "threads" | "youtube";
export type Role = "creator" | "brand" | "admin" | null;

export interface User {
  user_id: string;
  email: string;
  name: string;
  picture?: string | null;
  role: Role;
  balance: number;
  total_earned: number;
  brand_balance: number;
  profile: Record<string, string>;
}

export interface Campaign {
  campaign_id: string;
  brand_id: string;
  brand_name: string;
  title: string;
  category: string;
  platforms: Platform[];
  rate_per_1k: number;
  min_views: number;
  budget: number;
  spent: number;
  thumbnail?: string;
  instructions: string;
  exclusive: boolean;
  submission_count: number;
  total_views: number;
  status: "active" | "paused" | "closed";
  deadline: string;
  created_at: string;
  budget_left_pct: number;
}

export interface Sections {
  trending: Campaign[];
  top_rate: Campaign[];
  newest: Campaign[];
  closing: Campaign[];
  total: number;
  total_exclusive: number;
}

export interface Submission {
  submission_id: string;
  campaign_id: string;
  campaign_title: string;
  creator_name: string;
  platform: Platform;
  video_url: string;
  status: string;
  claimed_views: number;
  verified_views: number;
  payout: number;
  rate_per_1k: number;
  min_views: number;
  note: string;
  created_at: string;
}

export interface Streak {
  streak: number;
  posted_today: boolean;
  week: { date: string; label: string; posted: boolean }[];
}

export interface CreatorStats {
  balance: number;
  total_earned: number;
  pending: number;
  videos: number;
  campaigns: number;
  streak: Streak;
}

export interface BrandStats {
  brand_balance: number;
  active: number;
  spent: number;
  views: number;
  pending_reviews: number;
}

export interface Withdrawal {
  withdrawal_id: string;
  amount: number;
  method: string;
  account_number: string;
  account_holder: string;
  status: string;
  reference: string;
  created_at: string;
}

export interface Topup {
  topup_id: string;
  amount: number;
  payment_type: "qris" | "bank_transfer";
  channel_code: string;
  va_number: string;
  qr_string: string;
  payment_url: string;
  status: string;
  created_at: string;
}

export interface Notification {
  notification_id: string;
  title: string;
  body: string;
  kind: string;
  read: boolean;
  created_at: string;
}
