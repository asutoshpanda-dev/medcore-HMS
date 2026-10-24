"use client";

import { useEffect, useState } from "react";
import AppFrame from "@/components/AppFrame";
import { api, ApiError, clearSession, STAFF_ROLES } from "@/lib/api";
import {
  buttonClass,
  cardClass,
  errorClass,
  inputClass,
  labelClass,
  noticeClass,
  panelClass,
  secondaryButtonClass,
} from "@/lib/ui";

const EMPTY_FORM = { fullName: "", age: "", gender: "male", phone: "" };

export default function PatientsPage() {
  return (
    <AppFrame allowedRoles={STAFF_ROLES}>
      <PatientsContent />
    </AppFrame>
  );
}

function isSessionEnded(err) {
  return err instanceof ApiError && err.status === 401;
}

function PatientsContent() {
  const [patients, setPatients] = useState([]);
  const [pageInfo, setPageInfo] = useState(null);
  const [page, setPage] = useState(0);
  const [searchText, setSearchText] = useState("");
  const [query, setQuery] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const [form, setForm] = useState(EMPTY_FORM);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  // Reload the list whenever the page, the search or a new patient changes it
  useEffect(() => {
    let ignore = false;

    async function load() {
      setLoading(true);
      setError("");
      try {
        const params = new URLSearchParams({ page: String(page), size: "20" });
        if (query) params.set("q", query);
        // The response is { data: [...patients], page: { number, totalPages, ... } }
        const response = await api(`/api/patients?${params}`);
        if (!ignore) {
          setPatients(response.data);
          setPageInfo(response.page);
        }
      } catch (err) {
        if (ignore) return;
        if (isSessionEnded(err)) {
          clearSession();
          window.location.replace("/login");
          return;
        }
        setError(err.message);
      } finally {
        if (!ignore) setLoading(false);
      }
    }

    load();
    return () => {
      ignore = true;
    };
  }, [page, query, reloadKey]);

  function handleSearch(event) {
    event.preventDefault();
    setPage(0);
    setQuery(searchText.trim());
  }

  async function handleAdd(event) {
    event.preventDefault();
    setNotice("");
    setError("");
    try {
      await api("/api/patients", {
        method: "POST",
        body: { ...form, age: Number(form.age) },
      });
      setForm(EMPTY_FORM);
      setNotice("Patient added.");
      if (page === 0) setReloadKey((k) => k + 1);
      else setPage(0);
    } catch (err) {
      if (isSessionEnded(err)) {
        clearSession();
        window.location.replace("/login");
        return;
      }
      setError(err.message);
    }
  }

  return (
    <>
      <h2 className="mb-4 text-xl font-semibold text-slate-800">Patients</h2>

      <form onSubmit={handleSearch} className={`${cardClass} mb-6 flex gap-2 p-4`}>
        <input
          className={`${inputClass} flex-1`}
          placeholder="Search by name or phone"
          value={searchText}
          onChange={(e) => setSearchText(e.target.value)}
        />
        <button type="submit" className={buttonClass}>
          Search
        </button>
      </form>

      {error && <p className={`${errorClass} mb-4`}>{error}</p>}
      {notice && <p className={`${noticeClass} mb-4`}>{notice}</p>}

      <div className={`${panelClass} overflow-x-auto`}>
        <table className="w-full text-left text-sm">
          <thead className="bg-slate-50 text-slate-600">
            <tr>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Age</th>
              <th className="px-4 py-3 font-medium">Gender</th>
              <th className="px-4 py-3 font-medium">Phone</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {patients.map((p) => (
              <tr key={p.id} className="hover:bg-slate-50">
                <td className="px-4 py-3 font-medium text-slate-900">{p.fullName}</td>
                <td className="px-4 py-3">{p.age}</td>
                <td className="px-4 py-3 capitalize">{p.gender}</td>
                <td className="px-4 py-3">{p.phone}</td>
              </tr>
            ))}
            {!loading && patients.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-6 text-center text-slate-500">
                  No patients found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {pageInfo && (
        <div className="mt-4 flex items-center justify-between gap-4 text-sm text-slate-600">
          <button
            type="button"
            className={secondaryButtonClass}
            disabled={page === 0}
            onClick={() => setPage(page - 1)}
          >
            Previous
          </button>
          <span>
            Page {pageInfo.number + 1} of {Math.max(pageInfo.totalPages, 1)} ({pageInfo.totalElements} patients)
          </span>
          <button
            type="button"
            className={secondaryButtonClass}
            disabled={page + 1 >= pageInfo.totalPages}
            onClick={() => setPage(page + 1)}
          >
            Next
          </button>
        </div>
      )}

      <section className={`${cardClass} mt-8`}>
        <h3 className="mb-4 text-lg font-semibold text-slate-800">Add a patient</h3>
        <form onSubmit={handleAdd} className="grid gap-4 sm:grid-cols-2">
          <label className={labelClass}>
            Full name
            <input
              className={inputClass}
              value={form.fullName}
              onChange={(e) => setForm({ ...form, fullName: e.target.value })}
              required
            />
          </label>
          <label className={labelClass}>
            Age
            <input
              type="number"
              min="1"
              max="120"
              className={inputClass}
              value={form.age}
              onChange={(e) => setForm({ ...form, age: e.target.value })}
              required
            />
          </label>
          <label className={labelClass}>
            Gender
            <select
              className={inputClass}
              value={form.gender}
              onChange={(e) => setForm({ ...form, gender: e.target.value })}
            >
              <option value="male">Male</option>
              <option value="female">Female</option>
              <option value="other">Other</option>
            </select>
          </label>
          <label className={labelClass}>
            Phone (10 digits)
            <input
              className={inputClass}
              value={form.phone}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
              pattern="[0-9]{10}"
              required
            />
          </label>
          <div className="sm:col-span-2">
            <button type="submit" className={buttonClass}>
              Add patient
            </button>
          </div>
        </form>
      </section>
    </>
  );
}
