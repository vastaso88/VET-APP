"use server";

import { revalidatePath } from "next/cache";

import {
  discoverScientificEvidence,
  ingestScientificEvidence,
  type ScientificDiscoveryResult,
} from "../../../lib/admin-api";

export type ScientificActionState = {
  status: "idle" | "success" | "error";
  operation?: "discover" | "ingest";
  message?: string;
  result?: ScientificDiscoveryResult;
};

export async function runScientificDiscovery(
  _previous: ScientificActionState,
  formData: FormData,
): Promise<ScientificActionState> {
  const query = String(formData.get("query") ?? "").trim();
  const species = String(formData.get("species") ?? "dog");
  const intent = String(formData.get("intent") ?? "clinical_question");
  const max_results = Number(formData.get("max_results") ?? 10);
  const operation = String(formData.get("operation") ?? "discover");

  if (query.length < 2) {
    return { status: "error", message: "Query is required." };
  }
  if (operation !== "discover" && operation !== "ingest") {
    return { status: "error", message: "Invalid operation." };
  }

  try {
    const input = { query, species, intent, max_results };
    const result =
      operation === "ingest"
        ? await ingestScientificEvidence(input)
        : await discoverScientificEvidence(input);

    if (operation === "ingest") {
      revalidatePath("/data/scientific");
      revalidatePath("/jobs");
      revalidatePath("/");
    }

    const ingestion = result.ingestion;
    return {
      status: "success",
      operation,
      result,
      message:
        operation === "ingest" && ingestion
          ? `Scientific ingestion completed: ${ingestion.inserted} inserted, ${ingestion.updated} updated, ${ingestion.skipped} skipped.`
          : `${result.results.length} deduplicated results returned by ${result.backend}.`,
    };
  } catch (error) {
    return {
      status: "error",
      operation: operation === "ingest" ? "ingest" : "discover",
      message: error instanceof Error ? error.message : "Scientific operation failed.",
    };
  }
}
