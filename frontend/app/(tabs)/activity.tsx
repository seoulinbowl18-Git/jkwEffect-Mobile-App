import React from "react";
import { useAuth } from "@/src/context/AuthContext";
import CreatorContent from "@/src/screens/CreatorContent";
import BrandReview from "@/src/screens/BrandReview";
import AdminNotice from "@/src/screens/AdminNotice";

export default function Activity() {
  const { user } = useAuth();
  if (user?.role === "brand") return <BrandReview />;
  if (user?.role === "admin") return <AdminNotice title="Aktivitas" />;
  return <CreatorContent />;
}
