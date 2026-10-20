import { parse } from "yaml";

/** Preserve native Int64/UInt64 values rather than rounding them through Number. */
export function parseSceneValue(text) {
  const safe = (value) => {
    if (
      typeof value === "bigint" &&
      value >= BigInt(Number.MIN_SAFE_INTEGER) &&
      value <= BigInt(Number.MAX_SAFE_INTEGER)
    )
      return Number(value);
    if (Array.isArray(value)) return value.map(safe);
    if (value && typeof value === "object")
      return Object.fromEntries(
        Object.entries(value).map(([key, child]) => [key, safe(child)]),
      );
    return value;
  };
  return safe(parse(text, { maxAliasCount: 0, intAsBigInt: true }));
}

/** JSON syntax with exact native integer literals. Scene values are plain data. */
export function stringifySceneValue(value, space = 0) {
  const indent = " ".repeat(Math.min(10, Math.max(0, space)));
  const ancestors = new Set();
  function encode(value, depth) {
    if (typeof value === "bigint") return value.toString();
    if (!value || typeof value !== "object") return JSON.stringify(value);
    if (ancestors.has(value)) throw new TypeError("Circular scene value");
    ancestors.add(value);
    const array = Array.isArray(value);
    const parts = array
      ? value.map((child) => encode(child, depth + 1) ?? "null")
      : Object.entries(value)
          .filter(([, child]) => child !== undefined)
          .map(
            ([key, child]) =>
              JSON.stringify(key) +
              (indent ? ": " : ":") +
              encode(child, depth + 1),
          );
    ancestors.delete(value);
    const [open, close] = array ? ["[", "]"] : ["{", "}"];
    return (
      open +
      (parts.length && indent ? "\n" + indent.repeat(depth + 1) : "") +
      parts.join(indent ? ",\n" + indent.repeat(depth + 1) : ",") +
      (parts.length && indent ? "\n" + indent.repeat(depth) : "") +
      close
    );
  }
  return encode(value, 0);
}

/** Tool responses use decimal strings, because provider JSON cannot carry BigInt. */
export const sceneToolJSON = (value) =>
  JSON.stringify(value, (_, child) =>
    typeof child === "bigint" ? child.toString() : child,
  );
