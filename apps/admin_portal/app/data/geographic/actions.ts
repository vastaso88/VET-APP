"use server";

import { revalidatePath } from "next/cache";

import {
  executeGeographicIngestion,
  previewGeographicIngestion,
  type GeographicOperationResult,
} from "../../../lib/admin-api";

export type GeographicActionState = {
  status: "idle" | "success" | "error";
  operation?: "preview" | "execute";
  message?: string;
  result?: GeographicOperationResult;
};

export async function runGeographicOperation(
  _previous: GeographicActionState,
  formData: FormData,
): Promise<GeographicActionState> {
  const latitude = Number(formData.get("latitude"));
  const longitude = Number(formData.get("longitude"));
  const radius_km = Number(formData.get("radius_km"));
  const operation = String(formData.get("operation") ?? "preview");

  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    !Number.isFinite(radius_km)
  ) {
    return { status: "error", message: "Invalid coordinates or radius." };
  }
  if (operation !== "preview" && operation !== "execute") {
    return { status: "error", message: "Invalid operation." };
  }

  try {
    const input = { latitude, longitude, radius_km };
    const result =
      operation === "execute"
        ? await executeGeographicIngestion(input)
        : await previewGeographicIngestion(input);

    if (operation === "execute") {
      revalidatePath("/data/geographic");
      revalidatePath("/jobs");
      revalidatePath("/");
    }

    return {
      status: "success",
      operation,
      result,
      message:
        operation === "execute"
          ? "Ingestion completed and persisted."
          : "Preview completed. No database rows were changed.",
    };
  } catch (error) {
    return {
      status: "error",
      operation,
      message: error instanceof Error ? error.message : "Operation failed.",
    };
  }
}
