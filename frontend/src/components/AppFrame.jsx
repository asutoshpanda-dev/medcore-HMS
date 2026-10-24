"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { clearSession, getRole, getToken, homePathFor } from "@/lib/api";

// Wraps every logged-in screen. It sends visitors without a session to the login page.
// If the screen lists allowedRoles and this person's role is not one of them, they are sent to their own home page.
export default function AppFrame({ children, allowedRoles }) {
  const router = useRouter();
  const [checked, setChecked] = useState(false);
  const [role, setRole] = useState("");

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    const current = getRole() ?? "";
    if (allowedRoles && !allowedRoles.includes(current)) {
      router.replace(homePathFor(current) ?? "/login");
      return;
    }
    setRole(current);
    setChecked(true);
  }, [router, allowedRoles]);

  // A full page load (not a client-side route change) clears all screen state, so the next person starts clean
  function logout() {
    clearSession();
    window.location.replace("/login");
  }

  if (!checked) return null;

  return (
    <div className="min-h-screen">
      <header className="flex flex-wrap items-center gap-3 bg-teal-800 px-4 py-3 text-white sm:px-6">
        <strong className="text-lg">MedCore HMS</strong>
        <span className="rounded bg-teal-900/60 px-2 py-0.5 text-sm">{role}</span>
        <nav className="flex gap-4 text-sm">
          {role === "PATIENT" ? (
            <Link href="/portal" className="hover:underline">My portal</Link>
          ) : (
            <>
              <Link href="/patients" className="hover:underline">Patients</Link>
              <Link href="/appointments" className="hover:underline">Appointments</Link>
            </>
          )}
        </nav>
        <button
          type="button"
          onClick={logout}
          className="ml-auto rounded-md border border-white/40 px-3 py-1 text-sm hover:bg-white/10"
        >
          Log out
        </button>
      </header>
      <main className="mx-auto max-w-5xl p-4 sm:p-6">{children}</main>
    </div>
  );
}
