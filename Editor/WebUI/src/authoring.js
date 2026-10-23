import { LocalizedError } from "./localization.js";
import { clone, file, metadata, scenePath, validate } from "./documents.js";
import { decode, encode } from "./platform.js";
import { resources } from "./knowledge.js";
import { normalizeInputActions } from "./input-actions.js";
import { projectSchemas } from "./project-schemas.js";
import {
  normalizeScene,
  validateNativeValues,
} from "./authoring-validation.js";
import { stringifySceneValue } from "./scene-codec.js";
import { validateRuntime } from "./runtime-config.js";

/** Stage files and scene together; asynchronous preflight never mutates Undo. */
export async function authoringEdit(studio, update) {
  const document = studio.document;
  const generation = document.contentGeneration;
  const next = clone(document.snapshot);
  update(next);
  validate(next);
  const { contract } = await resources();
  const meta = metadata(next);
  validateRuntime(meta.runtime);
  if (meta.inputActions !== undefined)
    meta.inputActions = normalizeInputActions(
      meta.inputActions,
      contract.input,
    );
  file(next, ".ada/project.json").data = encode(JSON.stringify(meta, null, 2));
  // Avoid requiring a running Player for a plain built-in scene. Custom schemas
  // are parsed from the PROPOSED source set, not the currently loaded world.
  const needsSchemas = /@component\b/.test(
    next.files
      .filter((f) => f.path.startsWith("Sources/"))
      .map((f) => decode(f.data))
      .join("\n"),
  );
  const project = needsSchemas
    ? await projectSchemas(studio, next)
    : { schemas: [], available: true };
  if (needsSchemas && !project.available)
    throw new LocalizedError(
      "AdaPlayer is required to inspect project components.",
    );
  const content = (snapshot) =>
    snapshot.files.filter((f) => /\.(ada|ascn)$/.test(f.path));
  const affectsScene =
    JSON.stringify(content(next)) !==
      JSON.stringify(content(document.snapshot)) ||
    scenePath(next) !== scenePath(document.snapshot);
  const normalized = affectsScene
    ? normalizeScene(next, contract, project.schemas)
    : null;
  if (
    normalized &&
    normalized.nativeChecks.length &&
    !studio.preview?.frame &&
    studio.syncViewport
  ) {
    try {
      await studio.syncViewport(true);
    } catch {
      /* Inspection remains available after scene failure. */
    }
  }
  if (normalized) await validateNativeValues(studio, normalized.nativeChecks);
  if (studio.document !== document || document.contentGeneration !== generation)
    throw new LocalizedError("Project changed");
  if (normalized)
    file(next, scenePath(next)).data = encode(
      stringifySceneValue(normalized.value, 2),
    );
  document.edit((snapshot) => {
    snapshot.files = next.files;
    snapshot.title = next.title;
  });
  studio.changed();
  return {
    saved: true,
    generation: document.contentGeneration,
    validation:
      "authoring schemas and native value codecs; full compilation and runtime validation require editor_build",
    runtimePending: true,
  };
}
