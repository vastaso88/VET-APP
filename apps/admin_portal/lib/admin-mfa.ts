import { cookies } from "next/headers";
import {
  ADMIN_COOKIE,
  ADMIN_REFRESH_COOKIE,
  ADMIN_REFRESH_MAX_AGE,
  requireAdminSession,
  supabasePublishableKey,
  supabaseUrl,
} from "./admin-api";

type Factor = {
  id: string;
  status: string;
  factor_type: string;
};

type FactorList = { factors: Factor[] };

async function sessionToken(): Promise<string> {
  await requireAdminSession();
  const token = (await cookies()).get(ADMIN_COOKIE)?.value;
  if (!token) throw new Error("Sessione amministrativa scaduta: accedi nuovamente.");
  return token;
}

async function supabaseMfaRequest<T>(
  token: string,
  path: string,
  method: "GET" | "POST",
  data?: Record<string, string>,
): Promise<T> {
  const response = await fetch(`${supabaseUrl()}/auth/v1${path}`, {
    method,
    headers: {
      apikey: supabasePublishableKey(),
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
      ...(data ? { "Content-Type": "application/json" } : {}),
    },
    ...(data ? { body: JSON.stringify(data) } : {}),
    cache: "no-store",
  });
  if (!response.ok) {
    if (response.status === 429) throw new Error("Troppi tentativi TOTP, riprova più tardi.");
    if (response.status === 401 || response.status === 403) {
      throw new Error("Sessione non valida: effettua nuovamente il login.");
    }
    if (response.status === 400 || response.status === 422) {
      throw new Error("Codice TOTP non valido o scaduto.");
    }
    throw new Error("Servizio di autenticazione TOTP non disponibile.");
  }
  return response.json() as Promise<T>;
}

export async function getAdminTotpEnabled(): Promise<boolean> {
  const token = await sessionToken();
  const { factors } = await supabaseMfaRequest<FactorList>(token, "/factors", "GET");
  return factors.some((factor) => factor.factor_type === "totp" && factor.status === "verified");
}

export async function beginAdminTotpEnrollment(): Promise<
  { status: "already_enabled" } |
  { status: "setup"; factorId: string; qrDataUrl: string; secret: string }
> {
  const token = await sessionToken();
  const { factors } = await supabaseMfaRequest<FactorList>(token, "/factors", "GET");
  if (factors.some((factor) => factor.factor_type === "totp" && factor.status === "verified")) {
    return { status: "already_enabled" };
  }
  const enrolled = await supabaseMfaRequest<{
    id: string;
    totp: { qr_code: string; secret: string };
  }>(token, "/factors", "POST", {
    factor_type: "totp",
    friendly_name: "VET APP - Piani amministrativi",
  });
  if (!enrolled.id || !enrolled.totp?.qr_code || !enrolled.totp?.secret) {
    throw new Error("Impossibile creare il fattore TOTP.");
  }
  return {
    status: "setup",
    factorId: enrolled.id,
    qrDataUrl: "data:image/svg+xml;base64," +
      Buffer.from(enrolled.totp.qr_code, "utf8").toString("base64"),
    secret: enrolled.totp.secret,
  };
}

export async function finishAdminTotpEnrollment(factorId: string, code: string): Promise<void> {
  if (!/^[a-f0-9-]{36}$/i.test(factorId) || !/^\d{6}$/.test(code)) {
    throw new Error("Codice o fattore TOTP non valido.");
  }
  const token = await sessionToken();
  const challenge = await supabaseMfaRequest<{ id: string }>(
    token, `/factors/${encodeURIComponent(factorId)}/challenge`, "POST", {},
  );
  const verified = await supabaseMfaRequest<{
    access_token: string; refresh_token?: string; expires_in?: number;
  }>(
    token, `/factors/${encodeURIComponent(factorId)}/verify`, "POST",
    { challenge_id: challenge.id, code },
  );
  if (!verified.access_token) throw new Error("Impossibile attivare TOTP.");
  // The first verification upgrades the session and revokes other sessions.
  // Keep this server-side httpOnly; never expose the upgraded JWT to the client.
  const store = await cookies();
  store.set(ADMIN_COOKIE, verified.access_token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: Math.max(60, verified.expires_in ?? 3600),
  });
  // MFA verification may rotate the session's refresh token too.
  if (verified.refresh_token) {
    store.set(ADMIN_REFRESH_COOKIE, verified.refresh_token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: ADMIN_REFRESH_MAX_AGE,
    });
  }
}
