import { clone, scenePath } from "./documents.js";
import { resolve } from "./a2ui.js";
import { t, LocalizedError } from "./localization.js";

export function validateAnnotations(items = []) {
  if (!Array.isArray(items) || items.length > 8)
    throw new LocalizedError("Invalid annotations");
  const ids = new Set();
  const numbers = new Set();
  for (const item of items) {
    if (
      typeof item.id !== "string" ||
      item.id.length > 64 ||
      ids.has(item.id) ||
      (item.number !== undefined &&
        (!Number.isSafeInteger(item.number) ||
          item.number < 1 ||
          numbers.has(item.number))) ||
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
      throw new LocalizedError("Invalid annotation");
    ids.add(item.id);
    if (item.number !== undefined) numbers.add(item.number);
  }
}

export function toggleAnnotations(s) {
  s.annotationMode = !s.annotationMode;
  s.annotationDraft = null;
  s.annotationBatchID = s.annotationMode ? crypto.randomUUID() : null;
  ++s.annotationEpoch;
  s.emit();
}
export function cancelAnnotation(s) {
  s.annotationMode = false;
  s.annotationDraft = null;
  s.annotationBatchID = null;
  ++s.annotationEpoch;
  s.emit();
}
export const annotationNumber = (items, item) =>
  item.number || items.indexOf(item) + 1;
function open(s, target, anchor, editingID) {
  if (!s.document || s.projectBrowser) return;
  const items = s.session.annotations || [];
  if (!editingID && items.length >= 8)
    throw new LocalizedError("You can add up to eight annotations");
  const draft = {
    target,
    anchor,
    note: "",
    document: s.document,
    sessionID: s.session.id,
    epoch: ++s.annotationEpoch,
    busy: false,
    editingID,
    number: editingID
      ? annotationNumber(
          items,
          items.find((r) => r.id === editingID),
        )
      : Math.max(0, ...items.map((r) => annotationNumber(items, r))) + 1,
  };
  s.annotationBatchID ||= crypto.randomUUID();
  s.annotationMode = true;
  s.annotationDraft = draft;
  s.emit();
  return draft;
}
export function editAnnotation(s, id, anchor) {
  const item = s.session.annotations?.find((r) => r.id === id);
  if (!item) return;
  const draft = open(s, clone(item.target), anchor, id);
  if (!draft) return;
  const header = item.fragment.split("\n")[0];
  let start = s.prompt.indexOf(item.fragment),
    end;
  if (start >= 0) end = start + item.fragment.length;
  else {
    start = s.prompt.indexOf(header + "\n");
    if (start >= 0) {
      end = s.prompt.length;
      for (const other of s.session.annotations.filter((r) => r.id !== id)) {
        const next = s.prompt.indexOf(
          "\n\n" + other.fragment.split("\n")[0] + "\n",
          start + header.length,
        );
        if (next >= 0) end = Math.min(end, next);
      }
    }
  }
  draft.replacedFragment =
    start >= 0 ? s.prompt.slice(start, end) : item.fragment;
  draft.note =
    start >= 0
      ? draft.replacedFragment.slice(draft.replacedFragment.indexOf("\n") + 1)
      : item.note;
  draft.image = item.image;
  s.emit();
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
    throw new LocalizedError("The selected object is no longer in the scene");
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
    throw new LocalizedError("The selected UI element is no longer available");
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
    throw new LocalizedError("Wait for the preview to load");
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
    const image = await s.preview.message("capture", {
      point,
      annotationNumber: draft.number,
    });
    if (!current(s, draft)) return;
    if (s.preview.editorRevision !== revision)
      throw new LocalizedError(
        "The preview changed. Select the element again.",
      );
    if (
      typeof image === "string" &&
      image.startsWith("data:image/jpeg;base64,") &&
      image.length <= 96 * 1024
    )
      draft.image = image;
    else throw new LocalizedError("The preview image is unavailable");
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
    id: draft.editingID || crypto.randomUUID(),
    number: draft.number,
    batchID: draft.editingID
      ? s.session.annotations.find((r) => r.id === draft.editingID)?.batchID
      : s.annotationBatchID,
    target: clone(draft.target),
    note: draft.note.trim(),
    fragment:
      t("Annotation #{0}: {1}", draft.number, draft.target.label) +
      "\n" +
      draft.note.trim(),
    ...(draft.image ? { image: draft.image } : {}),
  };
  const previous = s.session.annotations?.find((r) => r.id === draft.editingID);
  let prompt = s.prompt;
  if (previous) {
    const fragment = draft.replacedFragment || previous.fragment;
    if (!prompt.includes(fragment))
      throw new LocalizedError(
        "This note was edited in the composer. Edit its text there or remove it before replacing it.",
      );
    prompt = prompt.replace(fragment, () => item.fragment);
  } else prompt += (prompt ? "\n\n" : "") + item.fragment;
  s.updateChat((c) => {
    const session = c.sessions.find((r) => r.id === draft.sessionID);
    const items = (session.annotations || []).map((r, i) => ({
      ...r,
      number: r.number || i + 1,
    }));
    session.annotations = previous
      ? items.map((r) => (r.id === item.id ? item : r))
      : [...items, item];
    validateAnnotations(session.annotations);
    session.draft = prompt;
  });
  s.prompt = prompt;
  s.annotationDraft = null;
  ++s.annotationEpoch;
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
