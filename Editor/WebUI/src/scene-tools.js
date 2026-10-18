import { file, scenePath, scene, clone } from "./documents.js";
export async function sceneRevision(snapshot) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(file(snapshot, scenePath(snapshot)).data),
  );
  return Array.from(new Uint8Array(digest), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
}
const safe = (key) => {
  if (
    typeof key !== "string" ||
    !key ||
    ["__proto__", "constructor", "prototype"].includes(key)
  )
    throw new Error("Invalid scene key");
  return key;
};
export function applyOperations(value, operations) {
  if (
    !Array.isArray(operations) ||
    !operations.length ||
    operations.length > 100
  )
    throw new Error("Use 1–100 scene operations");
  const entity = (id) => {
    const e = value.entities.find((e) => e.id === id);
    if (!e) throw new Error("Entity not found: " + id);
    return e;
  };
  for (const op of operations) {
    const id = op.entityID || op.id;
    switch (op.op) {
      case "createEntity": {
        if (value.entities.some((e) => e.id === id))
          throw new Error("Entity ID already exists");
        value.entities.push({
          id: id || crypto.randomUUID(),
          name: op.name,
          enabled: op.enabled !== false,
          parent: op.parentID || null,
          components: clone(op.components || {}),
        });
        break;
      }
      case "renameEntity":
        entity(id).name = op.name;
        break;
      case "setEntityEnabled":
        if (typeof op.enabled !== "boolean")
          throw new Error("Expected boolean");
        entity(id).enabled = op.enabled;
        break;
      case "reparentEntity":
        entity(id).parent = op.parentID || null;
        break;
      case "deleteEntity": {
        const current = entity(id),
          removed = new Set([id]);
        if (op.children === "reparent") {
          for (const e of value.entities)
            if (e.parent === id) e.parent = current.parent;
        } else {
          for (let before = -1; before !== removed.size; ) {
            before = removed.size;
            for (const e of value.entities)
              if (removed.has(e.parent)) removed.add(e.id);
          }
        }
        value.entities = value.entities.filter((e) => !removed.has(e.id));
        break;
      }
      case "addComponent":
      case "setComponent": {
        const e = entity(id),
          name = safe(op.typeName);
        if (op.op === "addComponent" && Object.hasOwn(e.components, name))
          throw new Error("Component already exists");
        if (
          !op.payload ||
          typeof op.payload !== "object" ||
          Array.isArray(op.payload)
        )
          throw new Error("Expected full component payload");
        e.components[name] = clone(op.payload);
        break;
      }
      case "removeComponent":
        delete entity(id).components[safe(op.typeName)];
        break;
      default:
        throw new Error("Unsupported scene operation: " + op.op);
    }
  }
  if (value.entities.length > 4096)
    throw new Error("Scene entity limit reached");
}
export async function sceneApply(studio, args) {
  const document = studio.document,
    before = file(studio.snapshot, scenePath(studio.snapshot)).data;
  if (args.path && args.path !== scenePath(studio.snapshot))
    throw new Error("Only the active project scene is available");
  if (args.expectedRevision !== (await sceneRevision(studio.snapshot)))
    throw new Error(
      "Scene changed. Read editor.scene.get and refresh the revision.",
    );
  if (
    studio.document !== document ||
    file(studio.snapshot, scenePath(studio.snapshot)).data !== before
  )
    throw new Error("Scene changed while validating revision");
  studio.editScene((s) => applyOperations(s, args.operations));
  return {
    path: scenePath(studio.snapshot),
    revision: await sceneRevision(studio.snapshot),
    message: "Scene updated",
  };
}
export function spawnOperations(snapshot, { entityID, count, spacing }) {
  const value = scene(snapshot),
    source = value.entities.find((e) => e.id === entityID);
  if (
    !source ||
    !Number.isInteger(count) ||
    count < 1 ||
    count > 100 ||
    !Number.isFinite(spacing) ||
    Math.abs(spacing) > 100000
  )
    throw new Error("Choose an existing NPC, count 1–100 and finite spacing");
  const ids = new Set([entityID]);
  for (let before = -1; before !== ids.size; ) {
    before = ids.size;
    for (const e of value.entities) if (ids.has(e.parent)) ids.add(e.id);
  }
  if (ids.size * count > 100)
    throw new Error("Spawn may create at most 100 entities including children");
  const operations = [];
  for (let index = 1; index <= count; index++) {
    const remap = new Map([...ids].map((id) => [id, crypto.randomUUID()]));
    for (const e of value.entities.filter((e) => ids.has(e.id))) {
      const components = clone(e.components);
      if (e.id === entityID) {
        const t = components["AdaTransform.Transform"];
        if (!t?.position) throw new Error("NPC requires a transform");
        t.position[0] += spacing * index;
      }
      operations.push({
        op: "createEntity",
        id: remap.get(e.id),
        name: e.name + " — копия",
        parentID: remap.get(e.parent) || e.parent,
        components,
        enabled: e.enabled,
      });
    }
  }
  return operations;
}
export function colorValue(text) {
  const names = {
    red: "#ff0000",
    green: "#008000",
    blue: "#0000ff",
    white: "#ffffff",
    black: "#000000",
    yellow: "#ffff00",
    transparent: "#00000000",
  };
  text = names[text?.toLowerCase()] || text;
  if (!/^#([a-f\d]{6}|[a-f\d]{8})$/i.test(text || ""))
    throw new Error("Use #RRGGBB or #RRGGBBAA");
  const n = text.slice(1);
  return {
    red: parseInt(n.slice(0, 2), 16) / 255,
    green: parseInt(n.slice(2, 4), 16) / 255,
    blue: parseInt(n.slice(4, 6), 16) / 255,
    alpha: n.length === 8 ? parseInt(n.slice(6), 16) / 255 : 1,
  };
}
export function colorOperations(
  snapshot,
  { entityID, typeName, field: fieldName, color },
) {
  const e = scene(snapshot).entities.find((e) => e.id === entityID),
    payload = clone(e?.components[typeName]);
  safe(fieldName);
  if (
    !payload ||
    !["color", "tintColor", "backgroundColor"].includes(fieldName) ||
    !payload[fieldName] ||
    !("red" in payload[fieldName])
  )
    throw new Error("Choose an existing registered color field");
  payload[fieldName] = colorValue(color);
  return [{ op: "setComponent", entityID, typeName, payload }];
}
