"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api, ApiError, homePathFor, saveSession } from "@/lib/api";
import { buttonClass, cardClass, errorClass, inputClass, labelClass } from "@/lib/ui";

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");
    setBusy(true);
    try {
      // The response is { data: { token, role, hospitalId, ... } }
      const response = await api("/api/auth/login", {
        method: "POST",
        body: { username, password },
      });
      saveSession(response.data);
      setPassword("");
      setBusy(false);
      router.replace(homePathFor(response.data.role) ?? "/patients");
    } catch (err) {
      setError(
        err instanceof ApiError && err.status === 401
          ? "Wrong username or password."
          : err.message
      );
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <form onSubmit={handleSubmit} className={`${cardClass} w-full max-w-sm space-y-4`}>
        <h1 className="text-2xl font-semibold text-teal-800">MedCore HMS</h1>
        <label className={labelClass}>
          Username
          <input
            className={inputClass}
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            required
          />
        </label>
        <label className={labelClass}>
          Password
          <input
            type="password"
            className={inputClass}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </label>
        {error && <p className={errorClass}>{error}</p>}
        <button type="submit" disabled={busy} className={`${buttonClass} w-full`}>
          {busy ? "Logging in..." : "Log in"}
        </button>
      </form>
    </main>
  );
}
