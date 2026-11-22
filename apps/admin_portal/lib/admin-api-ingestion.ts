import { authenticatedAdminRequest, isAdminApiStatus, requireAdminSession } from "./admin-api-core";

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
