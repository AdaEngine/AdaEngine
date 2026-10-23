import { t, LocalizedError } from "./localization.js";
import { parseSceneValue, stringifySceneValue } from "./scene-codec.js";
import { unzipSync, zipSync } from "fflate";
import { bytes, decode, encode, base64 } from "./platform.js";
import { defaultChat, validateChat } from "./chat.js";
export const clone = (value) => structuredClone(value);
export const textFile = (path, text) => ({ path, data: encode(text) });
export const file = (snapshot, path) =>
  snapshot.files.find((f) => f.path === path);
export const metadata = (snapshot) =>
  JSON.parse(decode(file(snapshot, ".ada/project.json").data));
export const scenePath = (snapshot) => metadata(snapshot).runtime.entry.scene;
export function scene(snapshot) {
  const value = parseSceneValue(decode(file(snapshot, scenePath(snapshot)).data));
  if (
    value?.format !== "ada.scene" ||
    value.schemaVersion !== 1 ||
    !Array.isArray(value.entities)
  )
    throw new LocalizedError("Unsupported scene format");
  const ids = new Set(value.entities.map((e) => e.id));
  if (ids.size !== value.entities.length)
    throw new LocalizedError("Duplicate entity IDs");
  const parents = new Map(value.entities.map((e) => [e.id, e.parent]));
  for (const e of value.entities) {
    if (
      typeof e.id !== "string" ||
      !e.id ||
      typeof e.name !== "string" ||
      !e.components ||
      Array.isArray(e.components) ||
      typeof e.components !== "object"
    )
      throw new LocalizedError("Invalid scene entity");
    const visited = new Set([e.id]);
    let p = e.parent;
    while (p) {
      if (!ids.has(p) || visited.has(p))
        throw new LocalizedError("Invalid hierarchy");
      visited.add(p);
      p = parents.get(p);
    }
  }
  return value;
}
export function validPath(path) {
  return (
    typeof path === "string" &&
    path.length <= 512 &&
    /^[a-zA-Z0-9_./-]+$/.test(path) &&
    path.split("/").every((p) => p && p !== "." && p !== "..") &&
    (path === ".ada/project.json" ||
      /^(AGENTS|DESIGN|PLAN|PROGRESS|README)\.md$/.test(path) ||
      /^\.ada\/skills\/[a-zA-Z0-9_-]+\/(SKILL\.md|[a-zA-Z0-9_.-]+\.md)$/.test(
        path,
      ) ||
      (path.startsWith("Docs/") && /\.(md|txt)$/.test(path)) ||
      (path.startsWith("Tests/") && path.endsWith(".ada")) ||
      (path.startsWith("Sources/") && path.endsWith(".ada")) ||
      (path.startsWith("Assets/") &&
        /\.(png|jpg|jpeg|wav|ogg|ascn|tilemap|tileset|json|ui|glb|gltf|bin|vox)$/i.test(
          path,
        )))
  );
}
export function validate(snapshot) {
  if (
    snapshot.formatVersion !== 1 ||
    !snapshot.title.trim() ||
    new TextEncoder().encode(snapshot.title).length > 240 ||
    snapshot.files.length > 512 ||
    !snapshot.files.length
  )
    throw new LocalizedError("Invalid project");
  const names = new Set();
  let total = 0;
  for (const f of snapshot.files) {
    const size = bytes(f.data).length;
    if (
      !validPath(f.path) ||
      names.has(f.path.toLowerCase()) ||
      size > 16 * 1024 * 1024 ||
      (f.path.startsWith("Sources/") && size > 512 * 1024)
    )
      throw new LocalizedError("Invalid file: {0}", f.path);
    names.add(f.path.toLowerCase());
    total += size;
  }
  if (total > 64 * 1024 * 1024)
    throw new LocalizedError("The project exceeds 64 MB");
  const meta = metadata(snapshot);
  if (
    meta.build?.system !== "adascript" ||
    meta.runtime?.entry?.view ||
    !file(snapshot, scenePath(snapshot)) ||
    !snapshot.files.some((f) => f.path.startsWith("Sources/"))
  )
    throw new LocalizedError("An AdaScript project with a scene is required");
  if (
    (meta.paths?.sources && meta.paths.sources !== "Sources") ||
    (meta.paths?.assets && meta.paths.assets !== "Assets") ||
    meta.paths?.resourceRoots?.some((p) => p !== "Assets")
  )
    throw new LocalizedError(
      "Use the Sources and Assets folders inside the project",
    );
  if (
    (snapshot.messages?.length ?? 0) > 1000 ||
    new TextEncoder().encode(JSON.stringify(snapshot.messages ?? [])).length >
      4 * 1024 * 1024
  )
    throw new LocalizedError("Chat history exceeds the project limit");
  validateChat(snapshot);
  scene(snapshot);
}
export function portable(snapshot, newIdentity = false) {
  validate(snapshot);
  const copy = clone(snapshot),
    meta = metadata(copy);
  meta.ai = {};
  meta.editor = {};
  meta.run = {};
  if (meta.paths) {
    delete meta.paths.build;
    delete meta.paths.generated;
    meta.paths.run = {};
  }
  if (newIdentity) meta.project.id = crypto.randomUUID();
  file(copy, ".ada/project.json").data = encode(JSON.stringify(meta, null, 2));
  return copy;
}
export function exportZIP(snapshot) {
  return zipSync(
    Object.fromEntries(
      portable(snapshot).files.map((f) => [f.path, bytes(f.data)]),
    ),
    { level: 6 },
  );
}
export function importZIP(data) {
  if (data.byteLength > 65 * 1024 * 1024)
    throw new LocalizedError("The archive exceeds 65 MB");
  const checksums = zipChecksums(data);
  let total = 0;
  const names = new Set();
  const entries = unzipSync(new Uint8Array(data), {
    filter: (f) => {
      if (f.name.endsWith("/")) return false;
      if (
        !validPath(f.name) ||
        names.has(f.name.toLowerCase()) ||
        f.originalSize > 16 * 1024 * 1024 ||
        names.size >= 512
      )
        throw new LocalizedError("Unsafe ZIP path or size");
      names.add(f.name.toLowerCase());
      total += f.originalSize;
      if (total > 64 * 1024 * 1024)
        throw new LocalizedError("The extracted project exceeds 64 MB");
      return true;
    },
  });
  const files = Object.entries(entries).map(([path, value]) => {
    if (crc32(value) !== checksums.get(path))
      throw new LocalizedError("Invalid ZIP archive: {0}", path);
    return { path, data: base64(value) };
  });
  const snapshot = {
    formatVersion: 1,
    title: t("Imported project"),
    files,
    messages: [],
  };
  const meta = metadata(snapshot);
  snapshot.title =
    meta.project?.displayName || meta.project?.name || snapshot.title;
  return portable(snapshot, true);
}
// fflate inflates entries but does not verify their CRC. Check the bounded central
// directory as well, so corrupt packages never become editable cloud projects.
function zipChecksums(input) {
  const data = new Uint8Array(input),
    view = new DataView(data.buffer, data.byteOffset, data.byteLength),
    result = new Map();
  let end = data.length - 22;
  for (; end >= Math.max(0, data.length - 65557); end--)
    if (
      view.getUint32(end, true) === 0x06054b50 &&
      end + 22 + view.getUint16(end + 20, true) === data.length
    )
      break;
  if (end < 0 || view.getUint32(end, true) !== 0x06054b50)
    throw new LocalizedError("Invalid ZIP archive");
  const count = view.getUint16(end + 10, true),
    size = view.getUint32(end + 12, true);
  let offset = view.getUint32(end + 16, true);
  const limit = offset + size;
  if (
    view.getUint16(end + 4, true) ||
    view.getUint16(end + 6, true) ||
    count !== view.getUint16(end + 8, true) ||
    count > 1024 ||
    limit !== end
  )
    throw new LocalizedError("Unsupported ZIP structure");
  for (let i = 0; i < count; i++) {
    if (offset + 46 > limit || view.getUint32(offset, true) !== 0x02014b50)
      throw new LocalizedError("Invalid ZIP archive");
    const flags = view.getUint16(offset + 8, true),
      method = view.getUint16(offset + 10, true),
      length = view.getUint16(offset + 28, true),
      extra = view.getUint16(offset + 30, true),
      comment = view.getUint16(offset + 32, true),
      next = offset + 46 + length + extra + comment;
    if (
      next > limit ||
      flags & 1 ||
      ![0, 8].includes(method) ||
      view.getUint32(offset + 20, true) === 0xffffffff ||
      view.getUint32(offset + 24, true) === 0xffffffff
    )
      throw new LocalizedError("Unsupported ZIP compression");
    const name = new TextDecoder("utf-8", { fatal: true }).decode(
      data.subarray(offset + 46, offset + 46 + length),
    );
    if (!name.endsWith("/")) {
      if (result.has(name)) throw new LocalizedError("Duplicate ZIP path");
      result.set(name, view.getUint32(offset + 16, true));
    }
    offset = next;
  }
  if (offset !== limit) throw new LocalizedError("Invalid ZIP archive");
  return result;
}
function crc32(data) {
  let value = 0xffffffff;
  for (const byte of data) {
    value ^= byte;
    for (let i = 0; i < 8; i++)
      value = (value >>> 1) ^ (value & 1 ? 0xedb88320 : 0);
  }
  return (value ^ 0xffffffff) >>> 0;
}
export const transform = (
  position = [0, 0, 0],
  scale = [1, 1, 1],
  rotation = [0, 0, 0, 1],
) => ({ position, scale, rotation });
const color = (red, green, blue) => ({ red, green, blue, alpha: 1 });
export function template(
  dimension = 3,
  title = dimension === 3 ? t("Valley of winds") : t("New 2D game"),
) {
  const meta = {
    schemaVersion: 1,
    project: {
      id: crypto.randomUUID(),
      name: "StudioGame",
      displayName: title,
    },
    build: { system: "adascript" },
    paths: { sources: "Sources", assets: "Assets", resourceRoots: ["Assets"] },
    runtime: {
      moduleName: "StudioGame",
      entry: { scene: "Assets/Scenes/Main.ascn" },
      plugins: { preset: `game${dimension}d`, settings: {} },
    },
    inputActions: [],
  };
  const entities = [];
  const add = (name, components, parent = null) => {
    const id = crypto.randomUUID();
    entities.push({ id, name, enabled: true, parent, components });
    return id;
  };
  add(t("Camera"), {
    "AdaTransform.Transform":
      dimension === 3
        ? transform([0, 5, -12], [1, 1, 1], [0.17, 0, 0, 0.985444])
        : transform(),
    "AdaRender.Camera": {
      projection: dimension === 3 ? "perspective" : "orthographic",
      isActive: true,
      renderOrder: 0,
      backgroundColor: color(0.09, 0.13, 0.18),
    },
  });
  const mesh = (name, kind, position, scale, tint) =>
    add(name, {
      "AdaTransform.Transform": transform(position, scale),
      "AdaScene.Mesh3DComponent": {
        mesh: kind,
        size: 1,
        color: color(...tint),
        metallic: 0,
        roughness: 0.85,
      },
    });
  if (dimension === 3) {
    add(t("Sun"), {
      "AdaTransform.Transform": transform(
        [0, 6, -4],
        [1, 1, 1],
        [0.25, 0.2, 0, 0.94736],
      ),
      "AdaScene.DirectionalLightComponent": {
        radiance: [1, 0.94, 0.83],
        intensity: 3,
        castShadows: true,
      },
    });
    mesh(t("Meadow"), "Cube", [0, -0.3, 4], [24, 0.5, 28], [0.33, 0.44, 0.25]);
    mesh("Player", "Cube", [0, 0.5, 0], [0.8, 1, 0.8], [0.79, 0.65, 0.44]);
    for (let i = 0; i < 9; i++) {
      const x = i % 2 === 0 ? -4 - i * 0.35 : 4 + i * 0.22,
        z = 1 + Math.floor(i / 2) * 3;
      const parent = mesh(
        t("Pine {0}", i + 1),
        "Cube",
        [x, 1.1, z],
        [0.25, 2.2, 0.25],
        [0.32, 0.24, 0.16],
      );
      mesh(
        t("Foliage {0}", i + 1),
        "Sphere",
        [x, 2.4, z],
        [1.8, 2.7, 1.8],
        [0.17, 0.3 + i * 0.006, 0.19],
      );
    }
    for (let i = 0; i < 5; i++)
      mesh(
        t("Rock {0}", i + 1),
        "Sphere",
        [-3 + i * 1.5, 0.25, 8 + (i % 2) * 1.3],
        [1.7, 0.8, 1.3],
        [0.48, 0.47, 0.42],
      );
  } else
    add("Player", {
      "AdaTransform.Transform": transform(),
      "AdaSprite.Sprite": {
        tintColor: color(0.5, 0.46, 1),
        size: { width: 80, height: 80 },
      },
    });
  const value = {
    format: "ada.scene",
    schemaVersion: 1,
    scene: { id: crypto.randomUUID(), name: title },
    entities,
  };
  return {
    formatVersion: 1,
    title,
    files: [
      textFile(".ada/project.json", JSON.stringify(meta, null, 2)),
      textFile(meta.runtime.entry.scene, JSON.stringify(value, null, 2)),
      textFile(
        "Sources/Game.ada",
        "// Describe your game to the assistant to add gameplay.\n",
      ),
    ],
    messages: [],
  };
}
export class Document {
  constructor(snapshot) {
    snapshot = { ...snapshot, messages: snapshot.messages || [] };
    validate(snapshot);
    this.snapshot = clone(snapshot);
    this.undoStack = [];
    this.redoStack = [];
    this.generation = 0;
    this.contentGeneration = 0;
  }
  edit(update) {
    const next = clone(this.snapshot);
    update(next);
    validate(next);
    if (JSON.stringify(next) === JSON.stringify(this.snapshot)) return;
    this.undoStack.push(this.snapshot);
    if (this.undoStack.length > 50) this.undoStack.shift();
    this.redoStack = [];
    this.snapshot = next;
    this.generation++;
    this.contentGeneration++;
  }
  write(path, text) {
    this.edit((s) => {
      const f = file(s, path);
      if (f) f.data = encode(text);
      else s.files.push(textFile(path, text));
    });
  }
  scene(update) {
    this.edit((s) => {
      const value = scene(s);
      update(value);
      file(s, scenePath(s)).data = encode(stringifySceneValue(value, 2));
    });
  }
  append(value) {
    const next = clone(this.snapshot);
    next.messages.push({ id: crypto.randomUUID(), ...value });
    validate(next);
    this.snapshot = next;
    this.generation++;
  }
  chat(update) {
    const next = clone(this.snapshot);
    let marker = next.messages.find((m) => m.kind === "studio-state");
    if (!marker) {
      marker = {
        id: crypto.randomUUID(),
        role: "assistant",
        content: "",
        kind: "studio-state",
        studio: defaultChat(),
      };
      next.messages.push(marker);
    }
    update(marker.studio);
    validate(next);
    this.snapshot = next;
    this.generation++;
  }
  undo() {
    const previous = this.undoStack.pop();
    if (!previous) return;
    this.redoStack.push(this.snapshot);
    this.snapshot = { ...previous, messages: this.snapshot.messages };
    this.generation++;
    this.contentGeneration++;
  }
  redo() {
    const next = this.redoStack.pop();
    if (!next) return;
    this.undoStack.push(this.snapshot);
    this.snapshot = { ...next, messages: this.snapshot.messages };
    this.generation++;
    this.contentGeneration++;
  }
}
