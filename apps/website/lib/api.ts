import { cookies } from "next/headers";
import { redirect } from "next/navigation";
export const SESSION_COOKIE = "quokka_session";

export async function api(
  path: string,
  init: RequestInit = {},
  authenticated = true,
) {
  const configured = process.env.QUOKKA_API_URL;
  if (!configured) throw new Error("QUOKKA_API_URL missing");
  const base = new URL(configured);
  if (
    base.username ||
    base.password ||
    (base.protocol !== "https:" &&
      !(
        process.env.NODE_ENV !== "production" &&
        ["localhost", "127.0.0.1"].includes(base.hostname)
      ))
  ) {
    throw new Error("Invalid API origin");
  }
  const token = authenticated
    ? (await cookies()).get(SESSION_COOKIE)?.value
    : null;
  if (authenticated && !token) redirect("/login");
  const response = await fetch(`${base.origin}${path}`, {
    ...init,
    cache: "no-store",
    signal: AbortSignal.timeout(20000),
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  });
  if (authenticated && response.status === 401)
    redirect("/login?notice=expired");
  return response;
}

export type BillingStatus = {
  plan_limits?: Record<
    string,
    {
      max_pets: number;
      max_chats_per_pet: number;
      daily_questions: number;
      max_devices: number;
    }
  >;
  has_access: boolean;
  test_period: boolean;
  billing_enabled: boolean;
  subscription: { plan: string | null; trial_ends_at: string };
  payment?: {
    status: string;
    current_period_end: string | null;
    cancel_at_period_end: boolean;
    risk_hold: boolean;
  };
  prices: {
    plan: string;
    amount: number | null;
    currency: string;
    interval: string;
    interval_count: number;
  }[];
};
