"use server";

import { revalidatePath } from "next/cache";

import {
  createAdminSchedule,
  updateAdminSchedule,
} from "../../lib/admin-api";

export async function createGeographicSchedule(formData: FormData): Promise<void> {
  const name = String(formData.get("name") ?? "").trim();
  const intervalHours = Number(formData.get("interval_hours") ?? 24);
  const latitude = Number(formData.get("latitude"));
  const longitude = Number(formData.get("longitude"));
  const radiusKm = Number(formData.get("radius_km"));
  const runImmediately = formData.get("run_immediately") === "on";

  await createAdminSchedule({
    name,
    engine: "geographic",
    interval_hours: intervalHours,
    run_immediately: runImmediately,
    payload: {
      latitude,
      longitude,
      radius_km: radiusKm,
    },
  });
  revalidatePath("/jobs");
}

export async function createScientificSchedule(formData: FormData): Promise<void> {
  const name = String(formData.get("name") ?? "").trim();
  const intervalHours = Number(formData.get("interval_hours") ?? 168);
  const query = String(formData.get("query") ?? "").trim();
  const species = String(formData.get("species") ?? "dog");
  const intent = String(formData.get("intent") ?? "clinical_question");
  const maxResults = Number(formData.get("max_results") ?? 10);
  const runImmediately = formData.get("run_immediately") === "on";

  await createAdminSchedule({
    name,
    engine: "scientific",
    interval_hours: intervalHours,
    run_immediately: runImmediately,
    payload: {
      query,
      species,
      intent,
      max_results: maxResults,
    },
  });
  revalidatePath("/jobs");
}

export async function scheduleAction(formData: FormData): Promise<void> {
  const scheduleId = String(formData.get("schedule_id") ?? "");
  const action = String(formData.get("action") ?? "");
  if (!scheduleId) throw new Error("Missing schedule id");
  if (!["enable", "disable", "run_now", "delete"].includes(action)) {
    throw new Error("Invalid schedule action");
  }

  await updateAdminSchedule(
    scheduleId,
    action as "enable" | "disable" | "run_now" | "delete",
  );
  revalidatePath("/jobs");
}
