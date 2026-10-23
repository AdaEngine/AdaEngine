import { LocalizedError } from "./localization.js";
export function providersForMode(studio, mode = studio.billingMode) {
  return studio.providers.filter((provider) =>
    mode === "codex"
      ? provider.transport === "codex"
      : provider.transport !== "codex" &&
        (mode !== "ada" || provider.hosted === true),
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

// The local launcher advertises metadata before Cloud sign-in. Hosted builds have no such endpoint.
export async function developmentAssistant(request = fetch) {
  try {
    const response = await request("/__dev/studio-config", {
      credentials: "same-origin",
      cache: "no-store",
    });
    if (
      !response.ok ||
      !response.headers.get("Content-Type")?.includes("application/json")
    )
      return null;
    const value = await response.json();
    if (
      value?.development !== true ||
      typeof value.codexEnabled !== "boolean" ||
      !Array.isArray(value.providers)
    )
      return null;
    const providers = value.codexEnabled
      ? value.providers.filter(
          (provider) =>
            provider.transport === "codex" &&
            typeof provider.id === "string" &&
            Array.isArray(provider.models),
        )
      : [];
    return { codexEnabled: value.codexEnabled, providers };
  } catch {
    return null;
  }
}
