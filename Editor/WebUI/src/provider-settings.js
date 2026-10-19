import { LocalizedError } from "./localization.js";
export function providersForMode(studio, mode = studio.billingMode) {
  return studio.providers.filter((provider) =>
    mode === "codex"
      ? provider.transport === "codex"
      : provider.transport !== "codex" && (mode !== "ada" || provider.hosted === true),
  );
}

export function setBillingMode(studio, mode) {
  if (!["ada", "byok", "codex"].includes(mode))
    throw new LocalizedError("Invalid assistant mode");
  const providers = providersForMode(studio, mode);
  const provider =
    providers.find((value) => value.id === studio.providerID) || providers[0];
  studio.billingMode = mode;
  studio.providerID = provider?.id || "";
  const models = provider?.models || [];
  if (!models.some((value) => value.id === studio.modelID && value.tools))
    studio.modelID = models.find((value) => value.tools)?.id || "";
  studio.emit();
}
