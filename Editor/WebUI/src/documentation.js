import vocabulary from "./documentation-terms.json" with { type: "json" };

const normalize = (value) => String(value).normalize("NFKC").toLowerCase();
const words = (value) =>
  normalize(value.replace(/([a-z\d])([A-Z])/g, "$1 $2")).match(
    /[\p{L}\p{N}_]+/gu,
  ) || [];
const ignored = new Set(vocabulary.ignore);
const indexes = new WeakMap();
const aliases = new Map(
  vocabulary.groups.flatMap((group) => group.map((word) => [word, group[0]])),
);
const prefixes = [...aliases].filter(([word]) => /[\u0400-\u04ff]/u.test(word));

function concept(word) {
  return (
    aliases.get(word) ||
    (/[\u0400-\u04ff]/u.test(word)
      ? prefixes.find(([prefix]) => word.startsWith(prefix))?.[1]
      : undefined) ||
    word
  );
}

const tokens = (value) => new Set(words(value).map(concept));
const slug = (value) => words(value).join("-") || "overview";

export function referenceMatches(text, query = "") {
  const available = tokens(text);
  return words(String(query).slice(0, 1000))
    .filter((word) => !ignored.has(word))
    .every((word) => available.has(concept(word)));
}

/** Heading paths remain stable when unrelated sections are inserted. */
export function documentationSections(docs) {
  const sections = [];
  for (const article of docs) {
    let section;
    const headings = [],
      used = new Map();
    for (const block of article.blocks) {
      if (block.kind === "heading" || !section) {
        if (block.kind === "heading") {
          while (headings.at(-1)?.level >= block.level) headings.pop();
          headings.push({ title: block.text, level: block.level });
        }
        const headingPath = headings.map((h) => h.title);
        const path = headingPath.map(slug).join("/") || "overview";
        const occurrence = (used.get(path) || 0) + 1;
        used.set(path, occurrence);
        section = {
          id: `${article.id}#${path}${occurrence > 1 ? "-" + occurrence : ""}`,
          articleID: article.id,
          title: article.title,
          heading: headingPath.at(-1) || article.title,
          headingPath,
          source: article.source,
          ...(article.platforms ? { platforms: article.platforms } : {}),
          blocks: [],
        };
        sections.push(section);
      }
      section.blocks.push(block);
    }
  }
  return sections;
}

function index(docs) {
  if (!indexes.has(docs))
    indexes.set(
      docs,
      documentationSections(docs).map((section) => {
        const content = section.blocks.map((b) => b.text).join("\n\n");
        return {
          ...section,
          content,
          titleTokens: tokens(section.title),
          headingTokens: tokens(section.headingPath.join(" ")),
          bodyTokens: tokens(content),
          identifiers: new Set(
            normalize(section.title + " " + content).match(/[\p{L}\p{N}_]+/gu),
          ),
        };
      }),
    );
  return indexes.get(docs);
}

function excerpt(section, query, limit = 1200) {
  // A matching code block or paragraph is more useful than an article preamble.
  const ranked = section.blocks
    .map((block, order) => ({
      text: block.text,
      order,
      score: [...tokens(block.text)].filter((word) => query.has(word)).length,
      heading: block.kind === "heading",
    }))
    .filter(
      (block) =>
        !block.heading || section.blocks.every((b) => b.kind === "heading"),
    )
    .sort(
      (a, b) =>
        b.score - a.score ||
        Number(a.heading) - Number(b.heading) ||
        a.order - b.order,
    );
  const best = ranked[0];
  const before = section.blocks
    .slice(Math.max(0, best.order - 1), best.order)
    .map((b) => b.text)
    .join("\n\n");
  const text = (before ? before.slice(-200) + "\n\n" : "") + best.text;
  // Long paragraphs may mention the symbol late; center the excerpt on it.
  const position = words(text).find((word) => query.has(concept(word)));
  const at = position ? normalize(text).indexOf(position) : 0;
  const start = Math.max(0, at - 160);
  return (
    (start ? "…" : "") +
    text.slice(start, start + limit) +
    (text.length > start + limit ? "…" : "")
  );
}

/** Weighted section retrieval; never substitutes unrelated content for no match. */
export function searchDocumentation(
  docs,
  { query = "", limit = 12, platform } = {},
) {
  const requested = words(String(query).slice(0, 1000)).filter(
    (w) => !ignored.has(w),
  );
  const queryTokens = new Set(requested.map(concept));
  const symbols = (
    String(query)
      .slice(0, 1000)
      .match(/[\p{L}_][\p{L}\p{N}_.]*/gu) || []
  )
    .filter((word) => /[a-z][A-Z]|_/.test(word))
    .flatMap((word) => normalize(word).split("."));
  const sections = index(docs).filter(
    (s) => !platform || !s.platforms || s.platforms.includes(platform),
  );
  const frequency = new Map(
    [...queryTokens].map((word) => [
      word,
      sections.filter(
        (s) =>
          s.bodyTokens.has(word) ||
          s.titleTokens.has(word) ||
          s.headingTokens.has(word),
      ).length,
    ]),
  );
  const ranked = sections
    .map((section) => {
      let score = 0,
        matched = 0;
      for (const word of queryTokens) {
        const weight =
          (section.headingTokens.has(word) ? 6 : 0) +
          (section.titleTokens.has(word) ? 2 : 0) +
          (section.bodyTokens.has(word) ? 1 : 0);
        if (weight) {
          matched++;
          score +=
            weight *
            (1 + Math.log(1 + sections.length / (1 + frequency.get(word))));
        }
      }
      if (queryTokens.size) score *= (matched / queryTokens.size) ** 2;
      if (
        normalize(query).trim() === normalize(section.title).trim() &&
        !section.headingPath.length
      )
        score += 1000;
      for (const exact of requested)
        if (section.identifiers.has(exact)) score += score ? 0.2 : 0;
      return { section, score, matched };
    })
    .filter(
      ({ section, score, matched }) =>
        (!queryTokens.size ||
          (score > 0 && matched / queryTokens.size >= 0.5)) &&
        symbols.every((symbol) => section.identifiers.has(symbol)),
    )
    .sort(
      (a, b) => b.score - a.score || a.section.id.localeCompare(b.section.id),
    );
  const count = Math.min(20, Math.max(1, Number.isInteger(limit) ? limit : 12));
  return {
    total: ranked.length,
    articles: ranked.slice(0, count).map(({ section }) => ({
      id: section.id,
      articleID: section.articleID,
      title: section.title,
      heading: section.heading,
      headingPath: section.headingPath,
      source: section.source,
      ...(section.platforms ? { platforms: section.platforms } : {}),
      excerpt: excerpt(section, queryTokens),
    })),
    ...(!ranked.length
      ? {
          hint: "No matching section. Search an exact API/type name or discover components, input bindings and examples with the dedicated tools.",
        }
      : {}),
  };
}

export function readDocumentation(docs, { id, offset = 0, limit = 16000 }) {
  const section = index(docs).find((section) => section.id === id);
  const article = docs.find((article) => article.id === id);
  if (!section && !article) return;
  const text =
    section?.content || article.blocks.map((b) => b.text).join("\n\n");
  const start =
    Number.isInteger(offset) && offset >= 0 ? Math.min(offset, text.length) : 0;
  const length = Math.min(
    48000,
    Math.max(1, Number.isInteger(limit) ? limit : 16000),
  );
  return {
    id,
    articleID: section?.articleID || article.id,
    source: section?.source || article.source,
    ...(section
      ? { heading: section.heading, headingPath: section.headingPath }
      : {}),
    content: text.slice(start, start + length),
    ...(start + length < text.length ? { nextOffset: start + length } : {}),
  };
}
