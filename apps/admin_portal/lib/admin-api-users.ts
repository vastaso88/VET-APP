import { AdminApiError, authenticatedAdminRequest, isAdminApiStatus, requireAdminSession } from "./admin-api-core";

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

export async function changeAdminUserPlan(ownerId: string, plan: "plus" | "pro" | "ultra" | null, totpCode: string): Promise<void> {
  await requireAdminSession();
  await authenticatedAdminRequest(`/admin/users/${encodeURIComponent(ownerId)}/plan`, {
    method: "POST",
    body: JSON.stringify({ plan, totp_code: totpCode }),
  });
}
