"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { getRole, getToken, homePathFor } from "@/lib/api";

// The home address sends the visitor to the right screen
export default function HomePage() {
  const router = useRouter();

  useEffect(() => {
    router.replace(getToken() ? (homePathFor(getRole()) ?? "/patients") : "/login");
  }, [router]);

  return null;
}
