"use client";

import { useEffect, useState } from "react";
import AppFrame from "@/components/AppFrame";
import { api, ApiError, clearSession, getRole, STAFF_ROLES } from "@/lib/api";
import { buttonClass, cardClass, errorClass, inputClass, noticeClass, panelClass } from "@/lib/ui";

const STATUSES = ["PENDING", "CONFIRMED", "IN_PROGRESS", "COMPLETED", "CANCELLED", "NO_SHOW"];
const PRIORITIES = ["NORMAL", "EMERGENCY"];
const filterInputClass =
  "rounded-md border border-slate-300 bg-white px-3 py-2 text-slate-900 focus:border-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-600/30";
const tableSelectClass =
  "rounded-md border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 focus:border-teal-600 focus:outline-none";

// Today's date in the user's own time zone, as yyyy-mm-dd (toISOString would give UTC)
function localDate(date = new Date()) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function emptyBooking() {
  return {
    patientId: "",
    doctorId: "",
    appointmentDate: localDate(),
    appointmentTime: "09:00",
    reason: "",
    priority: "NORMAL",
  };
}

function isSessionEnded(err) {
  return err instanceof ApiError && err.status === 401;
}

// A label tied to its field by id. The field must have the same id.
function Field({ id, label, className = "", children }) {
  return (
    <div className={`flex flex-col gap-1 text-sm font-medium text-slate-700 ${className}`}>
      <label htmlFor={id}>{label}</label>
      {children}
    </div>
  );
}

export default function AppointmentsPage() {
  return (
    <AppFrame allowedRoles={STAFF_ROLES}>
      <AppointmentsContent />
    </AppFrame>
  );
}

function AppointmentsContent() {
  // Read after the session check: AppFrame only renders this part once the check has passed
  const role = getRole();
  const canBook = role === "HOSPITAL_ADMIN" || role === "RECEPTIONIST";

  const [date, setDate] = useState(localDate());
  const [statusFilter, setStatusFilter] = useState("");
  const [appointments, setAppointments] = useState([]);
  const [total, setTotal] = useState(0);
  const [patients, setPatients] = useState([]);
  const [doctors, setDoctors] = useState([]);
  const [booking, setBooking] = useState(emptyBooking);
  const [reloadKey, setReloadKey] = useState(0);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  // Appointments only carry IDs, so the names come from the patient and doctor lists
  useEffect(() => {
    let ignore = false;

    async function loadNames() {
      try {
        const [patientPage, doctorPage] = await Promise.all([
          api("/api/patients?size=100"),
          api("/api/doctors?size=100"),
        ]);
        if (!ignore) {
          setPatients(patientPage.data);
          setDoctors(doctorPage.data);
        }
      } catch (err) {
        if (ignore) return;
        if (isSessionEnded(err)) {
          clearSession();
          window.location.replace("/login");
          return;
        }
        setError(err.message);
      }
    }

    loadNames();
    return () => {
      ignore = true;
    };
  }, []);

  // Reload the day's list when the date, the status filter or a change of data changes
  useEffect(() => {
    let ignore = false;

    async function load() {
      setLoading(true);
      setError("");
      try {
        const params = new URLSearchParams({ size: "100" });
        if (date) params.set("date", date);
        if (statusFilter) params.set("status", statusFilter);
        // The response is { data: [...appointments], page: { totalElements, ... } }
        const response = await api(`/api/appointments?${params}`);
        if (!ignore) {
          setAppointments(response.data);
          setTotal(response.page.totalElements);
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
  }, [date, statusFilter, reloadKey]);

  function patientName(id) {
    const patient = patients.find((p) => p.id === id);
    return patient ? patient.fullName : `Patient #${id}`;
  }

  function doctorName(id) {
    const doctor = doctors.find((d) => d.id === id);
    return doctor ? doctor.fullName : `Doctor #${id}`;
  }

  // Earliest first
  const sorted = [...appointments].sort((a, b) =>
    (a.appointmentDate + a.appointmentTime).localeCompare(b.appointmentDate + b.appointmentTime)
  );

  // A lost session sends the user back to login; any other error is shown on the page
  function handleError(err) {
    if (isSessionEnded(err)) {
      clearSession();
      window.location.replace("/login");
      return;
    }
    setError(err.message);
  }

  async function changeStatus(id, status) {
    setError("");
    setNotice("");
    try {
      await api(`/api/appointments/${id}/status`, { method: "PATCH", body: { status } });
      setNotice("Status updated.");
      setReloadKey((k) => k + 1);
    } catch (err) {
      handleError(err);
    }
  }

  async function handleBook(event) {
    event.preventDefault();
    setError("");
    setNotice("");
    try {
      await api("/api/appointments", {
        method: "POST",
        body: {
          patientId: Number(booking.patientId),
          doctorId: Number(booking.doctorId),
          appointmentDate: booking.appointmentDate,
          appointmentTime: booking.appointmentTime,
          reason: booking.reason.trim(),
          priority: booking.priority,
        },
      });
      // Keep the chosen date, clear the rest. On an error the form keeps its values so the user can fix them.
      setBooking({ ...emptyBooking(), appointmentDate: booking.appointmentDate });
      setNotice("Appointment booked.");
      setReloadKey((k) => k + 1);
    } catch (err) {
      handleError(err);
    }
  }

  return (
    <>
      <h2 className="mb-4 text-xl font-semibold text-slate-800">Appointments</h2>

      <div className={`${cardClass} mb-6 flex flex-wrap items-end gap-4`}>
        <Field id="filter-date" label="Show date">
          <input
            id="filter-date"
            type="date"
            className={filterInputClass}
            value={date}
            onChange={(e) => setDate(e.target.value)}
          />
        </Field>
        <Field id="filter-status" label="Status">
          <select
            id="filter-status"
            className={filterInputClass}
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="">All statuses</option>
            {STATUSES.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
        </Field>
        <p className="pb-2 text-sm text-slate-500">
          {loading ? "Loading..." : `Showing ${appointments.length} of ${total}`}
        </p>
      </div>

      {error && <p className={`${errorClass} mb-4`}>{error}</p>}
      {notice && <p className={`${noticeClass} mb-4`}>{notice}</p>}

      <div className={`${panelClass} overflow-x-auto`}>
        <table className="w-full text-left text-sm">
          <thead className="bg-slate-50 text-slate-600">
            <tr>
              <th className="px-4 py-3 font-medium">Time</th>
              <th className="px-4 py-3 font-medium">Patient</th>
              <th className="px-4 py-3 font-medium">Doctor</th>
              <th className="px-4 py-3 font-medium">Reason</th>
              <th className="px-4 py-3 font-medium">Priority</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {sorted.map((a) => (
              <tr key={a.id} className="hover:bg-slate-50">
                <td className="whitespace-nowrap px-4 py-3">{a.appointmentTime.slice(0, 5)}</td>
                <td className="px-4 py-3 font-medium text-slate-900">{patientName(a.patientId)}</td>
                <td className="px-4 py-3">{doctorName(a.doctorId)}</td>
                <td className="px-4 py-3">{a.reason}</td>
                <td className="px-4 py-3">
                  {a.priority === "EMERGENCY" ? (
                    <span className="rounded bg-red-100 px-2 py-0.5 font-medium text-red-700">EMERGENCY</span>
                  ) : (
                    "Normal"
                  )}
                </td>
                <td className="px-4 py-3">
                  <select
                    className={tableSelectClass}
                    value={a.status}
                    onChange={(e) => changeStatus(a.id, e.target.value)}
                  >
                    {STATUSES.map((s) => (
                      <option key={s} value={s}>{s}</option>
                    ))}
                  </select>
                </td>
              </tr>
            ))}
            {!loading && sorted.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-slate-500">
                  No appointments for these filters.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {canBook && (
        <section className={`${cardClass} mt-8`}>
          <h3 className="mb-4 text-lg font-semibold text-slate-800">Book an appointment</h3>
          <form onSubmit={handleBook} className="grid gap-4 sm:grid-cols-2">
            <Field id="booking-patient" label="Patient">
              <select
                id="booking-patient"
                className={inputClass}
                value={booking.patientId}
                onChange={(e) => setBooking({ ...booking, patientId: e.target.value })}
                required
              >
                <option value="">Choose a patient</option>
                {patients.map((p) => (
                  <option key={p.id} value={p.id}>{p.fullName} ({p.phone})</option>
                ))}
              </select>
            </Field>
            <Field id="booking-doctor" label="Doctor">
              <select
                id="booking-doctor"
                className={inputClass}
                value={booking.doctorId}
                onChange={(e) => setBooking({ ...booking, doctorId: e.target.value })}
                required
              >
                <option value="">Choose a doctor</option>
                {doctors.map((d) => (
                  <option key={d.id} value={d.id}>{d.fullName} - {d.specialization}</option>
                ))}
              </select>
            </Field>
            <Field id="booking-date" label="Appointment date">
              <input
                id="booking-date"
                type="date"
                className={inputClass}
                value={booking.appointmentDate}
                onChange={(e) => setBooking({ ...booking, appointmentDate: e.target.value })}
                required
              />
            </Field>
            <Field id="booking-time" label="Appointment time">
              <input
                id="booking-time"
                type="time"
                className={inputClass}
                value={booking.appointmentTime}
                onChange={(e) => setBooking({ ...booking, appointmentTime: e.target.value })}
                required
              />
            </Field>
            <Field id="booking-reason" label="Reason" className="sm:col-span-2">
              <input
                id="booking-reason"
                className={inputClass}
                maxLength={255}
                value={booking.reason}
                onChange={(e) => setBooking({ ...booking, reason: e.target.value })}
                required
              />
            </Field>
            <Field id="booking-priority" label="Priority">
              <select
                id="booking-priority"
                className={inputClass}
                value={booking.priority}
                onChange={(e) => setBooking({ ...booking, priority: e.target.value })}
              >
                {PRIORITIES.map((p) => (
                  <option key={p} value={p}>{p}</option>
                ))}
              </select>
            </Field>
            <div className="flex items-end sm:col-span-2">
              <button type="submit" className={buttonClass}>
                Book appointment
              </button>
            </div>
          </form>
        </section>
      )}
    </>
  );
}
