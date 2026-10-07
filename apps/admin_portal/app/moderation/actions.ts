"use server";

import { revalidatePath } from "next/cache";

import {
  resolveChatModeration,
  resolveMarketplaceModeration,
  resolveRadarModeration,
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
