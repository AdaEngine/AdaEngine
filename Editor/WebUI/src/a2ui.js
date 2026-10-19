import { LocalizedError } from "./localization.js";
export const catalogID = "https://adaengine.org/a2ui/catalogs/forms/v1";
const unsafe = (s) => ["__proto__", "constructor", "prototype"].includes(s);
const object = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
const bounded = (text, max = 4096) =>
  typeof text === "string" && text.length > 0 && text.length <= max;
export function tokens(path) {
  if (path === undefined || path === "/") return [];
  if (!bounded(path) || !path.startsWith("/") || /~(?![01])/g.test(path))
    throw new LocalizedError("Expected absolute JSON Pointer");
  const parts = path
    .slice(1)
    .split("/")
    .map((p) => p.replaceAll("~1", "/").replaceAll("~0", "~"));
  if (parts.length > 64 || parts.some(unsafe))
    throw new LocalizedError("Unsafe data binding");
  return parts;
}
export function get(model, path) {
  let current = model;
  for (const p of tokens(path)) {
    if (
      current === null ||
      typeof current !== "object" ||
      !Object.hasOwn(current, p)
    )
      return undefined;
    current = current[p];
  }
  return current;
}
export function set(model, path, value, remove = false) {
  const parts = tokens(path);
  if (!parts.length) {
    if (remove) throw new LocalizedError("Cannot delete root");
    return structuredClone(value);
  }
  let parent = model;
  for (const [i, p] of parts.entries()) {
    if (!object(parent) && !Array.isArray(parent))
      throw new LocalizedError("Binding parent is not a container");
    if (
      Array.isArray(parent) &&
      (!/^(0|[1-9]\d*)$/.test(p) || Number(p) > parent.length)
    )
      throw new LocalizedError("Invalid array index");
    if (i === parts.length - 1) {
      if (remove) {
        if (Array.isArray(parent)) parent[p] = null;
        else delete parent[p];
      } else parent[p] = structuredClone(value);
    } else {
      if (!Object.hasOwn(parent, p)) parent[p] = {};
      parent = parent[p];
    }
  }
  return model;
}
export function resolve(value, data, depth = 0) {
  if (depth > 64) throw new LocalizedError("Action nesting exceeds limit");
  if (
    object(value) &&
    Object.keys(value).length === 1 &&
    typeof value.path === "string"
  )
    return get(data, value.path) ?? null;
  if (Array.isArray(value))
    return value.map((v) => resolve(v, data, depth + 1));
  if (object(value))
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => {
        if (unsafe(k)) throw new LocalizedError("Unsafe context key");
        return [k, resolve(v, data, depth + 1)];
      }),
    );
  return value;
}
const properties = {
  Text: ["text"],
  Column: ["children", "spacing"],
  Row: ["children", "spacing"],
  Button: ["text", "action", "checks"],
  TextField: ["text", "placeholder", "checks"],
  Toggle: ["label", "value", "checks"],
  ChoicePicker: ["label", "value", "options", "checks"],
  Slider: ["value", "min", "max", "step", "checks"],
};
const required = {
  Text: ["text"],
  Column: ["children"],
  Row: ["children"],
  Button: ["text", "action"],
  TextField: ["text"],
  Toggle: ["label", "value"],
  ChoicePicker: ["value", "options"],
  Slider: ["value", "min", "max"],
};
function binding(v) {
  if (!object(v) || Object.keys(v).length !== 1 || typeof v.path !== "string")
    throw new LocalizedError("Input requires a writable binding");
  tokens(v.path);
}
function text(v, data) {
  if (typeof v === "string") {
    if (v.length > 65536) throw new LocalizedError("Text exceeds limit");
    return;
  }
  binding(v);
  const current = get(data, v.path);
  if (current !== undefined && typeof current !== "string")
    throw new LocalizedError("Text binding requires a string");
}
export function validateSurface(s) {
  if (!object(s.data) || JSON.stringify(s.data).length > 1024 * 1024)
    throw new LocalizedError("Invalid or oversized data model");
  const bindingTypes = new Map();
  const register = (v, type) => {
    if (object(v) && typeof v.path === "string") {
      const key = JSON.stringify(tokens(v.path)),
        previous = bindingTypes.get(key);
      if (previous && type !== previous)
        throw new LocalizedError("Incompatible binding types");
      bindingTypes.set(key, type);
    }
  };
  const all = Object.values(s.components);
  if (all.length > 1024) throw new LocalizedError("Too many components");
  for (const c of all) {
    if (
      !bounded(c.id, 256) ||
      unsafe(c.id) ||
      !Object.hasOwn(properties, c.component)
    )
      throw new LocalizedError("Unsupported component");
    if (
      Object.keys(c).some(
        (k) => !["id", "component", ...properties[c.component]].includes(k),
      ) ||
      required[c.component].some((k) => !Object.hasOwn(c, k))
    )
      throw new LocalizedError("Unsupported or missing component property");
    if (["Text", "Button", "TextField"].includes(c.component)) {
      text(c.text, s.data);
      register(c.text, "string");
    }
    if (c.component === "TextField") binding(c.text);
    if (c.placeholder !== undefined && typeof c.placeholder !== "string")
      throw new LocalizedError("Invalid placeholder");
    if (c.label !== undefined) {
      text(c.label, s.data);
      register(c.label, "string");
    }
    if (["Toggle", "ChoicePicker", "Slider"].includes(c.component)) {
      binding(c.value);
      const current = get(s.data, c.value.path),
        type = { Toggle: "boolean", ChoicePicker: "string", Slider: "number" }[
          c.component
        ];
      register(c.value, type);
      if (
        current !== undefined &&
        (typeof current !== type ||
          (type === "number" && !Number.isFinite(current)))
      )
        throw new LocalizedError("Wrong input binding type");
    }
    if (
      c.component === "ChoicePicker" &&
      (!Array.isArray(c.options) ||
        !c.options.length ||
        c.options.length > 64 ||
        c.options.some(
          (o) =>
            !object(o) ||
            typeof o.label !== "string" ||
            typeof o.value !== "string" ||
            Object.keys(o).some((k) => !["label", "value"].includes(k)),
        ) ||
        new Set(c.options.map((o) => o.value)).size !== c.options.length)
    )
      throw new LocalizedError("Invalid choices");
    if (
      c.component === "Slider" &&
      (!Number.isFinite(c.min) ||
        !Number.isFinite(c.max) ||
        c.min >= c.max ||
        (c.step !== undefined && (!Number.isFinite(c.step) || c.step <= 0)))
    )
      throw new LocalizedError("Invalid slider range");
    if (
      c.children !== undefined &&
      (!Array.isArray(c.children) ||
        c.children.length > 1024 ||
        new Set(c.children).size !== c.children.length ||
        c.children.some((id) => !bounded(id, 256)))
    )
      throw new LocalizedError("Invalid children");
    if (
      c.spacing !== undefined &&
      (!Number.isFinite(c.spacing) || c.spacing < 0 || c.spacing > 128)
    )
      throw new LocalizedError("Invalid spacing");
    if (c.component === "Button") {
      const event = c.action?.event;
      if (
        !object(c.action) ||
        Object.keys(c.action).length !== 1 ||
        !object(event) ||
        !bounded(event.name, 256) ||
        Object.keys(event).some((k) => !["name", "context"].includes(k)) ||
        (event.context !== undefined && !object(event.context))
      )
        throw new LocalizedError("Only server event actions are supported");
      resolve(event.context || {}, s.data);
    }
    if (c.checks !== undefined) {
      if (!Array.isArray(c.checks) || c.checks.length > 32)
        throw new LocalizedError("Invalid form checks");
      for (const check of c.checks) {
        const cond = check.condition,
          args = cond?.args;
        if (
          !bounded(check.message, 1024) ||
          !object(cond) ||
          !object(args) ||
          !["required", "range"].includes(cond.call) ||
          Object.keys(cond).some((k) => !["call", "args"].includes(k)) ||
          Object.keys(check).some((k) => !["condition", "message"].includes(k))
        )
          throw new LocalizedError("Unsupported check");
        if (
          !Object.hasOwn(args, "value") ||
          Object.keys(args).some(
            (k) =>
              !(
                cond.call === "range" ? ["value", "min", "max"] : ["value"]
              ).includes(k),
          )
        )
          throw new LocalizedError("Invalid check arguments");
        if (object(args.value)) binding(args.value);
        if (cond.call === "range") register(args.value, "number");
        if (
          cond.call === "range" &&
          (!Number.isFinite(args.min) ||
            !Number.isFinite(args.max) ||
            args.min > args.max)
        )
          throw new LocalizedError("Invalid check range");
      }
    }
  }
  const visit = (id, stack = new Set(), depth = 0, mounted = null) => {
    if (depth > 64 || stack.has(id) || mounted?.has(id))
      throw new LocalizedError("Cyclic or repeated component mount");
    mounted?.add(id);
    const c = s.components[id];
    if (!c) return;
    for (const child of c.children || [])
      visit(child, new Set([...stack, id]), depth + 1, mounted);
  };
  for (const c of all) visit(c.id);
  visit("root", new Set(), 0, new Set());
}
export function failures(c, data) {
  return (c.checks || [])
    .filter((check) => {
      const cond = check.condition,
        v = resolve(cond.args.value, data);
      return cond.call === "required"
        ? !(typeof v === "string"
            ? v.trim()
            : typeof v === "number"
              ? Number.isFinite(v)
              : Array.isArray(v)
                ? v.length
                : v === true)
        : typeof v !== "number" ||
            !Number.isFinite(v) ||
            v < cond.args.min ||
            v > cond.args.max;
    })
    .map((c) => c.message);
}
export function receive(records, envelope, owner) {
  if (
    JSON.stringify(envelope).length > 1024 * 1024 ||
    envelope.version !== "v0.9.1"
  )
    throw new LocalizedError("Unsupported A2UI envelope");
  const kinds = [
    "createSurface",
    "updateComponents",
    "updateDataModel",
    "deleteSurface",
  ].filter((k) => Object.hasOwn(envelope, k));
  if (kinds.length !== 1 || Object.keys(envelope).length !== 2)
    throw new LocalizedError("One A2UI message per envelope required");
  const kind = kinds[0],
    v = envelope[kind];
  if (!object(v) || !bounded(v.surfaceId, 256) || unsafe(v.surfaceId))
    throw new LocalizedError("Invalid surface ID");
  const index = records.findIndex(
      (s) =>
        s.id === v.surfaceId &&
        s.sessionID === owner.sessionID &&
        s.owner === owner.owner,
    ),
    old = records[index];
  if (old && old.owner !== owner.owner)
    throw new LocalizedError("Surface belongs to another agent");
  let next;
  if (kind === "createSurface") {
    if (
      old ||
      records.filter(
        (s) => s.sessionID === owner.sessionID && s.owner === owner.owner,
      ).length >= 16 ||
      v.catalogId !== catalogID ||
      (v.theme && Object.keys(v.theme).length) ||
      Object.keys(v).some(
        (k) =>
          !["surfaceId", "catalogId", "sendDataModel", "theme"].includes(k),
      ) ||
      (v.sendDataModel !== undefined && typeof v.sendDataModel !== "boolean")
    )
      throw new LocalizedError("Unsupported surface or catalog");
    next = {
      id: v.surfaceId,
      ...owner,
      generation: crypto.randomUUID(),
      components: {},
      data: {},
      status: "receiving",
      sendDataModel: v.sendDataModel === true,
    };
  } else {
    if (!old) throw new LocalizedError("Create the surface before updating");
    next = structuredClone(old);
    delete next.error;
    if (kind === "deleteSurface") {
      if (Object.keys(v).length !== 1)
        throw new LocalizedError("Invalid deletion");
      records.splice(index, 1);
      return;
    }
    if (kind === "updateComponents") {
      if (
        !Array.isArray(v.components) ||
        !v.components.length ||
        v.components.length > 1024 ||
        new Set(v.components.map((c) => c.id)).size !== v.components.length ||
        Object.keys(v).some((k) => !["surfaceId", "components"].includes(k))
      )
        throw new LocalizedError("Invalid component update");
      for (const c of v.components) {
        if (!bounded(c.id, 256) || unsafe(c.id))
          throw new LocalizedError("Invalid component ID");
        next.components[c.id] = c;
      }
    } else {
      if (
        Object.keys(v).some((k) => !["surfaceId", "path", "value"].includes(k))
      )
        throw new LocalizedError("Invalid data update");
      next.data = set(next.data, v.path, v.value, !Object.hasOwn(v, "value"));
    }
    next.status = "receiving";
    next.messageID = owner.messageID;
  }
  validateSurface(next);
  if (index < 0) records.push(next);
  else records[index] = next;
}
export function decodeFences(source, finish = false) {
  let fence = null,
    prose = [],
    frames = [],
    errors = [];
  const lines = source.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i],
      last = i === lines.length - 1;
    if (!fence) {
      const opening = line.match(/^(.*?)```a2ui\s*$/);
      if (opening) {
        if (opening[1]) prose.push(opening[1]);
        fence = "a2ui";
        continue;
      }
      if (/^\s*```/.test(line)) fence = "code";
      prose.push(line);
      continue;
    }
    if (/^\s*```\s*$/.test(line)) {
      if (fence === "code") prose.push(line);
      fence = null;
      continue;
    }
    if (fence === "code") {
      prose.push(line);
      continue;
    }
    if ((!last || finish) && line.trim()) {
      try {
        if (line.length > 1024 * 1024)
          throw new LocalizedError("A2UI frame exceeds limit");
        frames.push(JSON.parse(line));
      } catch (e) {
        errors.push(e.message);
        frames.push(null);
      }
    }
  }
  return { prose: prose.join("\n"), frames, errors };
}
export function actionEnvelope(surface, id) {
  const c = surface.components[id];
  if (c?.component !== "Button" || failures(c, surface.data).length)
    throw new LocalizedError("Form is invalid");
  const event = c.action.event;
  return {
    envelope: {
      action: {
        surfaceId: surface.id,
        sourceComponentId: id,
        name: event.name,
        context: resolve(event.context || {}, surface.data),
        timestamp: new Date().toISOString(),
      },
    },
    metadata: surface.sendDataModel
      ? {
          a2uiClientDataModel: {
            surfaces: { [surface.id]: structuredClone(surface.data) },
          },
        }
      : {},
  };
}
