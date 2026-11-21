"use server";

import { revalidatePath } from "next/cache";
import {
  saveAdminPricingFeature, saveAdminPricingPrice,
  type PricingFeatureUpdate, type PricingPriceUpdate,
} from "../../lib/admin-api";

function safeMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Operazione non disponibile.";
}

export async function savePricingFeature(input: PricingFeatureUpdate) {
  try {
    await saveAdminPricingFeature(input);
    revalidatePath("/pricing");
    return { ok: true as const };
  } catch (error) {
    return { ok: false as const, error: safeMessage(error) };
  }
}

export async function savePricingPrice(input: PricingPriceUpdate) {
  try {
    await saveAdminPricingPrice(input);
    revalidatePath("/pricing");
    return { ok: true as const };
  } catch (error) {
    return { ok: false as const, error: safeMessage(error) };
  }
}
