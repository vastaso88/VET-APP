"use server";

import {
  discoverScientificEvidence,
  type ScientificDiscoveryResult,
} from "../../../lib/admin-api";

export type ScientificActionState = {
  status: "idle" | "success" | "error";
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

  if (query.length < 2) {
    return { status: "error", message: "Query is required." };
  }

  try {
    const result = await discoverScientificEvidence({
      query,
      species,
      intent,
      max_results,
    });
    return {
      status: "success",
      result,
      message: `${result.results.length} deduplicated results returned by ${result.backend}.`,
    };
  } catch (error) {
    return {
      status: "error",
      message: error instanceof Error ? error.message : "Discovery failed.",
    };
  }
}
