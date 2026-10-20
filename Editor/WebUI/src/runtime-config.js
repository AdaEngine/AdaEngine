import { AuthoringError } from "./authoring-validation.js";
import { LocalizedError } from "./localization.js";
const string = { type: "string", minLength: 1 };
const strings = { type: "array", items: string, uniqueItems: true };
const object = (properties) => ({
  type: "object",
  properties,
  additionalProperties: false,
});
export const runtimePatchSchema = object({
  moduleName: string,
  entry: object({ scene: string, startupSystem: string }),
  plugins: object({
    preset: { type: "string", enum: ["ui", "game2d", "game3d", "custom"] },
    presetVersion: { type: "integer", minimum: 1 },
    enable: strings,
    disable: strings,
    settings: object({
      physics2d: object({
        gravity: {
          type: "array",
          items: { type: "number" },
          minItems: 2,
          maxItems: 2,
        },
      }),
      multiplayer: object({
        role: { type: "string", enum: ["host", "client"] },
        peerIndex: { type: "integer", minimum: 0 },
        port: { type: "integer", minimum: 1, maximum: 65535 },
        host: string,
        gameIdentifier: string,
        buildIdentifier: string,
      }),
    }),
  }),
  window: object({
    size: object({
      width: { type: "number", exclusiveMinimum: 0 },
      height: { type: "number", exclusiveMinimum: 0 },
    }),
    isResizable: { type: "boolean" },
  }),
});
export function patchRuntime(current, patch) {
  validateRuntime(patch);
  const result = structuredClone(current);
  for (const [key, value] of Object.entries(patch))
    result[key] =
      value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      result[key] &&
      typeof result[key] === "object"
        ? mergeObject(result[key], value)
        : structuredClone(value);
  return result;
}
function mergeObject(current, patch) {
  const next = structuredClone(current);
  for (const [key, value] of Object.entries(patch))
    next[key] =
      value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      next[key] &&
      typeof next[key] === "object"
        ? mergeObject(next[key], value)
        : structuredClone(value);
  return next;
}
/** One validator consumes the same complete runtime shape advertised to the model. */
export function validateRuntime(
  value,
  schema = runtimePatchSchema,
  path = "runtime",
) {
  const invalid = () => {
    throw new AuthoringError(
      "runtime.value",
      path,
      new LocalizedError(
        "Invalid runtime setting. Read the project configuration schema.",
      ),
      { repairTool: "editor_project_context" },
    );
  };
  if (schema.type === "object") {
    if (!value || typeof value !== "object" || Array.isArray(value)) invalid();
    for (const [key, next] of Object.entries(value)) {
      if (!Object.hasOwn(schema.properties, key)) invalid();
      validateRuntime(next, schema.properties[key], path + "." + key);
    }
  } else if (schema.type === "array") {
    if (
      !Array.isArray(value) ||
      value.length < (schema.minItems || 0) ||
      value.length > (schema.maxItems || Infinity) ||
      (schema.uniqueItems && new Set(value).size !== value.length)
    )
      invalid();
    value.forEach((item, index) =>
      validateRuntime(item, schema.items, `${path}[${index}]`),
    );
  } else {
    const type = schema.type === "integer" ? "number" : schema.type;
    if (
      typeof value !== type ||
      (schema.type === "integer" && !Number.isSafeInteger(value)) ||
      (type === "number" && !Number.isFinite(value)) ||
      (schema.minLength && value.length < schema.minLength) ||
      (schema.enum && !schema.enum.includes(value))
    )
      invalid();
    if (
      (schema.minimum !== undefined && value < schema.minimum) ||
      (schema.maximum !== undefined && value > schema.maximum) ||
      (schema.exclusiveMinimum !== undefined &&
        value <= schema.exclusiveMinimum)
    )
      invalid();
  }
}
