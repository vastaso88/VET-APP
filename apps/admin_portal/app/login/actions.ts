"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import {
  ADMIN_COOKIE,
  apiBaseUrl,
  supabasePublishableKey,
  supabaseUrl,
} from "../../lib/admin-api";

type SupabaseLoginPayload = {
  access_token?: string;
  error?: string;
  error_description?: string;
  msg?: string;
};

function loginError(code: string): never {
  redirect(`/login?error=${encodeURIComponent(code)}`);
}

export async function login(formData: FormData): Promise<void> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) loginError("missing");

  let authResponse: Response;
  try {
    authResponse = await fetch(
      `${supabaseUrl()}/auth/v1/token?grant_type=password`,
      {
        method: "POST",
        headers: {
          apikey: supabasePublishableKey(),
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({ email, password }),
        cache: "no-store",
      },
    );
  } catch {
    loginError("auth-service");
  }

  if (authResponse.status === 400 || authResponse.status === 401) {
    loginError("invalid");
  }
  if (!authResponse.ok) {
    loginError("auth-service");
  }

  const payload = (await authResponse.json()) as SupabaseLoginPayload;
  if (!payload.access_token) loginError("auth-service");

  let adminCheck: Response;
  try {
    adminCheck = await fetch(`${apiBaseUrl()}/admin/me`, {
      headers: {
        Authorization: `Bearer ${payload.access_token}`,
        Accept: "application/json",
      },
      cache: "no-store",
    });
  } catch {
    loginError("backend");
  }

  if (adminCheck.status === 503) loginError("not-configured");
  if (adminCheck.status === 401) loginError("backend-auth");
  if (adminCheck.status === 403) loginError("forbidden");
  if (!adminCheck.ok) loginError("backend");

  const cookieStore = await cookies();
  cookieStore.set(ADMIN_COOKIE, payload.access_token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60,
  });

  redirect("/");
}

export async function logout(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.delete(ADMIN_COOKIE);
  redirect("/login");
}
