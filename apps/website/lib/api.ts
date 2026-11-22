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

// Only the fields app/account/page.tsx reads from GET /subscription/status
// (GetOrCreateSubscriptionOutput). The response also carries store_subscription,
// plan_source, limits, plan_limits, test_period, ...: the site does not show them.
export type BillingStatus = {
  has_access: boolean;
  subscription: { plan: string | null; trial_ends_at: string };
};
