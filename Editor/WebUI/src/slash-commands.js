import { LocalizedError } from "./localization.js";
/** Command completion only applies to a slash token at a collapsed text caret. */
export function slashQuery(text, caret, end = caret) {
  if (
    !Number.isInteger(caret) ||
    caret < 0 ||
    caret > text.length ||
    end !== caret
  )
    return null;
  const match = text.slice(0, caret).match(/(?:^|\s)\/([\p{L}0-9-]*)$/iu);
  if (!match) return null;
  return {
    query: match[1].toLowerCase(),
    start: caret - match[1].length - 1,
    end: caret + (text.slice(caret).match(/^[\p{L}0-9-]*/iu)?.[0].length || 0),
  };
}

export function completeSlash(text, token, id) {
  if (!/^[a-z0-9-]+$/i.test(id)) throw new LocalizedError("Invalid command ID");
  const before = text.slice(0, token.start),
    after = text.slice(token.end);
  const command = `/${id}`;
  const gap = /^\s/.test(after) ? "" : " ";
  return {
    text: before + command + gap + after,
    caret: before.length + command.length + (gap.length || 1),
  };
}

export function commandMatches(catalog, query) {
  const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
  const rank = (skill) =>
    skill.id === query
      ? 0
      : skill.id.startsWith(query)
        ? 1
        : skill.id.includes(query)
          ? 2
          : 3;
  return catalog
    .filter((skill) =>
      terms.every((term) =>
        `${skill.id} ${skill.name || ""} ${skill.description || ""}`
          .toLowerCase()
          .includes(term),
      ),
    )
    .sort((a, b) => rank(a) - rank(b) || a.id.localeCompare(b.id));
}

export function mentionedSkills(text = "") {
  return [
    ...new Set(
      Array.from(
        text.matchAll(/(?:^|\s)\/([a-z0-9-]+)(?=\s|$|[.,!?])/gi),
        (match) => match[1].toLowerCase(),
      ),
    ),
  ];
}
