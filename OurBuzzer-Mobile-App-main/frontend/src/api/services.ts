import { request } from "./client";
import type {
  BrandStats, Campaign, CreatorStats, Notification, Platform, Sections, Streak, Submission, Topup, User, Withdrawal,
} from "./types";

type Ok = { ok: boolean };

export const authApi = {
  exchange: (session_id: string) => request<User & { session_token: string }>("/auth/session", { method: "POST", body: { session_id } }),
  me: () => request<User>("/auth/me"),
  logout: () => request<Ok>("/auth/logout", { method: "POST" }),
  setRole: (role: "creator" | "brand", brand_name?: string) => request<User>("/users/role", { method: "POST", body: { role, brand_name } }),
  updateProfile: (body: Record<string, string>) => request<User>("/users/profile", { method: "PUT", body }),
};

export const campaignApi = {
  sections: () => request<Sections>("/campaigns/sections"),
  list: (params: { q?: string; category?: string; exclusive?: boolean; sort?: string }) => request<Campaign[]>("/campaigns", { params }),
  get: (id: string) => request<Campaign>(`/campaigns/${id}`),
  create: (body: Record<string, unknown>) => request<Campaign>("/campaigns", { method: "POST", body }),
  setStatus: (id: string, status: "active" | "paused" | "closed") => request<Ok>(`/campaigns/${id}/status`, { method: "PATCH", body: { status } }),
};

export const creatorApi = {
  stats: () => request<CreatorStats>("/creator/stats"),
  submissions: () => request<Submission[]>("/creator/submissions"),
  submit: (campaign_id: string, platform: Platform, video_url: string) =>
    request<Submission>("/submissions", { method: "POST", body: { campaign_id, platform, video_url } }),
  claim: (sid: string, views: number) => request<Ok>(`/submissions/${sid}/claim`, { method: "POST", body: { views } }),
  withdrawals: () => request<Withdrawal[]>("/creator/withdrawals"),
  withdraw: (body: { amount: number; method: string; account_number: string; account_holder: string }) =>
    request<Withdrawal>("/withdrawals", { method: "POST", body }),
  streak: () => request<Streak>("/streak"),
};

export const brandApi = {
  stats: () => request<BrandStats>("/brand/stats"),
  campaigns: () => request<Campaign[]>("/brand/campaigns"),
  submissions: (status = "") => request<Submission[]>("/brand/submissions", { params: { status } }),
  review: (sid: string, action: "approve" | "reject", note = "") =>
    request<Ok>(`/submissions/${sid}/review`, { method: "POST", body: { action, note } }),
  verify: (sid: string, action: "approve" | "reject", verified_views: number, note = "") =>
    request<Ok & { payout: number }>(`/submissions/${sid}/verify`, { method: "POST", body: { action, verified_views, note } }),
  topups: () => request<Topup[]>("/brand/topups"),
  createTopup: (body: { amount: number; payment_type: "qris" | "bank_transfer"; channel_code?: string; phone?: string }) =>
    request<Topup>("/brand/topups", { method: "POST", body }),
  checkTopup: (id: string) => request<Topup>(`/brand/topups/${id}/check`, { method: "POST" }),
};

export const notifApi = {
  list: () => request<{ items: Notification[]; unread: number }>("/notifications"),
  readAll: () => request<Ok>("/notifications/read-all", { method: "POST" }),
};
