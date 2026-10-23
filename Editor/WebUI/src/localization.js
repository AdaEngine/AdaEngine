// The browser adapter uses the same catalogs and preference values as native Studio.
const catalog =
  typeof __STUDIO_AGENT_LOCALES__ === "undefined"
    ? {}
    : __STUDIO_AGENT_LOCALES__;
export function languagePreference() {
  try {
    const preference = localStorage.getItem("AdaEditor.language");
    return ["en", "ru", "system"].includes(preference) ? preference : "system";
  } catch {
    return "system";
  }
}
export function setLanguage(preference) {
  if (!["system", "en", "ru"].includes(preference))
    throw new LocalizedError("Invalid language");
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
export function currentLanguage() {
  return resolveLanguage(
    languagePreference(),
    globalThis.navigator?.languages || [],
  );
}
export function t(key, ...values) {
  return translatedText(key, currentLanguage(), ...values);
}
export function translatedText(key, language, ...values) {
  return (catalog[language]?.[key] || key).replace(/\{(\d+)\}/g, (_, index) =>
    String(values[index] ?? ""),
  );
}

/** Keep app-authored errors translatable while an existing alert stays mounted. */
export class LocalizedError extends Error {
  constructor(key, ...values) {
    super(key);
    Object.defineProperty(this, "message", {
      configurable: true,
      get: () => t(key, ...values),
    });
  }
}
