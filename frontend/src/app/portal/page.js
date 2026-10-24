"use client";

import { useEffect, useState } from "react";
import AppFrame from "@/components/AppFrame";
import { api, ApiError, clearSession } from "@/lib/api";
import { cardClass, errorClass, panelClass } from "@/lib/ui";

const BADGE_STYLES = {
  PENDING: "bg-amber-100 text-amber-800",
  CONFIRMED: "bg-teal-100 text-teal-800",
  IN_PROGRESS: "bg-blue-100 text-blue-800",
  COMPLETED: "bg-green-100 text-green-800",
  PAID: "bg-green-100 text-green-800",
  ACTIVE: "bg-teal-100 text-teal-800",
  CANCELLED: "bg-slate-200 text-slate-700",
  NO_SHOW: "bg-red-100 text-red-700",
};

// Only patients may open the portal
const PATIENT_ROLES = ["PATIENT"];

export default function PortalPage() {
  return (
    <AppFrame allowedRoles={PATIENT_ROLES}>
      <PortalContent />
    </AppFrame>
  );
}

function isSessionEnded(err) {
  return err instanceof ApiError && err.status === 401;
}

// Shows the logged-in patient's own appointments, prescriptions and bills.
// The server returns only this patient's records, so nothing is filtered here.
function PortalContent() {
  const [patient, setPatient] = useState(null);
  const [appointments, setAppointments] = useState([]);
  const [prescriptions, setPrescriptions] = useState([]);
  const [bills, setBills] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let ignore = false;

    async function load() {
      setLoading(true);
      setError("");
      try {
        const [me, appointmentPage, prescriptionPage, billPage] = await Promise.all([
          api("/api/me/patient"),
          api("/api/me/appointments?size=50"),
          api("/api/me/prescriptions?size=50"),
          api("/api/me/bills?size=50"),
        ]);
        if (!ignore) {
          setPatient(me.data);
          setAppointments(appointmentPage.data);
          setPrescriptions(prescriptionPage.data);
          setBills(billPage.data);
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
  }, []);

  // Earliest first, so the next visit is at the top
  const sortedAppointments = [...appointments].sort((a, b) =>
    (a.appointmentDate + a.appointmentTime).localeCompare(b.appointmentDate + b.appointmentTime)
  );

  return (
    <>
      <h2 className="text-xl font-semibold text-slate-800">
        {patient ? `Hello, ${patient.fullName}` : "My portal"}
      </h2>
      <p className="mb-6 text-sm text-slate-500">Your appointments, prescriptions and bills.</p>

      {error && <p className={`${errorClass} mb-4`}>{error}</p>}

      <Section title="My appointments">
        <div className={`${panelClass} overflow-x-auto`}>
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-medium">Date</th>
                <th className="px-4 py-3 font-medium">Time</th>
                <th className="px-4 py-3 font-medium">Reason</th>
                <th className="px-4 py-3 font-medium">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {sortedAppointments.map((a) => (
                <tr key={a.id}>
                  <td className="whitespace-nowrap px-4 py-3">{formatDate(a.appointmentDate)}</td>
                  <td className="px-4 py-3">{a.appointmentTime.slice(0, 5)}</td>
                  <td className="px-4 py-3">{a.reason}</td>
                  <td className="px-4 py-3"><Badge value={a.status} /></td>
                </tr>
              ))}
              {!loading && sortedAppointments.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-6 text-center text-slate-500">No appointments yet.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </Section>

      <Section title="My prescriptions">
        {prescriptions.map((rx) => (
          <div key={rx.id} className={`${cardClass} mb-4`}>
            <div className="flex flex-wrap items-center justify-between gap-2">
              <p className="font-medium text-slate-900">Visit #{rx.appointmentId ?? "-"}</p>
              <Badge value={rx.status} />
            </div>
            {rx.instructions && <p className="mt-2 text-sm text-slate-600">{rx.instructions}</p>}
            <table className="mt-3 w-full text-left text-sm">
              <thead className="text-slate-500">
                <tr>
                  <th className="py-1 font-medium">Medicine</th>
                  <th className="py-1 font-medium">Dosage</th>
                  <th className="py-1 font-medium">Frequency</th>
                  <th className="py-1 font-medium">Duration</th>
                </tr>
              </thead>
              <tbody>
                {rx.items.map((item) => (
                  <tr key={item.id} className="border-t border-slate-100">
                    <td className="py-2">{item.medicineName}</td>
                    <td className="py-2">{item.dosage}</td>
                    <td className="py-2">{item.frequency}</td>
                    <td className="py-2">{item.duration}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ))}
        {!loading && prescriptions.length === 0 && (
          <p className="text-sm text-slate-500">No prescriptions yet.</p>
        )}
      </Section>

      <Section title="My bills">
        <div className={`${panelClass} overflow-x-auto`}>
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-medium">Visit</th>
                <th className="px-4 py-3 font-medium">Consultation</th>
                <th className="px-4 py-3 font-medium">Medicines</th>
                <th className="px-4 py-3 font-medium">Total</th>
                <th className="px-4 py-3 font-medium">Payment</th>
                <th className="px-4 py-3 font-medium">Paid on</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {bills.map((b) => (
                <tr key={b.id}>
                  <td className="px-4 py-3">#{b.appointmentId ?? "-"}</td>
                  <td className="px-4 py-3">{money(b.consultationFee)}</td>
                  <td className="px-4 py-3">{money(b.medicineFee)}</td>
                  <td className="px-4 py-3 font-medium text-slate-900">{money(b.totalAmount)}</td>
                  <td className="px-4 py-3"><Badge value={b.paymentStatus} /></td>
                  <td className="px-4 py-3">{b.paymentDate ? formatDate(b.paymentDate) : "-"}</td>
                </tr>
              ))}
              {!loading && bills.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-6 text-center text-slate-500">No bills yet.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </Section>
    </>
  );
}

function Section({ title, children }) {
  return (
    <section className="mb-8">
      <h3 className="mb-3 text-lg font-semibold text-slate-800">{title}</h3>
      {children}
    </section>
  );
}

function Badge({ value }) {
  const style = BADGE_STYLES[value] || "bg-slate-100 text-slate-700";
  return <span className={`rounded px-2 py-0.5 text-xs font-medium ${style}`}>{value}</span>;
}

// yyyy-mm-dd to "23 Oct 2026"
function formatDate(text) {
  return new Date(`${text}T00:00`).toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

function money(value) {
  if (value === null || value === undefined) return "-";
  return "₹" + Number(value).toLocaleString("en-IN", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}
