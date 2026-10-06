"use server";

import { revalidatePath } from "next/cache";

import { resolveChatModeration } from "../../lib/admin-api";

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
  revalidatePath("/moderation");
  revalidatePath("/");
}
