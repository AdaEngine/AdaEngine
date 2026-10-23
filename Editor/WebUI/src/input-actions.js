import { LocalizedError } from "./localization.js";
import { referenceMatches } from "./documentation.js";

class InputConfigurationError extends Error {
  constructor(code, path, localized) {
    super();
    Object.defineProperty(this, "message", { get: () => localized.message });
    this.code = code;
    Object.defineProperty(this, "diagnostics", {
      get: () => [
        {
          code,
          path,
          message: this.message,
          repairTool: "editor_input_describe",
        },
      ],
    });
  }
}

// Compare encoded values independently of JSON object property order.
function bindingKey(value, depth = 0) {
  if (depth > 6) return "invalid";
  if (value && typeof value === "object") {
    if (Array.isArray(value)) return "invalid";
    return (
      "{" +
      Object.keys(value)
        .sort()
        .map(
          (key) =>
            JSON.stringify(key) + ":" + bindingKey(value[key], depth + 1),
        )
        .join(",") +
      "}"
    );
  }
  return JSON.stringify(value);
}

/** Names are authoring input; only the native codec's exact representation is saved. */
export function normalizeInputActions(actions, contract) {
  const fail = (code, path, localized) => {
    throw new InputConfigurationError(code, path, localized);
  };
  if (!Array.isArray(actions))
    fail(
      "input.actions.type",
      "inputActions",
      new LocalizedError(
        "Input actions must be an array ({0}).",
        "inputActions",
      ),
    );
  const byName = new Map(
    contract.bindings.map((b) => [b.kind + ":" + b.name, b.encoded]),
  );
  const byEncoding = new Map(
    contract.bindings.map((b) => [bindingKey(b.encoded), b.encoded]),
  );
  const names = new Set();
  return actions.map((action, index) => {
    const path = `inputActions[${index}]`;
    if (
      !action ||
      typeof action.name !== "string" ||
      !action.name ||
      action.name !== action.name.trim() ||
      /[\p{Cc}\p{Cf}]/u.test(action.name) ||
      names.has(action.name)
    )
      fail(
        "input.action.name",
        path + ".name",
        new LocalizedError(
          "Input action names must be unique, nonempty and have no surrounding whitespace or control characters ({0}).",
          path + ".name",
        ),
      );
    names.add(action.name);
    const deadZone = action.deadZone ?? contract.defaultDeadZone;
    if (
      typeof deadZone !== "number" ||
      !Number.isFinite(deadZone) ||
      deadZone < 0 ||
      deadZone >= 1
    )
      fail(
        "input.action.deadZone",
        path + ".deadZone",
        new LocalizedError(
          "Input dead zone must be a finite number from 0 up to 1, excluding 1 ({0}).",
          path + ".deadZone",
        ),
      );
    if (!Array.isArray(action.bindings))
      fail(
        "input.bindings.type",
        path + ".bindings",
        new LocalizedError(
          "Input bindings must be an array ({0}).",
          path + ".bindings",
        ),
      );
    const unique = new Set();
    const bindings = action.bindings.map((binding, index) => {
      const location = `${path}.bindings[${index}]`;
      const encoded =
        binding && Object.hasOwn(binding, "kind")
          ? Object.keys(binding).every((key) => ["kind", "name"].includes(key))
            ? byName.get(binding.kind + ":" + binding.name)
            : undefined
          : byEncoding.get(bindingKey(binding));
      if (!encoded)
        fail(
          "input.binding.unsupported",
          location,
          new LocalizedError(
            "Unsupported input binding ({0}). Read editor_input_describe for valid names and encoding.",
            location,
          ),
        );
      const key = bindingKey(encoded);
      if (unique.has(key))
        fail(
          "input.binding.duplicate",
          location,
          new LocalizedError(
            "An action cannot contain duplicate input bindings ({0}).",
            location,
          ),
        );
      unique.add(key);
      return structuredClone(encoded);
    });
    return { name: action.name, deadZone, bindings };
  });
}

export function describeInput(
  contract,
  { query = "", offset = 0, limit = 30 } = {},
) {
  const matched = contract.bindings.filter((binding) =>
    referenceMatches(
      "input actions bindings " + binding.kind + " " + binding.name,
      query,
    ),
  );
  const start = Number.isInteger(offset) && offset >= 0 ? offset : 0;
  const size = Math.min(50, Math.max(1, Number.isInteger(limit) ? limit : 30));
  return {
    total: matched.length,
    bindings: matched
      .slice(start, start + size)
      .map(({ kind, name, encoded }) => ({
        kind,
        name,
        authoring: { kind, name },
        encoded,
      })),
    ...(start + size < matched.length ? { nextOffset: start + size } : {}),
    example: {
      name: "Jump",
      deadZone: contract.defaultDeadZone,
      bindings: [
        { kind: "key", name: "space" },
        { kind: "mouseButton", name: "left" },
        { kind: "touch", name: "touch" },
      ],
    },
    note: "Use named bindings with editor_project_configure. Persisted enum values are different from names: Space is a literal space, and mouse buttons are numeric. The tool performs native encoding and rejects unsupported or duplicate inputs.",
  };
}
