import { decode } from "./platform.js";
import { LocalizedError } from "./localization.js";

const cached = new WeakMap();
const sourceFiles = (snapshot) =>
  snapshot.files
    .filter(
      (file) => file.path.startsWith("Sources/") && file.path.endsWith(".ada"),
    )
    .sort((a, b) => a.path.localeCompare(b.path))
    .map((file) => ({ path: file.path, source: decode(file.data) }));

/** This uses the native parser, never scene-instance values or a JS imitation. */
export async function projectSchemas(
  studio,
  snapshot = studio.document?.snapshot,
) {
  const document = studio.document;
  if (!document || !studio.preview?.message)
    return { available: false, schemas: [] };
  const currentKey = JSON.stringify(sourceFiles(document.snapshot));
  const sources = sourceFiles(snapshot);
  const key = JSON.stringify(sources);
  if (cached.get(document)?.key === key) return cached.get(document).value;
  if (
    new TextEncoder().encode(
      JSON.stringify({ name: "inspect-sources", sources }),
    ).length > 1_048_576
  )
    throw new LocalizedError(
      "Project sources exceed the schema inspection limit.",
    );
  if (!studio.preview.frame && studio.syncViewport) {
    // An invalid current scene can still initialize the fixed parser bridge.
    try {
      await studio.syncViewport(true);
    } catch {
      /* Scene diagnostics remain in the viewport. */
    }
  }
  const result = await studio.preview.message("agent-tool", {
    name: "inspect-sources",
    sources,
  });
  if (
    studio.document !== document ||
    JSON.stringify(sourceFiles(document.snapshot)) !== currentKey
  )
    throw new LocalizedError("Project changed");
  if (!Array.isArray(result.schemas))
    throw new LocalizedError("Invalid project schema response.");
  const value = {
    available: true,
    schemas: result.schemas.map((schema) => ({
      ...schema,
      defaultPayload: Object.fromEntries(
        Object.entries(schema.defaultPayload || {}).filter(
          ([name]) =>
            !schema.fields.some(
              (field) =>
                field.name === name && field.kind === "entityReference",
            ),
        ),
      ),
      fields: schema.fields.map((field) =>
        field.kind === "int"
          ? {
              ...field,
              minimum: -2147483648,
              maximum: 2147483647,
              integerEncoding: "signed 32-bit integer in this wasm32 Player",
            }
          : field.kind === "entityReference"
            ? {
                ...field,
                editable: false,
                limitation:
                  "Runtime default only; stable scene entity references are not decoded by this Player. Omit this field.",
              }
            : field,
      ),
    })),
    validation: result.validation,
  };
  cached.set(document, { key, value });
  return value;
}
