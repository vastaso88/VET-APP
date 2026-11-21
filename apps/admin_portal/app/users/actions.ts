"use server";

import { revalidatePath } from "next/cache";
import {
  changeAdminUserPlan,
  executeUserAction,
  previewUserAction,
  type UserActionInput,
} from "../../lib/admin-api";

export async function prepareAction(input: UserActionInput) {
  return previewUserAction(input);
}

export async function confirmAction(token: string) {
  const outcome = await executeUserAction(token);
  revalidatePath("/users", "layout");
  revalidatePath("/moderation", "layout");
  for (const result of outcome.results) revalidatePath(`/users/${result.id}`);
  return outcome;
}

export async function changePlan(formData: FormData): Promise<void> {
  const ownerId = String(formData.get("owner_id") ?? "");
  const raw = String(formData.get("plan") ?? "");
  if (!/^[a-f0-9-]{36}$/i.test(ownerId) || !["none", "plus", "pro", "ultra"].includes(raw)) {
    throw new Error("Invalid plan change");
  }
  await changeAdminUserPlan(ownerId, raw === "none" ? null : raw as "plus" | "pro" | "ultra");
  revalidatePath("/users", "layout");
  revalidatePath(`/users/${ownerId}`);
}
