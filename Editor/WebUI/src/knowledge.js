import { LocalizedError } from "./localization.js";
import { decode } from "./platform.js";
import {
  readDocumentation,
  searchDocumentation,
  referenceMatches,
} from "./documentation.js";
import { describeInput } from "./input-actions.js";
import { projectSchemas } from "./project-schemas.js";
let cached;
export async function resources() {
  if (!cached)
    cached = fetch("./agent-resources.json")
      .then((r) => {
        if (!r.ok) throw new LocalizedError("Agent resources unavailable");
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
  if (name === "editor_input_describe")
    return describeInput(data.contract.input, args);
  if (name === "editor_skills_list")
    return {
      skills: (await skills(studio))
        .filter((s) => matches(s.name + " " + s.description, args.query))
        .map(({ content, ...s }) => s),
    };
  if (name === "editor_skills_read") {
    const s = (await skills(studio)).find((s) => s.id === args.id);
    if (!s) throw new LocalizedError("Unknown skill ID");
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
  if (name === "editor_docs_search")
    return searchDocumentation(data.docs, args);
  if (name === "editor_docs_read") {
    if (!args.id) {
      const r = await fetch("./recipes.md");
      if (!r.ok) throw new LocalizedError("Recipes unavailable");
      return r.text();
    }
    const result = readDocumentation(data.docs, args);
    if (!result) throw new LocalizedError("Unknown documentation ID");
    return {
      ...result,
      hostNote:
        "Web Player API 4: @view, native UIComponent and ScriptableComponents HUD bindings are unavailable. A2UI is chat UI. Use browser examples and the supplied tool schemas; native process/LSP/TestWorld recipes do not apply.",
    };
  }
  if (name === "editor_api_describe")
    return {
      source: data.contract.source,
      fingerprint: data.contract.fingerprint,
      types: data.contract.api.types.filter((type) =>
        referenceMatches(
          type.name + " " + type.members.map((member) => member.name).join(" "),
          args.query,
        ),
      ),
      functions: data.contract.api.functions.filter((fn) =>
        referenceMatches(fn.name, args.query),
      ),
      note: "Compiler API signatures are independent of scene loading. Scene components must also appear in editor_components_describe. @view and editor-only context APIs are unavailable in this web host.",
    };
  if (name === "editor_components_describe") {
    let project = { available: false, schemas: [] },
      diagnostic;
    try {
      project = await projectSchemas(studio);
    } catch (error) {
      diagnostic = error.message;
    }
    const components = [
      ...data.contract.components,
      ...project.schemas.filter((schema) => schema.kind === "component"),
    ].filter((component) =>
      referenceMatches(
        component.typeName +
          " " +
          (component.name || "") +
          " " +
          (component.description || "") +
          " " +
          component.fields.map((field) => field.name).join(" "),
        args.query,
      ),
    );
    return {
      components,
      total: components.length,
      runtimeAPI: data.contract.runtimeAPI,
      fingerprint: data.contract.fingerprint,
      source: data.contract.source,
      projectComponentsAvailable: project.available,
      assetReferences:
        "Use @res:// relative to Assets, for example Assets/Sprites/player.png becomes @res://Sprites/player.png. Existing Assets/... project paths and resource-relative paths are normalized to that native wire form. Missing or escaping assets are rejected.",
      ...(diagnostic ? { diagnostic } : {}),
      ...(project.validation ? { projectValidation: project.validation } : {}),
      note: "Built-ins use verified native descriptors. Project components use the production source-schema parser; full compilation/runtime validation is separate. Entity-instance values are never schema defaults. defaultPayloadJSON preserves exact native integers; defaultPayload uses decimal strings for unsafe integer tool values.",
    };
  }
  const examples = data.examples;
  if (name === "editor_examples_list")
    return {
      examples: examples
        .filter((e) =>
          referenceMatches(
            e.id + " " + e.description + " " + (e.tags || []).join(" "),
            args.query,
          ),
        )
        .map(({ files, assets, ...e }) => ({
          ...e,
          files: Object.keys(files),
          assets: Object.keys(assets || {}),
        })),
    };
  if (name === "editor_examples_read") {
    const e = examples.find((e) => e.id === args.id);
    if (!e) throw new LocalizedError("Unknown example ID");
    const { assets, ...example } = e;
    return {
      ...example,
      assets: Object.entries(assets || {}).map(([path, data]) => ({
        path,
        bytes: (data.length * 3) / 4,
      })),
      importTool: "editor_examples_apply",
      note: "Use editor_examples_apply to import text and binary assets atomically. Native HUD is unavailable in this browser profile.",
    };
  }
  throw new LocalizedError("Unknown knowledge tool");
}
