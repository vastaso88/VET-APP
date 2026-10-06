import { cache } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

export const ADMIN_COOKIE = "vet_admin_access_token";

export type AdminUser = {
  id: string;
  email: string;
};

export type DataSourceSummary = {
  source: string;
  release: string;
  place_count: number;
  imported_at: string;
};

export type ScrapeRunSummary = {
  id: string;
  engine: string;
  status: string;
  coverage_key: string | null;
  source_names: unknown;
  place_count: number;
  error_message: string | null;
  requested_at: string | null;
  started_at: string | null;
  finished_at: string | null;
};

export type AdminOverview = {
  metrics: {
    users: number;
    pets: number;
    conversations: number;
    radar_places: number;
    radar_osm: number;
    radar_open: number;
    open_moderation: number;
    scrape_runs: number;
  };
  moderation: {
    radar_reports: number;
    chat_reports: number;
    marketplace_reports: number;
  };
  data_sources: DataSourceSummary[];
  recent_runs: ScrapeRunSummary[];
};

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

async function tokenFromCookie(): Promise<string | null> {
  const cookieStore = await cookies();
  return cookieStore.get(ADMIN_COOKIE)?.value ?? null;
}

async function adminFetch(path: string, token: string): Promise<Response> {
  return fetch(`${apiBaseUrl()}${path}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
    cache: "no-store",
  });
}

export const getAdminSession = cache(async (): Promise<AdminUser | null> => {
  const token = await tokenFromCookie();
  if (!token) return null;

  try {
    const response = await adminFetch("/admin/me", token);
    if (!response.ok) return null;
    return (await response.json()) as AdminUser;
  } catch {
    return null;
  }
});

export async function requireAdminSession(): Promise<AdminUser> {
  const user = await getAdminSession();
  if (!user) redirect("/login");
  return user;
}

export async function getAdminOverview(): Promise<AdminOverview> {
  await requireAdminSession();
  const token = await tokenFromCookie();
  if (!token) redirect("/login");

  const response = await adminFetch("/admin/overview", token);
  if (response.status === 401 || response.status === 403) redirect("/login");
  if (!response.ok) {
    throw new Error(`Admin overview unavailable (${response.status})`);
  }

  return (await response.json()) as AdminOverview;
}
