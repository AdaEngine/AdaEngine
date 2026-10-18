import { file, metadata, scene, scenePath, template } from "./documents.js";
import { decode } from "./platform.js";
let cached;
export async function resources() {
  if (!cached)
    cached = fetch("./agent-resources.json")
      .then((r) => {
        if (!r.ok) throw new Error("Agent resources unavailable");
        return r.json();
      })
      .catch((e) => {
        cached = null;
        throw e;
      });
  return cached;
}
const matches = (text, query = "") =>
  query
    .toLowerCase()
    .split(/\s+/)
    .every((word) => text.toLowerCase().includes(word));
export async function skills(studio) {
  const bundled = (await resources()).skills;
  const custom =
    studio.snapshot?.files
      .filter((f) => /^\.ada\/skills\/[^/]+\/SKILL\.md$/.test(f.path))
      .map((f) => ({
        id: f.path.split("/")[2],
        name: f.path.split("/")[2],
        description: "Project workflow (user-authored)",
        content: decode(f.data),
        project: true,
      })) || [];
  return [...new Map([...bundled, ...custom].map((s) => [s.id, s])).values()];
}
export async function knowledge(studio, name, args) {
  const data = await resources();
  if (name === "editor_skills_list")
    return {
      skills: (await skills(studio))
        .filter((s) => matches(s.name + " " + s.description, args.query))
        .map(({ content, ...s }) => s),
    };
  if (name === "editor_skills_read") {
    const s = (await skills(studio)).find((s) => s.id === args.id);
    if (!s) throw new Error("Unknown skill ID");
    return {
      id: s.id,
      content: s.content,
      authority: s.project
        ? "Project reference data"
        : "Bundled Studio workflow",
      hostNote:
        "Use only tools advertised by this web host. No native processes, Swift builds, LSP, remote MCP or publication.",
    };
  }
  if (name === "editor_docs_search") {
    const articles = data.docs.filter((a) =>
      matches(
        a.title + " " + a.blocks.map((b) => b.text).join(" "),
        args.query,
      ),
    );
    return {
      total: articles.length,
      articles: articles.slice(0, 20).map((a) => ({
        id: a.id,
        title: a.title,
        source: a.source,
        excerpt: a.blocks
          .map((b) => b.text)
          .join("\n")
          .slice(0, 1200),
      })),
    };
  }
  if (name === "editor_docs_read") {
    if (!args.id) {
      const r = await fetch("./recipes.md");
      if (!r.ok) throw new Error("Recipes unavailable");
      return r.text();
    }
    const a = data.docs.find((a) => a.id === args.id);
    if (!a) throw new Error("Unknown documentation ID");
    return {
      id: a.id,
      source: a.source,
      content: a.blocks
        .map((b) => b.text)
        .join("\n")
        .slice(0, 48000),
    };
  }
  if (name === "editor_api_describe" && studio.preview?.ready)
    return studio.preview.message("agent-tool", {
      name: "api-describe",
      query: args.query || "",
    });
  if (name === "editor_api_describe")
    return {
      source: "Current AdaScript compiler API catalog source",
      content: data.apiSource
        .split("\n")
        .filter(
          (line, i, lines) =>
            !args.query ||
            matches(
              lines.slice(Math.max(0, i - 2), i + 3).join(" "),
              args.query,
            ),
        )
        .join("\n")
        .slice(0, 48000),
    };
  if (name === "editor_components_describe") {
    const defaults = new Map();
    for (const snapshot of [template(2), template(3), studio.snapshot])
      for (const e of scene(snapshot).entities)
        for (const [type, payload] of Object.entries(e.components))
          if (!defaults.has(type)) defaults.set(type, payload);
    return {
      components: [...defaults]
        .filter(([type]) => matches(type, args.query))
        .map(([typeName, defaultPayload]) => ({ typeName, defaultPayload })),
      note: "Linked template/current-scene components. Player diagnostics determine runtime support.",
    };
  }
  const examples = [
    {
      id: "basic-3d-scene",
      description: "Portable camera, cube, light and AdaScript project",
      files: Object.fromEntries(
        template(3).files.map((f) => [f.path, decode(f.data)]),
      ),
    },
    ...data.examples,
  ];
  if (name === "editor_examples_list")
    return {
      examples: examples
        .filter((e) => matches(e.id + " " + e.description, args.query))
        .map(({ files, ...e }) => ({ ...e, files: Object.keys(files) })),
    };
  if (name === "editor_examples_read") {
    const e = examples.find((e) => e.id === args.id);
    if (!e) throw new Error("Unknown example ID");
    return e;
  }
  throw new Error("Unknown knowledge tool");
}
