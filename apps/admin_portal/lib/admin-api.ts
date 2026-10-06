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
  detail_available: boolean;
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
  user_details: {
    auth_accounts: number;
    profiles: number;
    geolocated: number;
    with_pets: number;
    new_7d: number;
    new_30d: number;
  };
  pet_details: {
    total: number;
    active: number;
    exotic: number;
    memorial: number;
    species: Record<string, number>;
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
  admin_resolution_note: string | null;
  resolved_by_admin_id: string | null;
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
  reporter_owner_id: string | null;
  reason: string;
  created_at: string;
  status: string;
  resolution_action: string | null;
  resolution_note: string | null;
  resolved_at: string | null;
  resolved_by_admin_id: string | null;
  listing: {
    id: string;
    owner_id: string;
    title: string;
    description: string | null;
    category: string;
    condition: string;
    price_cents: number | null;
    photo_urls: unknown;
    latitude: number;
    longitude: number;
    status: string;
    report_count: number;
    city_label: string | null;
    created_at: string;
    updated_at: string;
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

export type GeographicUser = {
  owner_id: string;
  email: string | null;
  city: string | null;
  address_label: string | null;
  latitude: number;
  longitude: number;
  created_at: string;
};

export type AdminGeographicData = {
  users_available: boolean;
  counts: {
    osm: number;
    open: number;
    cache: number;
  };
  sources: GeographicSource[];
  coverage: GeographicCoverage[];
  users: GeographicUser[];
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

export type ScientificDocument = {
  id: string;
  title: string;
  journal_name: string | null;
  doi: string | null;
  pmid: string | null;
  publication_year: number | null;
  reliability_tier: string;
  eligible_for_rag: boolean;
  embedding_status: string;
  ingestion_status: string;
  canonical_url: string;
  species_tags: string[];
  clinical_domain: string[];
  created_at: string;
  updated_at: string;
  source_host: string;
  source_name: string;
};

export type ScientificTrustedDomain = {
  id: string;
  host: string;
  display_name: string;
  source_kind: string;
  discovery_only: boolean;
  allowed_for_direct_ingest: boolean;
  authority_score: number | string;
  direct_source_score: number | string;
  registry_consensus_score: number | string;
  veterinary_relevance_score: number | string;
  evidence_policy: string;
  is_active: boolean;
  notes: string | null;
};

export type ScientificRegistry = {
  registry_key: string;
  display_name: string;
  registry_kind: string;
  metric_name: string;
  normalization_strategy: string;
  weight: number | string;
  is_active: boolean;
  source_url: string | null;
  notes: string | null;
};

export type ScientificCatalog = {
  governance_available: boolean;
  metrics: {
    trusted_domains: number;
    documents: number;
    eligible_for_rag: number;
    embedded: number;
    chunks: number;
  };
  trusted_domains: ScientificTrustedDomain[];
  registries: ScientificRegistry[];
  recent_documents: ScientificDocument[];
};

export type ScientificIngestionSummary = {
  inserted: number;
  updated: number;
  skipped: number;
  documents: number;
};

export type ScientificDiscoveryResult = {
  backend: string;
  results: ScientificEvidence[];
  job_id?: string;
  discovered?: number;
  submitted?: number;
  ingestion?: ScientificIngestionSummary;
  catalog?: ScientificCatalog;
};

export type AdminSchedule = {
  id: string;
  name: string;
  engine: "geographic" | "scientific";
  enabled: boolean;
  interval_hours: number;
  payload: Record<string, unknown>;
  next_run_at: string;
  last_run_at: string | null;
  last_status: string | null;
  last_error: string | null;
  last_job_id: string | null;
  locked_at: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
};

export type ModerationDetail = {
  queue: "radar" | "chat" | "marketplace";
  item: Record<string, unknown>;
  votes?: Array<{ vote: number; created_at: string }>;
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
  const payload = await authenticatedAdminRequest<Omit<AdminOverview, "detail_available"> & {
    user_details?: AdminOverview["user_details"];
    pet_details?: AdminOverview["pet_details"];
  }>("/admin/overview");
  const detailAvailable = Boolean(payload.user_details && payload.pet_details);
  return {
    ...payload,
    detail_available: detailAvailable,
    user_details: payload.user_details ?? {
      auth_accounts: payload.metrics.users,
      profiles: 0,
      geolocated: 0,
      with_pets: 0,
      new_7d: 0,
      new_30d: 0,
    },
    pet_details: payload.pet_details ?? {
      total: payload.metrics.pets,
      active: 0,
      exotic: 0,
      memorial: 0,
      species: {},
    },
  };
}

export async function getAdminModeration(): Promise<AdminModeration> {
  await requireAdminSession();
  const payload = await authenticatedAdminRequest<AdminModeration>("/admin/moderation");
  return {
    radar: payload.radar.map((item) => ({
      ...item,
      admin_resolution_note: item.admin_resolution_note ?? null,
      resolved_by_admin_id: item.resolved_by_admin_id ?? null,
    })),
    chat: payload.chat,
    marketplace: payload.marketplace.map((item) => ({
      ...item,
      status: item.status ?? "open",
      reporter_owner_id: item.reporter_owner_id ?? null,
      resolution_action: item.resolution_action ?? null,
      resolution_note: item.resolution_note ?? null,
      resolved_at: item.resolved_at ?? null,
      resolved_by_admin_id: item.resolved_by_admin_id ?? null,
    })),
  };
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
  const payload = await authenticatedAdminRequest<Omit<AdminGeographicData, "users_available"> & {
    users?: GeographicUser[];
  }>("/admin/geographic");
  return {
    ...payload,
    users_available: Array.isArray(payload.users),
    users: payload.users ?? [],
  };
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


export async function getScientificCatalog(): Promise<ScientificCatalog> {
  await requireAdminSession();
  const payload = await authenticatedAdminRequest<Omit<ScientificCatalog, "governance_available"> & {
    trusted_domains?: ScientificTrustedDomain[];
    registries?: ScientificRegistry[];
  }>("/admin/scientific");
  return {
    ...payload,
    governance_available: Array.isArray(payload.trusted_domains),
    trusted_domains: payload.trusted_domains ?? [],
    registries: payload.registries ?? [],
  };
}

export async function ingestScientificEvidence(input: {
  query: string;
  species: string;
  intent: string;
  max_results: number;
}): Promise<ScientificDiscoveryResult> {
  await requireAdminSession();
  return authenticatedAdminRequest<ScientificDiscoveryResult>(
    "/admin/scientific/ingest",
    {
      method: "POST",
      body: JSON.stringify(input),
    },
  );
}


export async function getModerationDetail(
  queue: "radar" | "chat" | "marketplace",
  itemId: string,
): Promise<ModerationDetail | null> {
  await requireAdminSession();
  try {
    return await authenticatedAdminRequest<ModerationDetail>(
      `/admin/moderation/${queue}/${encodeURIComponent(itemId)}`,
    );
  } catch (error) {
    if (error instanceof Error && error.message.includes("(404)")) return null;
    throw error;
  }
}

export async function resolveRadarModeration(
  reportId: string,
  action: "confirm" | "reject" | "reopen",
  resolutionNote?: string,
): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest(
    `/admin/moderation/radar/${encodeURIComponent(reportId)}`,
    {
      method: "POST",
      body: JSON.stringify({
        action,
        resolution_note: resolutionNote?.trim() || null,
      }),
    },
  );
}

export async function resolveMarketplaceModeration(
  reportId: string,
  action: "remove_listing" | "dismiss_report" | "restore_listing" | "reopen_report",
  resolutionNote?: string,
): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest(
    `/admin/moderation/marketplace/${encodeURIComponent(reportId)}`,
    {
      method: "POST",
      body: JSON.stringify({
        action,
        resolution_note: resolutionNote?.trim() || null,
      }),
    },
  );
}

export async function getAdminSchedules(): Promise<{
  available: boolean;
  schedules: AdminSchedule[];
}> {
  await requireAdminSession();
  try {
    const payload = await authenticatedAdminRequest<{ schedules: AdminSchedule[] }>(
      "/admin/schedules",
    );
    return { available: true, schedules: payload.schedules };
  } catch (error) {
    if (error instanceof Error && error.message.includes("(404)")) {
      return { available: false, schedules: [] };
    }
    throw error;
  }
}

export async function createAdminSchedule(input: {
  name: string;
  engine: "geographic" | "scientific";
  interval_hours: number;
  payload: Record<string, unknown>;
  enabled?: boolean;
  run_immediately?: boolean;
}): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest("/admin/schedules", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export async function updateAdminSchedule(
  scheduleId: string,
  action: "enable" | "disable" | "run_now" | "delete",
): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest(
    `/admin/schedules/${encodeURIComponent(scheduleId)}`,
    {
      method: "POST",
      body: JSON.stringify({ action }),
    },
  );
}
