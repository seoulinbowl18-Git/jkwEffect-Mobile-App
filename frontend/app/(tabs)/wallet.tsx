import React from "react";
import { useAuth } from "@/src/context/AuthContext";
import CreatorWallet from "@/src/screens/CreatorWallet";
import BrandWallet from "@/src/screens/BrandWallet";
import AdminNotice from "@/src/screens/AdminNotice";

export default function Wallet() {
  const { user } = useAuth();
  if (user?.role === "brand") return <BrandWallet />;
  if (user?.role === "admin") return <AdminNotice title="Dompet" />;
  return <CreatorWallet />;
}
