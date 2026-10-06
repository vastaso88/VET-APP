"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { ADMIN_COOKIE, apiBaseUrl } from "../../lib/admin-api";

type LoginPayload = {
  access_token?: string;
  user?: {
    email?: string;
  };
};

function loginError(code: string): never {
  redirect(`/login?error=${encodeURIComponent(code)}`);
}

export async function login(formData: FormData): Promise<void> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) loginError("missing");

  let response: Response;
  try {
    response = await fetch(`${apiBaseUrl()}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ email, password }),
      cache: "no-store",
    });
  } catch {
    loginError("backend");
  }

  if (!response.ok) loginError("invalid");

  const payload = (await response.json()) as LoginPayload;
  if (!payload.access_token) loginError("invalid");

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
  if (!adminCheck.ok) loginError("forbidden");

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
