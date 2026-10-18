import { clone, scenePath } from "./documents.js";
import { resolve } from "./a2ui.js";
import { t } from "./localization.js";

export function validateAnnotations(items = []) {
  if (!Array.isArray(items) || items.length > 8)
    throw new Error("Invalid annotations");
  const ids = new Set();
  for (const item of items) {
    if (
      typeof item.id !== "string" ||
      item.id.length > 64 ||
      ids.has(item.id) ||
      typeof item.note !== "string" ||
      item.note.length > 4000 ||
      typeof item.fragment !== "string" ||
      item.fragment.length > 4600 ||
      !["entity", "a2ui", "preview"].includes(item.target?.kind) ||
      typeof item.target.label !== "string" ||
      item.target.label.length > 500 ||
      JSON.stringify(item.target).length > 16000 ||
      (item.image !== undefined &&
        (typeof item.image !== "string" ||
          !item.image.startsWith("data:image/jpeg;base64,") ||
          item.image.length > 96 * 1024))
    )
      throw new Error("Invalid annotation");
    ids.add(item.id);
  }
}

export function toggleAnnotations(s) {
  s.annotationMode = !s.annotationMode;
  s.annotationDraft = null;
  ++s.annotationEpoch;
  s.emit();
}
export function cancelAnnotation(s) {
  s.annotationMode = false;
  s.annotationDraft = null;
  ++s.annotationEpoch;
  s.emit();
}
function open(s, target, anchor) {
  if (!s.document || s.projectBrowser) return;
  if ((s.session.annotations || []).length >= 8)
    throw new Error(t("You can add up to eight annotations"));
  const draft = {
    target,
    anchor,
    note: "",
    document: s.document,
    sessionID: s.session.id,
    epoch: ++s.annotationEpoch,
    busy: false,
  };
  s.annotationMode = true;
  s.annotationDraft = draft;
  s.emit();
  return draft;
}
function current(s, draft) {
  return (
    s.annotationDraft === draft &&
    s.annotationEpoch === draft.epoch &&
    s.document === draft.document &&
    s.session.id === draft.sessionID &&
    !s.projectBrowser
  );
}
export function entityTarget(s, id) {
  const entity = s.scene?.entities.find((e) => e.id === id);
  if (!entity)
    throw new Error(t("The selected object is no longer in the scene"));
  return {
    kind: "entity",
    label: entity.name.slice(0, 500),
    path: scenePath(s.snapshot),
    entityID: entity.id,
    componentTypes: Object.keys(entity.components),
    transform: clone(entity.components["AdaTransform.Transform"] || {}),
  };
}
export function annotateEntity(s, id, anchor) {
  return open(s, entityTarget(s, id), anchor);
}
export function annotateUI(s, surfaceID, generation, componentID, anchor) {
  const surface = s.chat.surfaces.find(
      (r) =>
        r.id === surfaceID &&
        r.generation === generation &&
        r.sessionID === s.session.id,
    ),
    component = surface?.components[componentID];
  if (!component)
    throw new Error(t("The selected UI element is no longer available"));
  const label = resolve(
    component.label ?? component.text ?? component.placeholder ?? component.id,
    surface.data,
  );
  const definition = JSON.stringify(component),
    values = JSON.stringify(resolve(component, surface.data));
  return open(
    s,
    {
      kind: "a2ui",
      label: String(label || component.id).slice(0, 500),
      surfaceID,
      generation,
      componentID,
      componentType: component.component,
      definition: definition.slice(0, 6000),
      values: values.slice(0, 6000),
    },
    anchor,
  );
}
export async function annotatePreview(s, point, anchor) {
  if (
    !s.preview.ready ||
    ![point.x, point.y].every((n) => Number.isFinite(n) && n >= 0 && n <= 1)
  )
    throw new Error(t("Wait for the preview to load"));
  const revision = s.preview.editorRevision;
  const draft = open(
    s,
    { kind: "preview", label: t("Game element"), point },
    anchor,
  );
  if (!draft) return;
  draft.busy = true;
  s.emit();
  try {
    if (!s.playing) {
      const hit = await s.preview.message("editor", {
        action: "annotate",
        point,
        revision,
      });
      if (!current(s, draft)) return;
      if (hit.entityID)
        draft.target = { ...entityTarget(s, hit.entityID), point };
      if (hit.entityID) draft.sceneTarget = draft.target;
    }
    const image = await s.preview.message("capture", { point });
    if (!current(s, draft)) return;
    if (s.preview.editorRevision !== revision)
      throw new Error(t("The preview changed. Select the element again."));
    if (
      typeof image === "string" &&
      image.startsWith("data:image/jpeg;base64,") &&
      image.length <= 96 * 1024
    )
      draft.image = image;
    else throw new Error(t("The preview image is unavailable"));
  } catch (error) {
    if (!current(s, draft)) return;
    draft.error = error.message;
  } finally {
    if (current(s, draft)) {
      draft.busy = false;
      s.emit();
    }
  }
}
export function addAnnotation(s) {
  const draft = s.annotationDraft;
  if (
    !draft ||
    !current(s, draft) ||
    draft.busy ||
    draft.error ||
    !draft.note.trim()
  )
    return false;
  const item = {
    id: crypto.randomUUID(),
    target: clone(draft.target),
    note: draft.note.trim(),
    fragment:
      t("Annotation: {0}", draft.target.label) + "\n" + draft.note.trim(),
    ...(draft.image ? { image: draft.image } : {}),
  };
  const prompt = s.prompt + (s.prompt ? "\n\n" : "") + item.fragment;
  s.updateChat((c) => {
    const session = c.sessions.find((r) => r.id === draft.sessionID);
    session.annotations = [...(session.annotations || []), item];
    validateAnnotations(session.annotations);
    session.draft = prompt;
  });
  s.prompt = prompt;
  cancelAnnotation(s);
  s.assistant = true;
  s.viewportExpanded = false;
  if (s.view !== "editor" && s.view !== "assistant") s.view = "assistant";
  ++s.composerFocus;
  s.emit();
  return true;
}
export function removeAnnotation(s, id) {
  const item = s.session.annotations?.find((r) => r.id === id);
  if (!item) return;
  const index = s.prompt.indexOf(item.fragment);
  let prompt = s.prompt;
  if (index >= 0) {
    const start =
      index >= 2 && prompt.slice(index - 2, index) === "\n\n"
        ? index - 2
        : index;
    let end = index + item.fragment.length;
    if (index === 0 && prompt.slice(end, end + 2) === "\n\n") end += 2;
    prompt = prompt.slice(0, start) + prompt.slice(end);
  }
  s.updateChat((c) => {
    const session = c.sessions.find((r) => r.id === s.session.id);
    session.annotations = session.annotations.filter((r) => r.id !== id);
    session.draft = prompt;
  });
  s.prompt = prompt;
  s.emit();
}
