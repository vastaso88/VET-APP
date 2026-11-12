"use server";

import { revalidatePath } from "next/cache";

import {
  correctClosedByAgeDateRequest,
  eraseClosedByAgeAccountRequest,
  setClosedByAgeCorrectionRequestedRequest,
} from "../../lib/admin-api";

function refresh(): void {
  revalidatePath("/age");
}

function refOf(formData: FormData): string {
  const ref = String(formData.get("ref") ?? "").trim();
  if (!ref || ref.length > 100) throw new Error("Missing or invalid account reference");
  return ref;
}

/**
 * Erases a closed account with the same eraser as the owner's own deletion.
 * The person at the desk ticks the box to say they checked the row; the
 * reference travels as the confirmation the API requires. Nothing but the
 * numbers comes back, and nothing is written down here.
 */
export async function eraseClosedAccount(formData: FormData): Promise<void> {
  const ref = refOf(formData);
  if (formData.get("checked") !== "on") throw new Error("Tick the box to confirm");

  await eraseClosedByAgeAccountRequest(ref, ref);
  refresh();
}

/** Support's correction of a mistyped date of birth (right to rectification). */
export async function correctClosedAccountDate(formData: FormData): Promise<void> {
  const ref = refOf(formData);
  const birthDate = String(formData.get("birth_date") ?? "");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) throw new Error("Use a valid date");

  await correctClosedByAgeDateRequest(ref, birthDate);
  refresh();
}

/** Notes (or clears) that the person wrote that the date was a mistake. */
export async function markCorrectionRequested(formData: FormData): Promise<void> {
  const ref = refOf(formData);
  const requested = String(formData.get("requested") ?? "") === "true";

  await setClosedByAgeCorrectionRequestedRequest(ref, requested);
  refresh();
}
