/** Centralized admin cookie and Supabase endpoints, safe in Next.js Proxy. */
export const ADMIN_COOKIE = "vet_admin_access_token";
export const ADMIN_REFRESH_COOKIE = "vet_admin_refresh_token";
// Admin-only refresh lifetime. Server-side cookies are httpOnly, secure in production.
export const ADMIN_REFRESH_MAX_AGE = 7 * 24 * 60 * 60;

export function apiBaseUrl(): string {
  const configured = process.env.VET_API_BASE_URL?.trim();
  if (configured) return configured.replace(/\/$/, "");
  return "https://vet-app-psi-nine.vercel.app";
}

export function supabaseUrl(): string {
  const configured =
    process.env.ADMIN_SUPABASE_URL?.trim() ??
    process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  if (configured) return configured.replace(/\/$/, "");
  return "https://ywbuzgwbkrmkukkpysbz.supabase.co";
}

export function supabasePublishableKey(): string {
  return (
    process.env.ADMIN_SUPABASE_PUBLISHABLE_KEY?.trim() ??
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?.trim() ??
    "sb_publishable_t5vFAehg91FYPh_rFLOiUQ_Wv9tFh5m"
  );
}
