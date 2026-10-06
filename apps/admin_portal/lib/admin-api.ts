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

export type RadarModerationItem = {
  id: string;
  kind: string;
  status: string;
  place_type: string;
  name: string | null;
  latitude: number;
  longitude: number;
  address_label: string | null;
  target_source: string | null;
  target_source_id: string | null;
  confirmations: number;
  denials: number;
  created_at: string;
  resolved_at: string | null;
};

export type ChatModerationItem = {
  id: string;
  conversation_id: string;
  message_id: string;
  pet_id: string;
  reason: string;
  details: string | null;
  reported_answer: string;
  status: string;
  created_at: string;
  resolved_at: string | null;
  resolution_note: string | null;
  credited_bug_ref: string | null;
};

export type MarketplaceModerationItem = {
  id: string;
  listing_id: string;
  reason: string;
  created_at: string;
  listing: {
    id: string;
    title: string;
    status: string;
    report_count: number;
    category: string;
    city_label: string | null;
    created_at: string;
  } | null;
};

export type AdminModeration = {
  radar: RadarModerationItem[];
  chat: ChatModerationItem[];
  marketplace: MarketplaceModerationItem[];
};

export type GeographicSource = {
  source: string;
  release: string;
  license: string | null;
  attribution: string | null;
  url: string | null;
  place_count: number;
  imported_at: string;
  min_latitude: number | null;
  max_latitude: number | null;
  min_longitude: number | null;
  max_longitude: number | null;
};

export type GeographicCoverage = {
  coverage_key: string;
  center_latitude: number;
  center_longitude: number;
  radius_km: number;
  source_name: string;
  place_count: number;
  refreshed_at: string;
  expires_at: string;
};

export type AdminGeographicData = {
  counts: {
    osm: number;
    open: number;
    cache: number;
  };
  sources: GeographicSource[];
  coverage: GeographicCoverage[];
};

export type GeographicOperationInput = {
  latitude: number;
  longitude: number;
  radius_km: number;
};

export type GeographicOperationResult = {
  source: string;
  coverage_key: string;
  center: {
    latitude: number;
    longitude: number;
  };
  search_radius_km: number;
  ingestion_radius_km: number;
  place_count: number;
  by_type: Record<string, number>;
  existing_coverage: {
    place_count: number;
    refreshed_at: string;
    expires_at: string;
  } | null;
  sample: Array<{
    name: string;
    place_type: string;
    subtype: string | null;
    city: string | null;
    address_label: string | null;
    latitude: number;
    longitude: number;
    source_external_id: string;
  }>;
  job_id?: string;
  refreshed_at?: string;
  expires_at?: string;
};

export type AdminJob = {
  id: string;
  job_id: string | null;
  engine: string;
  owner_id: string | null;
  coverage_key: string | null;
  status: string;
  search_radius_km: number | null;
  ingestion_radius_km: number | null;
  freshness_ttl_hours: number | null;
  source_names: unknown;
  place_count: number;
  error_message: string | null;
  requested_at: string | null;
  started_at: string | null;
  finished_at: string | null;
  created_at: string;
  updated_at: string;
};

export type ScientificEvidence = {
  title: string;
  journal: string | null;
  year: number | null;
  doi: string | null;
  pmid: string | null;
  tier: string;
  access_depth: string;
  clinical_domain: string;
  species: string;
  snippet: string | null;
  source_url: string | null;
};

export type ScientificDiscoveryResult = {
  backend: string;
  results: ScientificEvidence[];
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

async function adminFetch(
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
  });
}

async function authenticatedAdminRequest<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = await tokenFromCookie();
  if (!token) redirect("/login");

  const response = await adminFetch(path, token, init);
  if (response.status === 401 || response.status === 403) redirect("/login");
  if (!response.ok) {
    let detail = `Admin API unavailable (${response.status})`;
    try {
      const payload = (await response.json()) as { detail?: string };
      if (payload.detail) detail = payload.detail;
    } catch {
      // Keep the HTTP status fallback.
    }
    throw new Error(detail);
  }

  return (await response.json()) as T;
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
  return authenticatedAdminRequest<AdminOverview>("/admin/overview");
}

export async function getAdminModeration(): Promise<AdminModeration> {
  await requireAdminSession();
  return authenticatedAdminRequest<AdminModeration>("/admin/moderation");
}

export async function resolveChatModeration(
  reportId: string,
  status: "under_review" | "resolved" | "wont_fix",
  resolutionNote?: string,
): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest(`/admin/moderation/chat/${encodeURIComponent(reportId)}`, {
    method: "POST",
    body: JSON.stringify({
      status,
      resolution_note: resolutionNote?.trim() || null,
    }),
  });
}

export async function getAdminGeographic(): Promise<AdminGeographicData> {
  await requireAdminSession();
  return authenticatedAdminRequest<AdminGeographicData>("/admin/geographic");
}

export async function previewGeographicIngestion(
  input: GeographicOperationInput,
): Promise<GeographicOperationResult> {
  await requireAdminSession();
  return authenticatedAdminRequest<GeographicOperationResult>(
    "/admin/geographic/preview",
    {
      method: "POST",
      body: JSON.stringify(input),
    },
  );
}

export async function executeGeographicIngestion(
  input: GeographicOperationInput,
): Promise<GeographicOperationResult> {
  await requireAdminSession();
  return authenticatedAdminRequest<GeographicOperationResult>(
    "/admin/geographic/execute",
    {
      method: "POST",
      body: JSON.stringify(input),
    },
  );
}

export async function getAdminJobs(): Promise<AdminJob[]> {
  await requireAdminSession();
  const payload = await authenticatedAdminRequest<{ jobs: AdminJob[] }>("/admin/jobs");
  return payload.jobs;
}

export async function discoverScientificEvidence(input: {
  query: string;
  species: string;
  intent: string;
  max_results: number;
}): Promise<ScientificDiscoveryResult> {
  await requireAdminSession();
  return authenticatedAdminRequest<ScientificDiscoveryResult>(
    "/admin/scientific/discover",
    {
      method: "POST",
      body: JSON.stringify(input),
    },
  );
}
