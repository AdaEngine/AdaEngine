import { LocalizedError } from "./localization.js";
import { knowledge } from "./knowledge.js";
import { sceneApply, sceneRevision } from "./scene-tools.js";
import { file, metadata, scenePath, clone } from "./documents.js";
import { decode, encode, bytes } from "./platform.js";
const str = { type: "string" },
  obj = { type: "object" },
  integer = { type: "integer" };
export const tool = (name, description, properties = {}, required = []) => ({
  type: "function",
  function: {
    name,
    description,
    parameters: { type: "object", properties, required },
  },
});
export const extraTools = [
  tool(
    "editor_project_context",
    "Inspect project, runtime capabilities, roots, instructions and current selection.",
  ),
  tool(
    "editor_project_configure",
    "Patch portable runtime/plugins/inputActions project configuration.",
    { runtime: obj, inputActions: { type: "array" } },
  ),
  tool(
    "editor_files_search",
    "Search literal text in project sources and notes.",
    { query: str, path: str },
    ["query"],
  ),
  tool(
    "editor_file_patch",
    "Replace exactly one literal occurrence; fails on ambiguous edits.",
    { path: str, oldText: str, newText: str },
    ["path", "oldText", "newText"],
  ),
  tool("editor_selection_get", "Read selected scene entity and code context."),
  tool(
    "editor_scene_apply",
    "Atomically apply 1–100 scene operations with expectedRevision from editor_scene_get. createEntity, renameEntity, setEntityEnabled, reparentEntity, deleteEntity, addComponent, setComponent, removeComponent.",
    {
      path: str,
      expectedRevision: str,
      operations: { type: "array", items: obj },
    },
    ["expectedRevision", "operations"],
  ),
  ...[
    "skills_list",
    "docs_search",
    "api_describe",
    "components_describe",
    "examples_list",
  ].map((name) =>
    tool(
      "editor_" + name,
      "Search the shared native Studio " +
        name.replaceAll("_", " ") +
        " catalog.",
      { query: str },
    ),
  ),
  ...["skills_read", "examples_read"].map((name) =>
    tool(
      "editor_" + name,
      "Read a complete shared native Studio " +
        name.replaceAll("_", " ") +
        ". Dot tool names in skills map to underscores in this host.",
      { id: str },
      ["id"],
    ),
  ),
  tool(
    "editor_plan_update",
    "Show progress steps in the current conversation.",
    {
      steps: {
        type: "array",
        items: {
          type: "object",
          properties: {
            title: str,
            status: { type: "string", enum: ["pending", "running", "done"] },
          },
          required: ["title", "status"],
        },
      },
    },
    ["steps"],
  ),
  tool(
    "editor_image_read",
    "Inspect a project PNG/JPEG (vision model required).",
    { path: str },
    ["path"],
  ),
  ...["sprite", "audio", "model", "voxel"].map((kind) =>
    tool(
      "editor_" + kind + "_generate",
      "Run the native bounded AdaScript " +
        kind +
        " generator in AdaPlayer. Read its workflow skill for build(builder) syntax. Writes a NEW asset only.",
      { source: str, destination: str },
      ["source", "destination"],
    ),
  ),
  tool(
    "editor_model_inspect",
    "Read static GLB scene, nodes, material names and accessor bounds.",
    { path: str },
    ["path"],
  ),
  tool(
    "editor_audio_inspect",
    "Measure PCM16 WAV duration, RMS, peak and clipped samples.",
    { path: str },
    ["path"],
  ),
];
export const writeTools = new Set([
  "editor_file_write",
  "editor_file_patch",
  "editor_file_delete",
  "editor_scene_set",
  "editor_scene_add",
  "editor_scene_apply",
  "editor_project_configure",
  "editor_sprite_generate",
  "editor_audio_generate",
  "editor_model_generate",
  "editor_voxel_generate",
]);
export const unavailable = [
  "ACP subprocesses",
  "terminal/shell",
  "SwiftPM/Swift projects",
  "SourceKit-LSP",
  "external MCP servers",
  "native Git operations",
  "web search/proxy",
  "native TestWorld simulation",
  "publication",
];
export async function extraTool(s, name, args) {
  if (/^(editor_(skills|docs|api|components|examples)_)/.test(name))
    return knowledge(s, name, args);
  switch (name) {
    case "editor_project_context":
      return {
        title: s.snapshot.title,
        project: metadata(s.snapshot),
        scenePath: scenePath(s.snapshot),
        sceneRevision: await sceneRevision(s.snapshot),
        selection: s.entity,
        capabilities: [
          "AdaScript",
          "2D",
          "basic3D",
          "documentsUndo",
          "skills",
          "documentation",
          "A2UI",
          "assetGenerators",
        ],
        unavailable,
        instructions: s.snapshot.files
          .filter((f) => /^(AGENTS|DESIGN|PLAN|PROGRESS)\.md$/.test(f.path))
          .map((f) => ({ path: f.path, content: decode(f.data) })),
      };
    case "editor_selection_get":
      return { entity: s.entity || null, code: s.latestCodeSelection || "" };
    case "editor_scene_apply":
      return sceneApply(s, args);
    case "editor_file_patch": {
      const f = file(s.snapshot, args.path);
      if (!f) throw new LocalizedError("File not found");
      const text = decode(f.data);
      if (!args.oldText || text.split(args.oldText).length !== 2)
        throw new LocalizedError("Patch must match exactly once");
      s.document.write(
        args.path,
        text.replace(args.oldText, () => args.newText),
      );
      s.changed();
      return { path: args.path };
    }
    case "editor_files_search":
      return s.snapshot.files
        .filter(
          (f) =>
            (!args.path || f.path.startsWith(args.path)) &&
            /\.(ada|md|txt|json|ascn|ui)$/.test(f.path),
        )
        .flatMap((f) =>
          decode(f.data)
            .split("\n")
            .flatMap((line, i) =>
              line.includes(args.query)
                ? [{ path: f.path, line: i + 1, text: line.slice(0, 1000) }]
                : [],
            ),
        )
        .slice(0, 100);
    case "editor_project_configure": {
      s.document.edit((snapshot) => {
        const meta = metadata(snapshot);
        if (args.runtime) {
          if (args.runtime.entry?.view)
            throw new LocalizedError("AdaScript views are unavailable");
          meta.runtime = { ...meta.runtime, ...args.runtime };
        }
        if (args.inputActions) meta.inputActions = args.inputActions;
        file(snapshot, ".ada/project.json").data = encode(
          JSON.stringify(meta, null, 2),
        );
      });
      s.changed();
      return metadata(s.snapshot);
    }
    case "editor_plan_update": {
      if (
        !Array.isArray(args.steps) ||
        args.steps.length > 30 ||
        args.steps.some(
          (step) =>
            typeof step.title !== "string" ||
            step.title.length > 300 ||
            !["pending", "running", "done"].includes(step.status),
        )
      )
        throw new LocalizedError("Invalid progress plan");
      s.updateChat((c) => {
        const session = c.sessions.find(
          (c) => c.id === (s.runningSessionID || s.session.id),
        );
        session.plan = args.steps;
      });
      return { ok: true };
    }
    case "editor_image_read": {
      if (!s.model?.vision)
        throw new LocalizedError("Selected model cannot inspect images");
      const f = file(s.snapshot, args.path);
      if (!f || !/\.(png|jpe?g)$/i.test(f.path) || f.data.length > 500000)
        throw new LocalizedError("Use a project PNG/JPEG below 375 KiB");
      return `data:image/${/\.png$/i.test(f.path) ? "png" : "jpeg"};base64,${f.data}`;
    }
    case "editor_model_inspect": {
      const f = file(s.snapshot, args.path);
      if (!f) throw new LocalizedError("File not found");
      const data = bytes(f.data),
        v = new DataView(data.buffer);
      if (
        data.length < 20 ||
        v.getUint32(0, true) !== 0x46546c67 ||
        v.getUint32(4, true) !== 2 ||
        v.getUint32(8, true) !== data.length ||
        v.getUint32(16, true) !== 0x4e4f534a ||
        v.getUint32(12, true) > data.length - 20
      )
        throw new LocalizedError("Invalid GLB");
      const model = JSON.parse(
        new TextDecoder().decode(data.subarray(20, 20 + v.getUint32(12, true))),
      );
      return {
        scene: model.scene,
        scenes: model.scenes,
        nodes: model.nodes,
        materials: model.materials,
        accessors: model.accessors?.map((a) => ({
          min: a.min,
          max: a.max,
          count: a.count,
          type: a.type,
        })),
        note: "Metadata inspection; validate actual materials and appearance in Play.",
      };
    }
    case "editor_audio_inspect": {
      const f = file(s.snapshot, args.path);
      if (!f) throw new LocalizedError("File not found");
      const data = bytes(f.data),
        v = new DataView(data.buffer);
      let offset = 12,
        format,
        sampleRate,
        channels,
        pcm;
      if (
        data.length < 44 ||
        new TextDecoder().decode(data.subarray(0, 4)) !== "RIFF" ||
        new TextDecoder().decode(data.subarray(8, 12)) !== "WAVE"
      )
        throw new LocalizedError("Expected WAV");
      while (offset + 8 <= data.length) {
        const id = new TextDecoder().decode(data.subarray(offset, offset + 4)),
          length = v.getUint32(offset + 4, true),
          start = offset + 8;
        if (start + length > data.length)
          throw new LocalizedError("Truncated WAV");
        if (id === "fmt ") {
          if (length < 16 || v.getUint16(start + 14, true) !== 16)
            throw new LocalizedError("Expected PCM16");
          format = v.getUint16(start, true);
          channels = v.getUint16(start + 2, true);
          sampleRate = v.getUint32(start + 4, true);
        }
        if (id === "data") pcm = data.subarray(start, start + length);
        offset = start + length + (length % 2);
      }
      if (
        format !== 1 ||
        !channels ||
        !sampleRate ||
        !pcm?.length ||
        pcm.length % 2
      )
        throw new LocalizedError("Expected PCM16 WAV");
      let sum = 0,
        peak = 0,
        clipped = 0;
      const samples = new DataView(pcm.buffer, pcm.byteOffset, pcm.length);
      for (let i = 0; i < pcm.length; i += 2) {
        const value = samples.getInt16(i, true) / 32768;
        peak = Math.max(peak, Math.abs(value));
        sum += value * value;
        if (Math.abs(value) >= 32767 / 32768) clipped++;
      }
      return {
        durationSeconds: pcm.length / 2 / channels / sampleRate,
        sampleRate,
        channels,
        peak,
        rms: Math.sqrt(sum / (pcm.length / 2)),
        clippedSamples: clipped,
      };
    }
    default: {
      const kind = name.match(
        /^editor_(sprite|audio|model|voxel)_generate$/,
      )?.[1];
      if (!kind) throw new LocalizedError("Unavailable tool: {0}", name);
      const ext = { sprite: "png", audio: "wav", model: "glb", voxel: "vox" }[
        kind
      ];
      if (
        typeof args.source !== "string" ||
        new TextEncoder().encode(args.source).length > 65536 ||
        typeof args.destination !== "string" ||
        !args.destination.startsWith("Assets/") ||
        !args.destination.endsWith("." + ext) ||
        file(s.snapshot, args.destination)
      )
        throw new LocalizedError(
          "Choose a new project asset path ending in .{0}",
          ext,
        );
      const doc = s.document;
      if (!s.preview.ready) await s.syncViewport();
      const result = await s.preview.message("agent-tool", {
        name,
        source: args.source,
      });
      if (s.document !== doc) throw new LocalizedError("Project changed");
      s.document.edit((snapshot) => {
        if (file(snapshot, args.destination))
          throw new LocalizedError("Destination exists");
        snapshot.files.push({ path: args.destination, data: result.data });
      });
      s.changed();
      return {
        path: args.destination,
        bytes: result.bytes,
        assetReference: args.destination.replace(/^Assets\//, ""),
        requiresRestart: true,
      };
    }
  }
}
