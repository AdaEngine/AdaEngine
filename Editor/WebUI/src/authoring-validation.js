import { LocalizedError } from "./localization.js";
import { file, scene, scenePath, validPath } from "./documents.js";
import { stringifySceneValue } from "./scene-codec.js";

const object = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const unsafe = new Set(["__proto__", "prototype", "constructor"]);
export class AuthoringError extends Error {
  constructor(code, path, detail, context = {}) {
    super();
    this.name = "AuthoringError";
    this.code = code;
    this.path = path;
    this.detail = detail;
    this.context = context;
  }
  get diagnostics() {
    return [
      {
        code: this.code,
        path: this.path,
        detail: this.detail?.message || this.detail,
        repairTool: "editor_components_describe",
        ...this.context,
      },
    ];
  }
  get message() {
    return new LocalizedError(
      "Invalid authoring value at {0}: {1}",
      this.path,
      this.detail?.message || this.detail,
    ).message;
  }
}
const reject = (code, path, detail, context) => {
  throw new AuthoringError(code, path, detail, context);
};
const finite = (value) =>
  typeof value === "number" &&
  Number.isFinite(value) &&
  Math.abs(value) <= 3.4028234663852886e38;
const vector = (value, size) =>
  Array.isArray(value) && value.length === size && value.every(finite);
const at = (value, path) => path.reduce((part, key) => part?.[key], value);
const assign = (value, path, next) => {
  for (const key of path.slice(0, -1)) value = value[key];
  value[path.at(-1)] = next;
};
function merge(defaults, input) {
  if (!object(defaults) || !object(input)) return structuredClone(input);
  const result = structuredClone(defaults);
  for (const [key, value] of Object.entries(input)) {
    if (unsafe.has(key))
      reject("component.field", key, new LocalizedError("Unsafe field name"));
    result[key] =
      object(value) && object(defaults[key])
        ? merge(defaults[key], value)
        : structuredClone(value);
  }
  return result;
}
function integer(value, unsigned, path, context) {
  if (typeof value === "number" && !Number.isSafeInteger(value))
    reject(
      "component.integer",
      path,
      new LocalizedError("Use an exact decimal string for a 64-bit integer"),
      context,
    );
  if (
    !(
      ["bigint", "number"].includes(typeof value) ||
      (typeof value === "string" && /^-?\d+$/.test(value))
    )
  )
    reject(
      "component.integer",
      path,
      new LocalizedError("Expected an integer"),
      context,
    );
  const next = BigInt(value);
  if (
    next < (unsigned ? 0n : -9223372036854775808n) ||
    next > (unsigned ? 18446744073709551615n : 9223372036854775807n)
  )
    reject(
      "component.integer",
      path,
      new LocalizedError("Integer is outside the native 64-bit range"),
      context,
    );
  return next <= BigInt(Number.MAX_SAFE_INTEGER) &&
    next >= BigInt(Number.MIN_SAFE_INTEGER)
    ? Number(next)
    : next;
}
function fieldValue(value, field, path, snapshot, context) {
  const kind = field.kind;
  if (field.coding === "unsignedInteger")
    return integer(value, true, path, context);
  if (kind === "int") {
    const next = integer(value, false, path, context);
    // Swift Int is 32-bit in the fixed wasm32 Player (UInt64 masks are separate).
    if (next < -2147483648 || next > 2147483647)
      reject(
        "component.integer",
        path,
        new LocalizedError(
          "Use a signed 32-bit integer for this browser field.",
        ),
        context,
      );
    if (field.minimum !== undefined && next < field.minimum)
      reject(
        "component.range",
        path,
        new LocalizedError("Value must be at least {0}.", field.minimum),
        context,
      );
    return next;
  }
  let valid = true;
  if (field.coding === "json") return value; // Production native decoder validates the nested shape.
  if (field.coding === "enumCase" || field.coding === "spriteImageMode") {
    const name =
      typeof value === "string"
        ? value
        : object(value) && Object.keys(value).length === 1
          ? Object.keys(value)[0]
          : null;
    if (!field.cases.includes(name))
      reject(
        "component.enum",
        path,
        new LocalizedError("Expected one of: {0}", field.cases.join(", ")),
        context,
      );
    return typeof value === "string"
      ? structuredClone(field.examples?.[name] || { [name]: {} })
      : value;
  }
  if (field.cases) valid = field.cases.includes(value);
  else if (kind === "bool") valid = typeof value === "boolean";
  else if (kind === "float") valid = finite(value);
  else if (kind === "string") valid = typeof value === "string";
  else if (kind.startsWith("vector")) {
    const size = Number(kind.slice(6));
    valid =
      field.coding === "spriteSize"
        ? value === null ||
          vector(value, 2) ||
          (object(value) &&
            Object.keys(value).length === 2 &&
            [value.width, value.height].every(finite))
        : field.coding === "vectorObject"
          ? object(value) &&
            Object.keys(value).length === size &&
            ["x", "y", "z", "w"]
              .slice(0, size)
              .every((key) => finite(value[key]))
          : vector(value, size);
  } else if (kind === "color")
    valid =
      (context.script && vector(value, 4)) ||
      (object(value) &&
        Object.keys(value).length === 4 &&
        ["red", "green", "blue", "alpha"].every((key) => finite(value[key])));
  else if (kind === "assetReference") {
    valid = value === null || typeof value === "string";
    if (valid && value) {
      const asset = value.startsWith("@res://")
        ? "Assets/" + value.slice(7)
        : value.startsWith("Assets/")
          ? value
          : "Assets/" + value;
      if (
        !validPath(asset) ||
        !asset.startsWith("Assets/") ||
        !file(snapshot, asset)
      )
        reject(
          "component.asset",
          path,
          new LocalizedError(
            "Referenced asset must exist inside Assets: {0}",
            value,
          ),
          context,
        );
      // The native AssetsPlugin owns Assets as its resource root. Keep the wire
      // reference canonical even when a tool caller supplies a project path.
      value = "@res://" + asset.slice(7);
    }
  } else if (kind === "entityReference")
    valid = value === -1; // No portable entity remapping is implemented by this Player.
  else valid = false;
  if (!valid)
    reject(
      "component.value",
      path,
      new LocalizedError(
        "Expected {0}",
        kind + (field.cases ? ": " + field.cases.join(", ") : ""),
      ),
      context,
    );
  if (field.minimum !== undefined && value < field.minimum)
    reject(
      "component.range",
      path,
      new LocalizedError("Value must be at least {0}.", field.minimum),
      context,
    );
  return value;
}
function checkKeys(value, fields, defaults, prefix, path, context) {
  for (const [key, child] of Object.entries(value)) {
    const parts = [...prefix, key];
    if (unsafe.has(key))
      reject(
        "component.field",
        path + "." + parts.join("."),
        new LocalizedError("Unsafe field name"),
        context,
      );
    const exact = fields.find((f) => f.path.join(".") === parts.join("."));
    if (exact) continue;
    const nested = fields.some(
      (f) => f.path.slice(0, parts.length).join(".") === parts.join("."),
    );
    // Some serialized defaults include native, non-editable nested fields (inertia.x/y, LUT intensity).
    if (nested && object(child))
      checkKeys(child, fields, defaults, parts, path, context);
    else if (at(defaults, parts) === undefined)
      reject(
        "component.field",
        path + "." + parts.join("."),
        new LocalizedError("Unknown field; read the component schema"),
        context,
      );
    else if (JSON.stringify(child) !== JSON.stringify(at(defaults, parts)))
      reject(
        "component.field",
        path + "." + parts.join("."),
        new LocalizedError("This native field is not editable in Web Player"),
        context,
      );
  }
}
/** Returns a normalized clone; never changes the candidate or current document. */
export function normalizeScene(snapshot, contract, schemas = []) {
  const value = scene(snapshot);
  const catalog = [
    ...contract.components,
    ...schemas.filter((s) => s.kind === "component"),
  ];
  const nativeChecks = [];
  for (const entity of value.entities) {
    if (typeof entity.enabled !== "boolean")
      reject(
        "entity.enabled",
        "entities." + entity.id + ".enabled",
        new LocalizedError("Expected boolean"),
      );
    for (const [typeName, input] of Object.entries(entity.components)) {
      const context = {
        entityID: entity.id,
        component: typeName,
        file: scenePath(snapshot),
      };
      const path = "entities." + entity.id + ".components." + typeName;
      const schema = catalog.find(
        (s) =>
          s.typeName === typeName ||
          s.name === typeName ||
          s.aliases?.includes(typeName),
      );
      if (!schema)
        reject(
          "component.unknown",
          path,
          new LocalizedError(
            "Unsupported component; declare it in project sources or choose a supported built-in",
          ),
          context,
        );
      if (!object(input))
        reject(
          "component.payload",
          path,
          new LocalizedError("Expected a component object"),
          context,
        );
      const script = schema.kind === "component";
      context.script = script;
      const defaults = schema.defaultPayload || {};
      checkKeys(input, schema.fields, defaults, [], path, context);
      const payload = merge(defaults, input);
      for (const field of schema.fields.filter((f) =>
        ["enumCase", "spriteImageMode"].includes(f.coding),
      )) {
        const supplied = at(input, field.path);
        if (supplied !== undefined)
          assign(payload, field.path, structuredClone(supplied));
      }
      for (const field of schema.fields) {
        const current = at(payload, field.path);
        if (script && field.kind === "entityReference") {
          if (current !== undefined && current !== -1)
            reject(
              "component.reference",
              path + "." + field.name,
              new LocalizedError(
                "This native field is not editable in Web Player",
              ),
              context,
            );
          // Omission retains the production runtime descriptor's default. Its
          // scene decoder intentionally has no portable entity-reference writer.
          delete payload[field.name];
          continue;
        }
        if (current !== undefined)
          assign(
            payload,
            field.path,
            fieldValue(
              current,
              field,
              path + "." + field.path.join("."),
              snapshot,
              context,
            ),
          );
      }
      for (const required of schema.requiredComponents || []) {
        // Visibility is automatically inserted by native renderable components.
        if (required === "AdaRender.Visibility") continue;
        if (!Object.hasOwn(entity.components, required))
          reject(
            "component.dependency",
            path,
            new LocalizedError("Also attach {0} on this entity.", required),
            context,
          );
      }
      if (
        schema.requiresAsset &&
        !payload.source &&
        typeName !== "AdaTilemap.TileMapComponent"
      )
        reject(
          "component.asset",
          path + ".source",
          new LocalizedError("An existing asset reference is required"),
          context,
        );
      if (typeName === "AdaScene.Mesh3DComponent" && payload.size > 100000)
        reject(
          "component.range",
          path + ".size",
          new LocalizedError("Mesh size must be at most 100000"),
          context,
        );
      entity.components[typeName] = payload;
      if (
        [
          "AdaPhysics.PhysicsBody2DComponent",
          "AdaSprite.Sprite",
          "AdaRender.Environment3D",
          "AdaScene.PointLightComponent",
        ].includes(typeName)
      )
        nativeChecks.push({
          typeName,
          entityID: entity.id,
          payloadJSON: stringifySceneValue(payload),
        });
    }
  }
  return { value, nativeChecks };
}
export async function validateNativeValues(studio, checks) {
  if (!checks.length) return;
  if (!studio.preview?.message)
    throw new LocalizedError(
      "AdaPlayer is required to validate component values.",
    );
  const result = await studio.preview.message("agent-tool", {
    name: "validate-component-values",
    components: checks,
  });
  if (result.valid !== true) {
    const first = result.diagnostics?.[0];
    throw new AuthoringError(
      "component.native",
      first?.path || "components",
      first?.message || result.error || "Native validation unavailable",
      first || {},
    );
  }
}
