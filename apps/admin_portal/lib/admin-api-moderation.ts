import { authenticatedAdminRequest, isAdminApiStatus, requireAdminSession } from "./admin-api-core";

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

export type ModerationQueue = "radar" | "chat" | "marketplace" | "marketplace_messages";

export type ModerationDetail = {
  queue: ModerationQueue;
  item: Record<string, unknown>;
  votes?: Array<{ vote: number; created_at: string }>;
};

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
