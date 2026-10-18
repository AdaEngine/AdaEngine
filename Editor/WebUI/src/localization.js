// The browser adapter uses the same catalogs and preference values as native Studio.
const catalog =
  typeof __STUDIO_AGENT_LOCALES__ === "undefined"
    ? {}
    : __STUDIO_AGENT_LOCALES__;
export function languagePreference() {
  try {
    return localStorage.getItem("AdaEditor.language") || "system";
  } catch {
    return "system";
  }
}
export function setLanguage(preference) {
  if (!["system", "en", "ru"].includes(preference))
    throw new Error("Invalid language");
  localStorage.setItem("AdaEditor.language", preference);
}
export function resolveLanguage(preference, languages) {
  if (preference !== "system") return preference;
  for (const id of languages) {
    const base = id.toLowerCase().split(/[-_]/)[0];
    if (["ru", "en"].includes(base)) return base;
  }
  return "en";
}
export function t(key, ...values) {
  const language = resolveLanguage(
    languagePreference(),
    globalThis.navigator?.languages || [],
  );
  return (catalog[language]?.[key] || key).replace(/\{(\d+)\}/g, (_, index) =>
    String(values[index] ?? ""),
  );
}
