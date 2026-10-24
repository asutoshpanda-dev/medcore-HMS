// Talks to the MedCore API. Paths start with /api; next.config.mjs forwards them to Spring Boot.

const TOKEN_KEY = "medcore.token";
const ROLE_KEY = "medcore.role";

// The session is kept in sessionStorage: it survives a page refresh and ends when the tab closes.
export function saveSession({ token, role }) {
  sessionStorage.setItem(TOKEN_KEY, token);
  sessionStorage.setItem(ROLE_KEY, role);
}

export function getToken() {
  return sessionStorage.getItem(TOKEN_KEY);
}

export function getRole() {
  return sessionStorage.getItem(ROLE_KEY);
}

// Roles that work in the staff screens (patients and appointments)
export const STAFF_ROLES = ["HOSPITAL_ADMIN", "DOCTOR", "RECEPTIONIST"];

// The first screen each role sees after login. Roles without a screen return null.
export function homePathFor(role) {
  if (role === "PATIENT") return "/portal";
  if (STAFF_ROLES.includes(role)) return "/patients";
  return null;
}

export function clearSession() {
  sessionStorage.removeItem(TOKEN_KEY);
  sessionStorage.removeItem(ROLE_KEY);
}

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// Sends one request and returns the parsed JSON, or null for "204 No Content".
// Throws ApiError with a message that can be shown to the user.
export async function api(path, { method = "GET", body } = {}) {
  const headers = { Accept: "application/json" };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";

  const response = await fetch(path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (response.status === 204) return null;

  const text = await response.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = null;
  }

  if (!response.ok) {
    throw new ApiError(response.status, messageFrom(data, response.status));
  }
  return data;
}

// The server describes errors as ProblemDetail: { title, detail, errors: { field: message } }
function messageFrom(data, status) {
  if (data?.errors && typeof data.errors === "object") {
    return Object.values(data.errors).join(" ");
  }
  if (data?.detail) return data.detail;
  if (data?.title) return data.title;
  if (status === 401) return "Your session has ended. Please log in again.";
  if (status === 403) return "Your account is not allowed to do this.";
  return `Something went wrong (error ${status}).`;
}
