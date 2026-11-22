import { createHash } from "node:crypto";
import { cache } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  ADMIN_COOKIE,
  apiBaseUrl,
} from "./admin-auth-config";

export {
  ADMIN_COOKIE,
  ADMIN_REFRESH_COOKIE,
  ADMIN_REFRESH_MAX_AGE,
  apiBaseUrl,
  supabaseUrl,
  supabasePublishableKey,
} from "./admin-auth-config";

export type AdminUser = {
  id: string;
  email: string;
};

export type UserAccount = {
  id: string;
  email: string | null;
  created_at: string | null;
  last_sign_in_at: string | null;
  email_verified: boolean;
  banned_until: string | null;
  stored_plan: string | null;
  effective_plan: string | null;
  access: "developer" | "test" | "not_started" | "plan" | "trial" | "expired";
  trial_ends_at: string | null;
  subscription_created_at: string | null;
  total_paid_minor: number | null;
  currency: string | null;
  last_payment_at: string | null;
  location: { country_code: string | null; city: string | null; source: string | null; updated_at: string | null } | null;
};

export type AdminUsers = {
  users: UserAccount[];
  total: number;
  page: number;
  page_size: number;
  test_plan: string | null;
  payments_available: boolean;
  countries: Record<string, number>;
};

export async function getAdminUsers(q: string, page: number, country = ""): Promise<AdminUsers | null> {
  await requireAdminSession();
  const params = new URLSearchParams({ q, page: String(page), country });
  try {
    return await authenticatedAdminRequest<AdminUsers>(`/admin/users?${params}`);
  } catch (error) {
    if (error instanceof AdminApiError || error instanceof TypeError) return null;
    throw error;
  }
}

export type AdminPet = {
  country: string | null;
  region: string | null;
  city: string | null;
  id: string;
  owner_id: string;
  name: string;
  species: string;
  species_group: string | null;
  breed: string | null;
  is_active: boolean | null;
  is_exotic: boolean | null;
  is_memorial: boolean | null;
};

export type AdminPets = {
  pets: AdminPet[];
  total: number;
  page: number;
  page_size: number;
};

export async function getAdminPets(
  q: string,
  page: number,
  species = "",
  status = "",
  country = "",
  region = "",
): Promise<AdminPets | null> {
  await requireAdminSession();
  const params = new URLSearchParams({ q, page: String(page), species, status, country, region });
  try {
    return await authenticatedAdminRequest<AdminPets>(`/admin/pets?${params}`);
  } catch (error) {
    if (error instanceof AdminApiError || error instanceof TypeError) return null;
    throw error;
  }
}

export type UserCase = { owner_id: string; queue: "marketplace" | "marketplace_messages"; id: string };
export type UserActionInput = {
  action: "restrict_marketplace" | "lift_marketplace" | "revoke_devices";
  reason: "spam" | "scam" | "harassment" | "prohibited_items" | "other";
  note: string;
  duration_days: number;
  owner_ids?: string[];
  cases?: UserCase[];
  all_results?: boolean;
  q?: string;
  country?: string;
};
export type UserActionPreview = {
  token: string;
  users: { id: string; email: string | null; case: UserCase | null }[];
  action: UserActionInput["action"];
  reason: string;
  note: string;
  duration_days: number;
  expires_at: number;
};
export type UserActionResult = { id: string; status: string; changed: boolean };
export type ModerationEvent = {
  id: string; queue: "marketplace" | "marketplace_messages"; direction: "received" | "filed";
  reason: string; status: string; created_at: string; resolved_at: string | null;
  resolution_action: string | null; resolved_by_admin_id: string | null;
};
export type UserDetail = {
  user: UserAccount;
  usage: {
    pets: number; conversations: number; messages: number; listings: number;
    last_device_activity_at: string | null; quota_days_7d: number; quota_days_30d: number;
    daily: { day: string; messages: number; vision: number; dictation: number; summary: number; sonnet: number; followup: number }[];
  } | null;
  devices: { device_id: string; first_seen_at: string; last_seen_at: string; revoked_at: string | null }[] | null;
  logins: { occurred_at: string }[] | null;
  actions: { id: string; admin_id: string; action: string; reason: string; note: string;
    case_queue: string | null; case_id: string | null; expires_at: string | null;
    changed: boolean; created_at: string }[] | null;
  moderation: { events: ModerationEvent[]; received: number; filed: number; truncated: boolean } | null;
  location: { home_country_code: string | null; home_city: string | null; home_saved_at: string | null;
    current_source: string | null; current_captured_at: string | null }[] | null;
  restriction: { reason: string; note: string | null; created_at: string; expires_at: string | null;
    lifted_at: string | null; created_by_admin_id: string | null; lifted_by_admin_id: string | null }[] | null;
  unavailable: string[];
};

export async function getUserDetail(id: string): Promise<UserDetail | null> {
  await requireAdminSession();
  try {
    return await authenticatedAdminRequest<UserDetail>(`/admin/users/${encodeURIComponent(id)}`);
  } catch (error) {
    if (isAdminApiStatus(error, 404)) return null;
    throw error;
  }
}

export async function previewUserAction(input: UserActionInput): Promise<UserActionPreview> {
  await requireAdminSession();
  return authenticatedAdminRequest<UserActionPreview>("/admin/user-actions/preview", {
    method: "POST", body: JSON.stringify(input),
  });
}

export async function executeUserAction(token: string): Promise<{ results: UserActionResult[] }> {
  await requireAdminSession();
  return authenticatedAdminRequest("/admin/user-actions/execute", {
    method: "POST", body: JSON.stringify({ token, confirmed: true }),
  });
}

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

export type MarketplaceMessageReportItem = {
  id: string;
  conversation_id: string;
  reason: string;
  status: string;
  created_at: string;
  listing_title: string | null;
  subject_owner_id?: string | null;
};

export type MarketplaceRestrictionItem = {
  owner_id: string;
  reason: string;
  note: string | null;
  created_at: string;
  created_by_admin_id: string | null;
  lifted_at: string | null;
  lifted_by_admin_id: string | null;
  expires_at?: string | null;
};

export type AdminModeration = {
  radar: RadarModerationItem[];
  chat: ChatModerationItem[];
  marketplace: MarketplaceModerationItem[];
  marketplace_messages: MarketplaceMessageReportItem[];
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

export type ModerationQueue = "radar" | "chat" | "marketplace" | "marketplace_messages";

export type ModerationDetail = {
  queue: ModerationQueue;
  item: Record<string, unknown>;
  votes?: Array<{ vote: number; created_at: string }>;
};

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
    signal: init.signal ?? AbortSignal.timeout(path === "/admin/me" ? 8000 : 20000),
  });
}

class AdminApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "AdminApiError";
  }
}

function isAdminApiStatus(error: unknown, status: number): boolean {
  return error instanceof AdminApiError && error.status === status;
}

async function authenticatedAdminRequest<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = await tokenFromCookie();
  if (!token) redirect("/login");

  const response = await adminFetch(path, token, init);
  if (response.status === 401) redirect("/login");
  // 403 means denied, not an expired session; don't bounce to login.
  if (!response.ok) {
    let detail = `Admin API unavailable (${response.status})`;
    try {
      const payload = (await response.json()) as { detail?: string };
      if (payload.detail) detail = payload.detail;
    } catch {
      // Keep the HTTP status fallback.
    }
    throw new AdminApiError(response.status, detail);
  }

  return (await response.json()) as T;
}

// A warm Next.js worker can reuse the backend-verified admin identity for
// 30 seconds. Cache keys are SHA-256 hashes of the full token (never stored),
// and every protected data/mutation endpoint still authenticates at the API.
const sessionCache = new Map<string, { user: AdminUser; until: number }>();
const SESSION_TTL_MS = 30_000;
const SESSION_CACHE_MAX = 256;

function tokenExpiryMs(token: string): number {
  try {
    const body = JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString("utf8")) as {
      exp?: number;
    };
    return typeof body.exp === "number" ? body.exp * 1000 : 0;
  } catch {
    return 0;
  }
}

export const getAdminSession = cache(async (): Promise<AdminUser | null> => {
  const token = await tokenFromCookie();
  if (!token) return null;
  const key = createHash("sha256").update(token).digest("hex");
  const now = Date.now();
  const cached = sessionCache.get(key);
  if (cached && cached.until > now) return cached.user;
  sessionCache.delete(key);

  // A transient error should render an error boundary, NEVER force a logout.
  // Only the backend's definitive 401 means the token is invalid/expired.
  const response = await adminFetch("/admin/me", token);
  if (response.status === 401) return null;
  if (!response.ok) {
    throw new AdminApiError(response.status, "Verifica amministratore temporaneamente non disponibile.");
  }
  const user = (await response.json()) as AdminUser;
  if (!user.id || !user.email) throw new Error("Risposta identità amministratore non valida.");
  const expiry = tokenExpiryMs(token) - 15_000;
  const until = Math.min(now + SESSION_TTL_MS, expiry);
  if (until > now) {
    if (sessionCache.size >= SESSION_CACHE_MAX) {
      for (const [k, value] of sessionCache) {
        if (value.until <= now) sessionCache.delete(k);
      }
      if (sessionCache.size >= SESSION_CACHE_MAX) sessionCache.delete(sessionCache.keys().next().value!);
    }
    sessionCache.set(key, { user, until });
  }
  return user;
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

// A separate read: before the backend update or the SQL script, this queue is
// simply empty and the other three keep working.
async function getMarketplaceMessageReports(): Promise<MarketplaceMessageReportItem[]> {
  try {
    const payload = await authenticatedAdminRequest<{ reports: MarketplaceMessageReportItem[] }>(
      "/admin/moderation/marketplace_messages",
    );
    return payload.reports;
  } catch {
    return [];
  }
}

export async function getAdminModeration(): Promise<AdminModeration> {
  await requireAdminSession();
  const payload = await authenticatedAdminRequest<Omit<AdminModeration, "marketplace_messages">>(
    "/admin/moderation",
  );
  return {
    marketplace_messages: await getMarketplaceMessageReports(),
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
  queue: ModerationQueue,
  itemId: string,
): Promise<ModerationDetail | null> {
  await requireAdminSession();
  try {
    return await authenticatedAdminRequest<ModerationDetail>(
      `/admin/moderation/${queue}/${encodeURIComponent(itemId)}`,
    );
  } catch (error) {
    if (isAdminApiStatus(error, 404)) return null;
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

// Before the backend update or the SQL script this list is simply empty.
export async function getMarketplaceRestrictions(): Promise<MarketplaceRestrictionItem[]> {
  await requireAdminSession();
  try {
    const payload = await authenticatedAdminRequest<{ restrictions: MarketplaceRestrictionItem[] }>(
      "/admin/moderation/marketplace_restrictions",
    );
    return payload.restrictions;
  } catch {
    return [];
  }
}

export type ClosedByAgeAccount = {
  /** Keyed reference: the only name of the account the portal ever sees. */
  ref: string;
  closed_at: string;
  days_closed: number;
  /** 30 days or more since the account was closed. */
  past_deadline: boolean;
  /** The person wrote that the date was a mistake: do not erase. */
  correction_requested: boolean;
  /** First letter and domain only, to recognise the sender of a message. */
  email_hint: string | null;
};

export async function getClosedByAgeAccounts(): Promise<ClosedByAgeAccount[]> {
  await requireAdminSession();
  try {
    const payload = await authenticatedAdminRequest<{ accounts: ClosedByAgeAccount[] }>(
      "/admin/age/closed",
    );
    return payload.accounts;
  } catch {
    return [];
  }
}

/** Totals of one model's calls over a period. Aggregates only. */
export type LlmUsageTotals = {
  /** Calls to the model, not answers: one chat answer can take several. */
  calls: number;
  prompt_tokens: number;
  completion_tokens: number;
  cached_tokens: number;
  cache_write_tokens: number;
  total_tokens: number;
  usd: number;
  eur: number;
};

export type LlmModelUsage = {
  model: string;
  /** "Haiku 5.5", "Sonnet 5.5", "gpt-oss-120b". */
  label: string;
  provider: "anthropic" | "groq";
  paid: boolean;
  today: LlmUsageTotals;
  month: LlmUsageTotals;
};

export type LlmDayUsage = {
  /** The ledger's day (UTC), YYYY-MM-DD. */
  date: string;
  usd: number;
  eur: number;
  calls: number;
  paid_calls: number;
  reserve_calls: number;
};

/** "ok"; "reserve" (past the reserve share: Sonnet is off); "exhausted". */
export type LlmBudgetState = "ok" | "reserve" | "exhausted";

/** What the AI costs: from the usage ledger, no owner, no text. */
export type AdminLlmUsage = {
  generated_at: string;
  /** 1 EUR in USD, as configured. */
  usd_per_eur: number;
  /** "us" costs 1.1 times the standard price. */
  inference_geo: string;
  today: {
    date: string;
    spent_usd: number;
    spent_eur: number;
    cap_eur: number | null;
    share_of_cap: number | null;
    state: LlmBudgetState;
  };
  month: {
    month: string;
    spent_usd: number;
    spent_eur: number;
    credits_usd: number;
    share_of_credits: number;
    days_elapsed: number;
    days_in_month: number;
    projected_usd: number;
  };
  models: LlmModelUsage[];
  /** The last 30 days, oldest first, none missing. */
  daily: LlmDayUsage[];
  sonnet_answers_today: number;
  /** Calls the Groq reserve took today. */
  reserve_calls_today: number;
  failed_calls_today: number;
  failed_calls_month: number;
};

/** null when the usage ledger cannot be read (the page says so). */
export async function getAdminLlmUsage(): Promise<AdminLlmUsage | null> {
  await requireAdminSession();
  try {
    return await authenticatedAdminRequest<AdminLlmUsage>("/admin/llm-usage");
  } catch (error) {
    // A failed API answer or a network failure: the page says it. Anything
    // else (a redirect to the sign-in page) must go through.
    if (error instanceof AdminApiError || error instanceof TypeError) return null;
    throw error;
  }
}

export type ClosedByAgeErasure = { rows_deleted: number; files_removed: number };

export async function eraseClosedByAgeAccountRequest(
  ref: string,
  confirm: string,
): Promise<ClosedByAgeErasure> {
  await requireAdminSession();
  const payload = await authenticatedAdminRequest<{ outcome: ClosedByAgeErasure }>(
    `/admin/age/closed/${encodeURIComponent(ref)}/erase`,
    { method: "POST", body: JSON.stringify({ confirm }) },
  );
  return payload.outcome;
}

export async function correctClosedByAgeDateRequest(
  ref: string,
  birthDate: string,
): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest(`/admin/age/closed/${encodeURIComponent(ref)}/correct`, {
    method: "POST",
    body: JSON.stringify({ birth_date: birthDate }),
  });
}

export async function setClosedByAgeCorrectionRequestedRequest(
  ref: string,
  requested: boolean,
): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest(
    `/admin/age/closed/${encodeURIComponent(ref)}/correction-requested`,
    { method: "POST", body: JSON.stringify({ requested }) },
  );
}

export async function resolveMarketplaceMessageModeration(
  reportId: string,
  action: "close_conversation" | "dismiss_report" | "reopen_report",
  resolutionNote?: string,
): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest(
    `/admin/moderation/marketplace_messages/${encodeURIComponent(reportId)}`,
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
    if (isAdminApiStatus(error, 404)) {
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

// --- Billing (App Store / Google Play) -------------------------------------

export type BillingOverview = {
  active_subscriptions: number;
  active_by_plan: Record<string, number>;
  active_by_store: Record<string, number>;
  states: Record<string, number>;
  expiring_7d: number;
  not_renewing: number;
  anomalies: number;
  trials_active: number;
  trials_ending_7d: number;
  trials_expired_without_plan: number;
  revenue: {
    kind: "estimate_gross_list_price";
    monthly_recurring_eur_estimate: number;
    note: string;
    reconciled_eur: number | null;
  };
};

export type BillingUserSubscription = {
  store: string;
  product_id: string;
  plan: string;
  period: string;
  state: string;
  expires_at: string | null;
  auto_renew: boolean;
  grace_expires_at: string | null;
  revoked_at: string | null;
  environment: string;
  last_verified_at: string;
  verification_error_at: string | null;
  anomaly: string | null;
  grants_access: boolean;
};

export type BillingUser = {
  owner_id: string;
  plan: string | null;
  trial_ends_at: string | null;
  subscriptions: BillingUserSubscription[];
};

export async function getBillingOverview(): Promise<BillingOverview> {
  await requireAdminSession();
  return authenticatedAdminRequest<BillingOverview>("/admin/billing/overview");
}

export async function getBillingUser(ownerId: string): Promise<BillingUser> {
  await requireAdminSession();
  return authenticatedAdminRequest<BillingUser>(
    `/admin/billing/users/${encodeURIComponent(ownerId)}`,
  );
}
export async function changeAdminUserPlan(ownerId: string, plan: "plus" | "pro" | "ultra" | null, totpCode: string): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest(`/admin/users/${encodeURIComponent(ownerId)}/plan`, {
    method: "POST",
    body: JSON.stringify({ plan, totp_code: totpCode }),
  });
}
