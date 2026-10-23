import { currentLanguage, translatedText } from "./localization.js";

// Instant local continuations; arbitrary drafts can use the separate tool-free completion endpoint.
const examples = [
  (language) =>
    translatedText(
      "Create a game where I explore a forest, collect crystals and unlock new paths.",
      language,
    ),
  (language) =>
    translatedText(
      "I want a game about exploring an island and finding treasures.",
      language,
    ),
  (language) =>
    translatedText(
      "An adventure game where I explore ruins, solve puzzles and find my way home.",
      language,
    ),

  (language) =>
    translatedText(
      "Create a platformer where I jump between floating islands and collect stars.",
      language,
    ),
  (language) =>
    translatedText(
      "Create a racing game where I dodge obstacles and beat my best time.",
      language,
    ),
  (language) =>
    translatedText(
      "Create a puzzle game where I move blocks to open a path to the exit.",
      language,
    ),
  (language) =>
    translatedText(
      "Create a cozy farming game where I grow plants and explore a small village.",
      language,
    ),
  (language) =>
    translatedText(
      "I want to make a game where I explore a mysterious island and discover hidden treasures.",
      language,
    ),
  (language) =>
    translatedText(
      "A game about a robot that collects spare parts and builds its own little world.",
      language,
    ),
  (language) =>
    translatedText(
      "A platformer where each level introduces a new obstacle and a secret to discover.",
      language,
    ),
  (language) =>
    translatedText(
      "A racing game with short tracks, checkpoints and a timer.",
      language,
    ),
  (language) =>
    translatedText(
      "A puzzle game with switches, moving blocks and a clear goal in every level.",
      language,
    ),
  (language) =>
    translatedText(
      "Make a game where I explore a forest, collect crystals and unlock new paths.",
      language,
    ),
];
export function promptCompletion(
  text,
  caret,
  end = caret,
  language = currentLanguage(),
) {
  if (
    caret !== text.length ||
    end !== caret ||
    text.trim().length < 3 ||
    text.length > 1000 ||
    /(?:^|\s)[/@]\S*$/.test(text) ||
    /[.!?]\s*$/.test(text)
  )
    return "";
  // Follow the language being typed, even if interface language is different.
  const script = /[\u0400-\u04ff]/u.test(text)
    ? "ru"
    : /[a-z]/i.test(text)
      ? "en"
      : language;
  const leading = text.match(/^\s*/)[0].length;
  const prefix = text.slice(leading).toLocaleLowerCase(script);
  const match = examples
    .map((example) => example(script))
    .find((example) => example.toLocaleLowerCase(script).startsWith(prefix));
  return match ? match.slice(text.length - leading) : "";
}

export function completionEligible(text, caret, end = caret) {
  return (
    caret === text.length &&
    end === caret &&
    text.trim().length >= 3 &&
    text.length <= 2000 &&
    !/(?:^|\s)[/@]\S*$/.test(text) &&
    !/[.!?]\s*$/.test(text)
  );
}
export function completionLanguage(text, fallback = currentLanguage()) {
  return /[\u0400-\u04ff]/u.test(text)
    ? "ru"
    : /[a-z]/i.test(text)
      ? "en"
      : fallback;
}
export function validateCompletion(value, prefix) {
  if (typeof value !== "string") return "";
  const suffix = value.startsWith(prefix) ? value.slice(prefix.length) : value;
  return suffix.length <= 240 &&
    !/[\x00-\x1f]/.test(suffix) &&
    !suffix.includes("```")
    ? suffix
    : "";
}
export async function requestPromptCompletion(body, signal, request = fetch) {
  const send = () =>
    request("/v1/ai/complete", {
      method: "POST",
      credentials: "same-origin",
      cache: "no-store",
      signal,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  let response = await send();
  if (response.status === 401) {
    const refresh = await request("/v1/auth/refresh", {
      method: "POST",
      credentials: "same-origin",
      signal,
    });
    if (refresh.ok) response = await send();
  }
  if (
    !response.ok ||
    !response.headers.get("Content-Type")?.includes("text/event-stream")
  )
    throw new Error("Completion unavailable");
  const reader = response.body.getReader(),
    decoder = new TextDecoder();
  let pending = "",
    size = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      pending += decoder.decode(value, { stream: !done });
      size += value?.length || 0;
      if (size > 32000) throw new Error("Completion response too large");
      let end;
      while ((end = pending.indexOf("\n")) >= 0) {
        const line = pending.slice(0, end).trim();
        pending = pending.slice(end + 1);
        if (!line.startsWith("data:")) continue;
        const event = JSON.parse(line.slice(5));
        if (event.type === "error") throw new Error("Completion unavailable");
        if (event.type === "completion")
          return validateCompletion(event.suffix, body.text);
      }
      if (done) return "";
    }
  } finally {
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}
