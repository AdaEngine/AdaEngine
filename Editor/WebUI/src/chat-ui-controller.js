import { t, LocalizedError } from "./localization.js";
import { encode } from "./platform.js";
import { identity, editChat } from "./chat.js";
import {
  decodeFences,
  receive,
  actionEnvelope,
  set,
  validateSurface,
  get,
} from "./a2ui.js";
import {
  applyOperations,
  sceneRevision,
  spawnOperations,
  colorOperations,
} from "./scene-tools.js";
import { scenePath, file, scene, clone } from "./documents.js";
export function receiveUI(s, text, messageID, sessionID, finish = false) {
  const decoded = decodeFences(text, finish);
  if (s.uiProgress?.messageID !== messageID)
    s.uiProgress = { messageID, count: 0, errors: 0 };
  const progress = s.uiProgress,
    frames = decoded.frames.slice(progress.count),
    errors = decoded.errors.slice(progress.errors);
  if (!frames.length && !errors.length) return decoded.prose;
  progress.count = decoded.frames.length;
  progress.errors = decoded.errors.length;
  editChat(s, (c) => {
    for (const envelope of frames) {
      if (!envelope) continue;
      try {
        receive(c.surfaces, envelope, {
          messageID,
          sessionID,
          owner: s.turnOwner || identity(s),
        });
      } catch (e) {
        errors.push(e.message);
        const id = Object.values(envelope).find((v) => v?.surfaceId)?.surfaceId;
        const previous = c.surfaces.find(
          (r) =>
            r.id === id &&
            r.sessionID === sessionID &&
            r.owner === (s.turnOwner || identity(s)),
        );
        if (previous) previous.error = e.message;
      }
    }
    for (const message of errors)
      c.events.push({
        id: crypto.randomUUID(),
        sessionID,
        messageID,
        type: "a2ui-error",
        message,
      });
    c.events = c.events.slice(-100);
  });
  return decoded.prose;
}
export function finishUI(s, sessionID, status) {
  if (
    !s.chat.surfaces.some(
      (r) => r.sessionID === sessionID && r.status === "receiving",
    )
  )
    return;
  editChat(s, (c) => {
    for (const surface of c.surfaces)
      if (surface.sessionID === sessionID && surface.status === "receiving") {
        surface.status = surface.components.root ? status : "failed";
        if (!surface.components.root)
          surface.error = t("The form is missing its root component");
      }
  });
}
function owned(s, id, generation) {
  const surface = s.chat.surfaces.find(
    (r) =>
      r.id === id &&
      r.sessionID === s.session.id &&
      r.generation === generation,
  );
  if (
    !surface ||
    surface.owner !== identity(s) ||
    s.running ||
    !["ready", "submitted"].includes(surface.status)
  )
    throw new LocalizedError(
      "Card unavailable: select its original agent and wait for the response to finish.",
    );
  return surface;
}
export function editSurface(s, id, generation, path, value) {
  if (owned(s, id, generation).status !== "ready")
    throw new LocalizedError("The form has already been submitted");
  editChat(s, (c) => {
    const r = c.surfaces.find(
      (r) => r.id === id && r.sessionID === s.session.id,
    );
    r.data = set(r.data, path, value);
    validateSurface(r);
  });
}
export async function submitSurface(s, id, generation, componentID) {
  const surface = owned(s, id, generation),
    event = actionEnvelope(surface, componentID),
    name = event.envelope.action.name,
    context = event.envelope.action.context;
  if (name === "editor.color.pick")
    throw new LocalizedError(
      "Use the color picker on the card to set its color binding.",
    );
  if (name.startsWith("editor.")) {
    if (s.session.mode === "plan")
      throw new LocalizedError(
        "Switch this conversation to edit mode to apply the tool.",
      );
    if (
      ![
        "editor.scene.spawn",
        "editor.scene.setColor",
        "editor.scene.apply",
      ].includes(name)
    )
      throw new LocalizedError("Unsupported local action: {0}", name);
    if (
      typeof context.revisionBinding !== "string" ||
      get(surface.data, context.revisionBinding) !== context.expectedRevision
    )
      throw new LocalizedError("Card requires a matching revision binding");
    let operations = context.operations;
    if (name === "editor.scene.spawn")
      operations = spawnOperations(s.snapshot, context);
    if (name === "editor.scene.setColor")
      operations = colorOperations(s.snapshot, context);
    const doc = s.document,
      before = clone(file(s.snapshot, scenePath(s.snapshot)));
    const baseRevision = await sceneRevision(s.snapshot);
    if (
      context.path !== before.path ||
      context.expectedRevision !== baseRevision
    )
      throw new LocalizedError(
        "Scene changed. Read the scene and refresh the card.",
      );
    const candidate = clone(s.snapshot),
      value = scene(candidate);
    applyOperations(value, operations);
    const after = encode(JSON.stringify(value, null, 2));
    file(candidate, before.path).data = after;
    const revision = await sceneRevision(candidate);
    owned(s, id, generation);
    if (
      s.document !== doc ||
      file(s.snapshot, before.path).data !== before.data
    )
      throw new LocalizedError("Scene changed while validating revision");
    doc.edit((snapshot) => {
      file(snapshot, before.path).data = after;
      const r = snapshot.messages
        .find((m) => m.kind === "studio-state")
        .studio.surfaces.find(
          (r) =>
            r.generation === generation && r.sessionID === surface.sessionID,
        );
      if (!r) throw new LocalizedError("Surface expired");
      r.data = set(r.data, context.revisionBinding, revision);
      r.lastApplication = {
        before,
        revision,
        binding: context.revisionBinding,
      };
      r.status = "ready";
      r.error = "";
    });
    s.changed();
    return;
  }
  if (surface.status === "submitted")
    throw new LocalizedError("This form has already been submitted");
  editChat(s, (c) => {
    c.surfaces.find((r) => r.generation === generation).status = "submitting";
  });
  try {
    const completed = await s.send(
      "[A2UI user action]\nEnvelope: " +
        JSON.stringify(event.envelope) +
        "\nTransport metadata: " +
        JSON.stringify(event.metadata),
      { preserveDraft: true },
    );
    if (!completed)
      throw new LocalizedError(
        "The response was interrupted. You can submit the form again.",
      );
    editChat(s, (c) => {
      const r = c.surfaces.find((r) => r.generation === generation);
      if (r?.status === "submitting") r.status = "submitted";
    });
  } catch (e) {
    editChat(s, (c) => {
      const r = c.surfaces.find((r) => r.generation === generation);
      if (r) {
        r.status = "failed";
        r.error = e.message;
      }
    });
    throw e;
  }
}
export async function undoSurface(s, id, generation) {
  const r = owned(s, id, generation),
    last = r.lastApplication,
    doc = s.document;
  const current = file(s.snapshot, scenePath(s.snapshot))?.data;
  if (
    !last ||
    last.before.path !== scenePath(s.snapshot) ||
    last.revision !== (await sceneRevision(s.snapshot))
  )
    throw new LocalizedError(
      "The scene has changed. Ask the agent to refresh the card.",
    );
  const candidate = clone(s.snapshot);
  file(candidate, last.before.path).data = last.before.data;
  const revision = await sceneRevision(candidate);
  owned(s, id, generation);
  if (
    s.document !== doc ||
    file(s.snapshot, last.before.path)?.data !== current
  )
    throw new LocalizedError("Scene changed");
  doc.edit((snapshot) => {
    file(snapshot, last.before.path).data = last.before.data;
    const card = snapshot.messages
      .find((m) => m.kind === "studio-state")
      .studio.surfaces.find((c) => c.generation === generation);
    if (!card) throw new LocalizedError("Surface expired");
    card.data = set(card.data, last.binding, revision);
    delete card.lastApplication;
  });
  s.changed();
}
export async function exportSurface(s, id, generation) {
  const r = owned(s, id, generation),
    doc = s.document;
  if (!s.preview.ready) await s.syncViewport();
  const result = await s.preview.message("agent-tool", {
    name: "a2ui-export",
    surface: {
      id: r.id,
      data: r.data,
      components: Object.values(r.components),
    },
  });
  if (s.document !== doc) throw new LocalizedError("Project changed");
  const path =
    "Assets/UI/AgentPreviews/" +
    id.replace(/[^A-Za-z0-9_-]/g, "-").slice(0, 48) +
    "-" +
    crypto.randomUUID().slice(0, 8) +
    ".ui";
  s.document.write(path, result.content);
  s.changed();
  s.activeFile = path;
  s.navigate("code");
  return path;
}
