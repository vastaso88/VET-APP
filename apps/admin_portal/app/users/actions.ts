"use server";

import { revalidatePath } from "next/cache";
import {
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
