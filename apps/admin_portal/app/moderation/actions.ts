"use server";

import { revalidatePath } from "next/cache";

import {
  resolveChatModeration,
  liftMarketplaceRestrictionRequest,
  resolveMarketplaceMessageModeration,
  resolveMarketplaceModeration,
  resolveRadarModeration,
  restrictMarketplaceUserRequest,
} from "../../lib/admin-api";

function refreshModeration(): void {
  revalidatePath("/moderation");
  revalidatePath("/");
}

export async function resolveChatReport(formData: FormData): Promise<void> {
  const reportId = String(formData.get("report_id") ?? "");
  const status = String(formData.get("status") ?? "");
  const note = String(formData.get("resolution_note") ?? "");

  if (!reportId) throw new Error("Missing report id");
  if (!["under_review", "resolved", "wont_fix"].includes(status)) {
    throw new Error("Invalid moderation status");
  }

  await resolveChatModeration(
    reportId,
    status as "under_review" | "resolved" | "wont_fix",
    note,
  );
  refreshModeration();
  revalidatePath(`/moderation/chat/${reportId}`);
}

export async function resolveRadarReport(formData: FormData): Promise<void> {
  const reportId = String(formData.get("report_id") ?? "");
  const action = String(formData.get("action") ?? "");
  const note = String(formData.get("resolution_note") ?? "");

  if (!reportId) throw new Error("Missing report id");
  if (!["confirm", "reject", "reopen"].includes(action)) {
    throw new Error("Invalid Radar moderation action");
  }

  await resolveRadarModeration(
    reportId,
    action as "confirm" | "reject" | "reopen",
    note,
  );
  refreshModeration();
  revalidatePath(`/moderation/radar/${reportId}`);
}

export async function resolveMarketplaceReport(formData: FormData): Promise<void> {
  const reportId = String(formData.get("report_id") ?? "");
  const action = String(formData.get("action") ?? "");
  const note = String(formData.get("resolution_note") ?? "");

  if (!reportId) throw new Error("Missing report id");
  if (!["remove_listing", "dismiss_report", "restore_listing", "reopen_report"].includes(action)) {
    throw new Error("Invalid Marketplace moderation action");
  }

  await resolveMarketplaceModeration(
    reportId,
    action as "remove_listing" | "dismiss_report" | "restore_listing" | "reopen_report",
    note,
  );
  refreshModeration();
  revalidatePath(`/moderation/marketplace/${reportId}`);
}

export async function resolveMarketplaceMessageReport(formData: FormData): Promise<void> {
  const reportId = String(formData.get("report_id") ?? "");
  const action = String(formData.get("action") ?? "");
  const note = String(formData.get("resolution_note") ?? "");

  if (!reportId) throw new Error("Missing report id");
  if (!["close_conversation", "dismiss_report", "reopen_report"].includes(action)) {
    throw new Error("Invalid marketplace message moderation action");
  }

  await resolveMarketplaceMessageModeration(
    reportId,
    action as "close_conversation" | "dismiss_report" | "reopen_report",
    note,
  );
  refreshModeration();
  revalidatePath(`/moderation/marketplace_messages/${reportId}`);
}

const RESTRICTION_REASONS = ["spam", "scam", "harassment", "prohibited_items", "other"];

export async function restrictMarketplaceUser(formData: FormData): Promise<void> {
  const ownerId = String(formData.get("owner_id") ?? "").trim();
  const reason = String(formData.get("reason") ?? "");
  const note = String(formData.get("note") ?? "");

  if (!ownerId || ownerId.length > 100) throw new Error("Missing or invalid user id");
  if (!RESTRICTION_REASONS.includes(reason)) throw new Error("Invalid restriction reason");

  await restrictMarketplaceUserRequest(
    ownerId,
    reason as "spam" | "scam" | "harassment" | "prohibited_items" | "other",
    note,
  );
  refreshModeration();
}

export async function liftMarketplaceRestriction(formData: FormData): Promise<void> {
  const ownerId = String(formData.get("owner_id") ?? "").trim();
  if (!ownerId) throw new Error("Missing user id");

  await liftMarketplaceRestrictionRequest(ownerId);
  refreshModeration();
}
