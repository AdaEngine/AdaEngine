import { LocalizedError } from "./localization.js";
import { AuthoringError } from "./authoring-validation.js";
const string = { type: "string", minLength: 1 };
const parent = { type: ["string", "null"] };
const components = { type: "object", additionalProperties: { type: "object" } };
const variants = [
  [
    "createEntity",
    {
      id: string,
      name: string,
      enabled: { type: "boolean" },
      parentID: parent,
      components,
    },
    ["name", "components"],
  ],
  ["renameEntity", { name: string }, ["entityID", "name"]],
  [
    "setEntityEnabled",
    { enabled: { type: "boolean" } },
    ["entityID", "enabled"],
  ],
  ["reparentEntity", { parentID: parent }, ["entityID", "parentID"]],
  [
    "deleteEntity",
    { children: { type: "string", enum: ["delete", "reparent"] } },
    ["entityID"],
  ],
  [
    "addComponent",
    { typeName: string, payload: { type: "object" } },
    ["entityID", "typeName", "payload"],
  ],
  [
    "setComponent",
    { typeName: string, payload: { type: "object" } },
    ["entityID", "typeName", "payload"],
  ],
  ["removeComponent", { typeName: string }, ["entityID", "typeName"]],
];
export const sceneOperationsSchema = {
  type: "array",
  minItems: 1,
  maxItems: 100,
  items: {
    oneOf: variants.map(([op, properties, required]) => ({
      type: "object",
      properties: {
        op: { type: "string", const: op },
        ...(op === "createEntity" ? {} : { entityID: string }),
        ...properties,
      },
      required: ["op", ...required],
      additionalProperties: false,
    })),
  },
};
export function validateSceneOperation(op, index) {
  const variant = sceneOperationsSchema.items.oneOf.find(
    (s) => s.properties.op.const === op?.op,
  );
  const fail = (key, detail) => {
    throw new AuthoringError(
      "scene.operation",
      `operations[${index}]${key ? "." + key : ""}`,
      detail,
      { repairTool: "editor_scene_get" },
    );
  };
  if (!variant || !op || typeof op !== "object" || Array.isArray(op))
    fail("", new LocalizedError("Unsupported scene operation"));
  for (const key of variant.required) {
    // Accept the legacy target id spelling in existing local action envelopes.
    if (
      op[key] === undefined &&
      !(key === "entityID" && typeof op.id === "string")
    )
      fail(key, new LocalizedError("Required field"));
  }
  for (const [key, value] of Object.entries(op)) {
    const spec = variant.properties[key] || (key === "id" ? string : null);
    if (!spec) fail(key, new LocalizedError("Unknown operation field"));
    const valid =
      spec.type === "object"
        ? value !== null && typeof value === "object" && !Array.isArray(value)
        : Array.isArray(spec.type)
          ? value === null || typeof value === "string"
          : typeof value === spec.type;
    if (
      !valid ||
      (spec.minLength && !value.length) ||
      (spec.enum && !spec.enum.includes(value))
    )
      fail(key, new LocalizedError("Invalid operation field"));
  }
}
