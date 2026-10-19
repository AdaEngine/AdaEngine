import { json } from "./platform.js";
import { LocalizedError } from "./localization.js";

export const creditScale = 1_000_000;
export function creditAmount(value) {
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: 6 }).format(
    value / creditScale,
  );
}
export function validateBalance(value, owner) {
  const fields = [
    "allowance",
    "spent",
    "reserved",
    "available",
    "cycleStart",
    "cycleEnd",
  ];
  if (
    !value ||
    value.accountID?.toLowerCase() !== owner?.toLowerCase() ||
    value.scale !== creditScale || typeof value.closed !== "boolean" || typeof value.suspended !== "boolean" ||
    !fields.every(
      (key) => Number.isSafeInteger(value[key]) && value[key] >= 0,
    ) ||
    value.cycleEnd < value.cycleStart || value.cycleEnd > 32_503_680_000 ||
    value.available !==
      Math.max(0, value.allowance - value.spent - value.reserved)
  ) {
    throw new LocalizedError("AI credit balance is unavailable. Please retry.");
  }
  return value;
}
export async function refreshAICredits(studio, request = json) {
  const owner = studio.account?.id;
  const epoch = (studio.aiRefreshEpoch = (studio.aiRefreshEpoch || 0) + 1);
  if (!owner) {
    studio.aiBalance = null;
    studio.aiCatalog = null;
    studio.aiPhase = "signedout";
    studio.emit();
    return;
  }
  studio.aiPhase = "loading";
  studio.emit();
  try {
    const [catalog, raw] = await Promise.all([
      request("/v1/ai/catalog"),
      request("/v1/ai/balance"),
    ]);
    if (studio.aiRefreshEpoch !== epoch || studio.account?.id !== owner) return;
    const balance = validateBalance(raw, owner);
    if (
      typeof catalog.enabled !== "boolean" ||
      catalog.microcreditsPerCredit !== creditScale || !Array.isArray(catalog.capabilities)
    )
      throw new LocalizedError("Invalid AI catalog");
    studio.aiCatalog = catalog;
    studio.aiBalance = balance;
    studio.aiPhase = "ready";
  } catch {
    if (studio.aiRefreshEpoch !== epoch || studio.account?.id !== owner) return;
    studio.aiCatalog = null;
    studio.aiBalance = null;
    studio.aiPhase = "unavailable";
  }
  studio.emit();
}
export async function requireHostedAI(studio) {
  await studio.refreshAI();
  const balance = studio.aiBalance;
  const provider = studio.providers?.find((p) => p.id === studio.providerID);
  if (provider && !provider.hosted)
    throw new LocalizedError("Ada AI is not available on this server yet.");
  if (
    !balance ||
    !studio.aiCatalog?.enabled ||
    !studio.aiCatalog.capabilities?.includes("llm")
  )
    throw new LocalizedError("Ada AI is not available on this server yet.");
  if (balance.closed || balance.suspended)
    throw new LocalizedError("Ada AI is unavailable for this account.");
  if (!balance.allowance)
    throw new LocalizedError("Cloud Pro includes 500 AI credits per month. Subscribe to use Ada AI.");
  if (!balance.available)
    throw new LocalizedError("Your AI credits are used up. They renew with your monthly Cloud Pro allowance.");
}
