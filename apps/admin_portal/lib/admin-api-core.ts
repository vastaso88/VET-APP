import { createHash } from "node:crypto";
import { cache } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  ADMIN_COOKIE,
  apiBaseUrl,
} from "./admin-auth-config";

export type AdminUser = {
  id: string;
  email: string;
};

export async function tokenFromCookie(): Promise<string | null> {
  const cookieStore = await cookies();
  return cookieStore.get(ADMIN_COOKIE)?.value ?? null;
}

export async function adminFetch(
  path: string,
  token: string,
  init: RequestInit = {},
): Promise<Response> {
  return fetch(`${apiBaseUrl()}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      ...(init.headers ?? {}),
    },
    cache: "no-store",
    signal: init.signal ?? AbortSignal.timeout(path === "/admin/me" ? 8000 : 20000),
  });
}

export class AdminApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "AdminApiError";
  }
}

export function isAdminApiStatus(error: unknown, status: number): boolean {
  return error instanceof AdminApiError && error.status === status;
}

export async function authenticatedAdminRequest<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = await tokenFromCookie();
  if (!token) redirect("/login");

  const response = await adminFetch(path, token, init);
  if (response.status === 401) redirect("/login");
  // 403 means denied, not an expired session; don't bounce to login.
  if (!response.ok) {
    let detail = `Admin API unavailable (${response.status})`;
    try {
      const payload = (await response.json()) as { detail?: string };
      if (payload.detail) detail = payload.detail;
    } catch {
      // Keep the HTTP status fallback.
    }
    throw new AdminApiError(response.status, detail);
  }

  return (await response.json()) as T;
}

// A warm Next.js worker can reuse the backend-verified admin identity for
// 30 seconds. Cache keys are SHA-256 hashes of the full token (never stored),
// and every protected data/mutation endpoint still authenticates at the API.
const sessionCache = new Map<string, { user: AdminUser; until: number }>();

const SESSION_TTL_MS = 30_000;

const SESSION_CACHE_MAX = 256;

function tokenExpiryMs(token: string): number {
  try {
    const body = JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString("utf8")) as {
      exp?: number;
    };
    return typeof body.exp === "number" ? body.exp * 1000 : 0;
  } catch {
    return 0;
  }
}

export const getAdminSession = cache(async (): Promise<AdminUser | null> => {
  const token = await tokenFromCookie();
  if (!token) return null;
  const key = createHash("sha256").update(token).digest("hex");
  const now = Date.now();
  const cached = sessionCache.get(key);
  if (cached && cached.until > now) return cached.user;
  sessionCache.delete(key);

  // A transient error should render an error boundary, NEVER force a logout.
  // Only the backend's definitive 401 means the token is invalid/expired.
  const response = await adminFetch("/admin/me", token);
  if (response.status === 401) return null;
  if (!response.ok) {
    throw new AdminApiError(response.status, "Verifica amministratore temporaneamente non disponibile.");
  }
  const user = (await response.json()) as AdminUser;
  if (!user.id || !user.email) throw new Error("Risposta identità amministratore non valida.");
  const expiry = tokenExpiryMs(token) - 15_000;
  const until = Math.min(now + SESSION_TTL_MS, expiry);
  if (until > now) {
    if (sessionCache.size >= SESSION_CACHE_MAX) {
      for (const [k, value] of sessionCache) {
        if (value.until <= now) sessionCache.delete(k);
      }
      if (sessionCache.size >= SESSION_CACHE_MAX) sessionCache.delete(sessionCache.keys().next().value!);
    }
    sessionCache.set(key, { user, until });
  }
  return user;
});

export async function requireAdminSession(): Promise<AdminUser> {
  const user = await getAdminSession();
  if (!user) redirect("/login");
  return user;
}
