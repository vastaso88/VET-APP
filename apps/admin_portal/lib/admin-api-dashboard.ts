import { AdminApiError, authenticatedAdminRequest, requireAdminSession } from "./admin-api-core";

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
    listing_reviews?: number;
  };
  data_sources: DataSourceSummary[];
  recent_runs: ScrapeRunSummary[];
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
  /** "Haiku 5.5", "Sonnet 5.5"; "gpt-oss-120b" in the old rows. */
  label: string;
  /** "groq": only the rows written before 2026-11-25, when it was removed. */
  provider: "anthropic" | "groq" | "echo";
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
  /** Calls with no price: the old rows of the removed reserve. */
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
