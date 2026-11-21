"use server";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { api, SESSION_COOKIE } from "../lib/api";

export async function authenticate(form: FormData) {
  const mode = "login";
  const email = String(form.get("email") ?? "").trim();
  const password = String(form.get("password") ?? "");
  if (!email || !password || email.length > 254 || password.length > 72)
    redirect("/login?notice=invalid");
  let response: Response;
  try {
    response = await api(
      `/auth/${mode}`,
      { method: "POST", body: JSON.stringify({ email, password }) },
      false,
    );
  } catch {
    redirect("/login?notice=unavailable");
  }
  if (!response.ok) redirect("/login?notice=invalid");
  const data = await response.json();
  if (!data.access_token) redirect("/login?notice=confirm");
  // No tokens in URLs, browser storage or rendered HTML. Reauthenticate after one hour.
  (await cookies()).set(SESSION_COOKIE, data.access_token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 3600,
  });
  redirect("/account");
}
export async function logout() {
  (await cookies()).delete(SESSION_COOKIE);
  redirect("/login");
}
