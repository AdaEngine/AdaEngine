import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  documentationSections,
  readDocumentation,
  searchDocumentation,
} from "../src/documentation.js";
import { knowledge } from "../src/knowledge.js";

const docs = JSON.parse(
  await readFile(
    new URL(
      "../../Sources/AdaEditor/Assets/Documentation/catalog.json",
      import.meta.url,
    ),
  ),
);
const block = (text, kind = "text", level = 2) => ({ kind, text, level });
const article = (id, blocks) => ({ id, title: id, source: `${id}.md`, blocks });

test("real authoring queries rank input sections ahead of A2UI forms in both languages", () => {
  for (const query of [
    "keyboard bindings",
    "как привязать клавишу",
    "input actions",
  ]) {
    const first = searchDocumentation(docs, { query }).articles[0];
    assert.ok(
      ["AdaScriptECS", "AdaScriptGameplayRecipes"].includes(first.articleID),
      `${query}: ${first.id}`,
    );
    assert.match(first.heading, /[Ii]nput/);
    assert.match(first.excerpt, /Input|input|binding|action/i);
    assert.ok(first.excerpt.length > first.heading.length + 30);
  }
  const first = searchDocumentation(docs, { query: "isActionJustPressed" })
    .articles[0];
  assert.match(
    readDocumentation(docs, { id: first.id }).content,
    /isActionJustPressed/,
  );
  assert.match(first.excerpt, /isActionJustPressed/);
  assert.equal(searchDocumentation(docs, { query: "KeyCode" }).total, 0);
  assert.equal(
    searchDocumentation(docs, { query: "AdaScript gameplay recipes" })
      .articles[0].id,
    "AdaScriptGameplayRecipes#overview",
  );
});

test("search returns the matching section and excerpt, and its ID is readable through production dispatch", async () => {
  globalThis.fetch = async () => Response.json({ docs });
  const found = await knowledge({}, "editor_docs_search", {
    query: "keyboard bindings",
    limit: 2,
  });
  assert.equal(found.articles.length, 2);
  const result = found.articles[0];
  assert.ok(result.id.includes("#"));
  const read = await knowledge({}, "editor_docs_read", { id: result.id });
  assert.equal(read.articleID, result.articleID);
  assert.equal(read.heading, result.heading);
  assert.ok(read.content.includes(result.excerpt.replace(/^…|…$/g, "")));
});

test("headings get stable paths, duplicate headings are distinct and preambles remain available", () => {
  const original = article("Guide", [
    block("Introduction"),
    block("Input", "heading"),
    block("Space"),
    block("Bindings", "heading", 3),
    block("Keyboard"),
    block("Input", "heading"),
    block("Touch"),
  ]);
  const sections = documentationSections([original]);
  assert.deepEqual(
    sections.map((s) => s.id),
    ["Guide#overview", "Guide#input", "Guide#input/bindings", "Guide#input-2"],
  );
  const inserted = structuredClone(original);
  inserted.blocks.splice(1, 0, block("Assets", "heading"), block("Files"));
  const after = documentationSections([inserted]);
  for (const section of sections)
    assert.ok(after.some((s) => s.id === section.id));
  assert.equal(
    readDocumentation([original], { id: "Guide#input/bindings" }).content,
    "Bindings\n\nKeyboard",
  );
});

test("unknown symbols return no unrelated fallback and matching is token-based rather than substring-based", () => {
  const corpus = [
    article("Configuration", [block("Formatting and transforms")]),
  ];
  for (const query of [
    "unknown_symbol",
    "form",
    "transform",
    "неизвестный_тип_без_совпадений",
  ]) {
    const found = searchDocumentation(corpus, { query });
    assert.equal(found.total, 0, query);
    assert.deepEqual(found.articles, []);
    assert.ok(found.hint);
  }
});

test("punctuation and quoted API identifiers reach their matching section without rewriting the source", () => {
  const corpus = [
    article("API", [
      block("Other", "heading"),
      block("A2UI input forms"),
      block("Input", "heading"),
      block('input.isActionJustPressed("Jump");', "code"),
    ]),
  ];
  const found = searchDocumentation(corpus, {
    query: '"Input.isActionJustPressed()"',
  });
  assert.equal(found.articles[0].id, "API#input");
  assert.match(
    found.articles[0].excerpt,
    /input\.isActionJustPressed\("Jump"\);/,
  );
});

test("long matching paragraphs yield a bounded excerpt near the term rather than the article opening", () => {
  const corpus = [
    article("Large", [
      block(
        "Unrelated beginning. ".repeat(200) +
          "UniqueIdentifier is the answer. " +
          "More text. ".repeat(200),
      ),
    ]),
  ];
  const found = searchDocumentation(corpus, { query: "UniqueIdentifier" });
  assert.match(found.articles[0].excerpt, /UniqueIdentifier is the answer/);
  assert.ok(found.articles[0].excerpt.length <= 1202);
});

test("legacy article IDs, bounded pagination, empty queries and explicit platform filtering work", () => {
  const corpus = [
    article("Legacy", [block("a".repeat(18000))]),
    { ...article("Native", [block("native-only")]), platforms: ["native"] },
  ];
  const first = readDocumentation(corpus, { id: "Legacy", limit: 500 });
  assert.equal(first.content.length, 500);
  assert.equal(first.nextOffset, 500);
  assert.equal(
    readDocumentation(corpus, {
      id: "Legacy",
      offset: first.nextOffset,
      limit: 48000,
    }).content.length,
    17500,
  );
  assert.equal(readDocumentation(corpus, { id: "missing" }), undefined);
  assert.equal(
    searchDocumentation(corpus, { query: "", platform: "web" }).total,
    1,
  );
  assert.equal(
    searchDocumentation(corpus, { query: "", limit: -1 }).articles.length,
    1,
  );
});

test("generated browser contracts answer the acceptance queries instead of headings or unsupported native HUD recipes", async () => {
  const { webAuthoringDocs } = await import(
    "../scripts/web-authoring-docs.mjs"
  );
  const contract = JSON.parse(
    await readFile(new URL("../assets/agent-contract.json", import.meta.url)),
  );
  const corpus = [...webAuthoringDocs(contract), ...docs];
  for (const [query, articleID, useful] of [
    ["KeyCode space JSON", "WebInputActions", /literal space/],
    ["как привязать пробел для прыжка", "WebInputActions", /Jump|space/],
    ["keyboard bindings", "WebInputActions", /bindings/],
    ["gamepad axis dead zone", "WebInputActions", /deadZone/],
    [
      "нажатие мыши и касание экрана",
      "WebInputActions",
      /mouseButton|Mouse and touch/,
    ],
    [
      "create entity with custom component",
      "WebSceneComponents",
      /component|editor_project_apply/,
    ],
    [
      "добавить компонент к сущности",
      "WebSceneComponents",
      /component|editor_project_apply/,
    ],
    ["Mesh3DComponent size", "WebSceneComponents", /100000/],
    ["UIComponent", "WebSceneComponents", /not supported|unavailable/],
    ["flappy", "WebExamples", /side-scroller-3d/],
  ]) {
    const first = searchDocumentation(corpus, { query }).articles[0];
    assert.equal(first.articleID, articleID, query + ": " + first.id);
    assert.match(first.excerpt, useful, query);
    assert.ok(first.excerpt.length > first.heading.length + 20, query);
    assert.ok(
      readDocumentation(corpus, { id: first.id }).content.includes(
        first.excerpt.replace(/^…|…$/g, ""),
      ),
    );
  }
  assert.equal(
    searchDocumentation(corpus, { query: "неизвестный_тип_без_совпадений" })
      .total,
    0,
  );
});
