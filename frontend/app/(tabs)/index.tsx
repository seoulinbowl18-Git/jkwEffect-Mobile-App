import React from "react";
import { useAuth } from "@/src/context/AuthContext";
import CariCuan from "@/src/screens/CariCuan";
import BrandHome from "@/src/screens/BrandHome";

export default function Home() {
  const { user } = useAuth();
  return user?.role === "brand" ? <BrandHome /> : <CariCuan />;
}
