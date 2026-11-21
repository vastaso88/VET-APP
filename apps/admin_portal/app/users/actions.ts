"use server";

import { revalidatePath } from "next/cache";
import {
  changeAdminUserPlan,
  executeUserAction,
  previewUserAction,
  type UserActionInput,
} from "../../lib/admin-api";
import {
  beginAdminTotpEnrollment,
  finishAdminTotpEnrollment,
} from "../../lib/admin-mfa";

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

function safeMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Operazione non disponibile.";
}

export async function beginPlanTotpSetup() {
  try {
    const result = await beginAdminTotpEnrollment();
    return { ok: true as const, result };
  } catch (error) {
    return { ok: false as const, error: safeMessage(error) };
  }
}

export async function completePlanTotpSetup(factorId: string, code: string) {
  try {
    await finishAdminTotpEnrollment(factorId, code);
    return { ok: true as const };
  } catch (error) {
    return { ok: false as const, error: safeMessage(error) };
  }
}

export async function changePlanWithTotp(
  ownerId: string, rawPlan: string, totpCode: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  if (!/^[a-f0-9-]{36}$/i.test(ownerId) ||
      !["none", "plus", "pro", "ultra"].includes(rawPlan) ||
      !/^\d{6}$/.test(totpCode)) {
    return { ok: false, error: "Inserisci un piano valido e un codice TOTP di 6 cifre." };
  }
  try {
    const plan = rawPlan === "none" ? null : rawPlan as "plus" | "pro" | "ultra";
    await changeAdminUserPlan(ownerId, plan, totpCode);
    revalidatePath("/users", "layout");
    revalidatePath(`/users/${ownerId}`);
    return { ok: true };
  } catch (error) {
    return { ok: false, error: safeMessage(error) };
  }
}
