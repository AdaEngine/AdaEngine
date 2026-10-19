import { currentLanguage, translatedText } from "./localization.js";

// Local, editable continuations. No remote generation or agent side turn while typing.
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
