import { t, LocalizedError } from "./localization.js";
import { validateSurface } from "./a2ui.js";
import { validateAnnotations, cancelAnnotation } from "./annotations.js";

export function validateChat(snapshot) {
  const messages = snapshot.messages || [];
  const markers = messages.filter((m) => m.kind === "studio-state");
  if (markers.length > 1) throw new LocalizedError("Duplicate chat state");
  for (const m of messages)
    if (
      !["user", "assistant", "tool"].includes(m.role) ||
      typeof m.content !== "string" ||
      m.content.length > 512 * 1024
    )
      throw new LocalizedError("Invalid chat message");
  if (!markers.length) return;
  const c = markers[0].studio;
  if (
    c?.version !== 1 ||
    !Array.isArray(c.sessions) ||
    !c.sessions.length ||
    c.sessions.length > 20 ||
    new Set(c.sessions.map((s) => s.id)).size !== c.sessions.length ||
    !c.sessions.some((s) => s.id === c.activeSessionID) ||
    !Array.isArray(c.surfaces) ||
    c.surfaces.length > 320 ||
    !Array.isArray(c.events) ||
    c.events.length > 100
  )
    throw new LocalizedError("Invalid chat state");
  for (const s of c.sessions) {
    validateAnnotations(s.annotations);
    if (
      typeof s.id !== "string" ||
      typeof s.title !== "string" ||
      !["build", "plan"].includes(s.mode) ||
      !["auto", "ask"].includes(s.permission) ||
      typeof s.draft !== "string" ||
      s.draft.length > 65536 ||
      !Array.isArray(s.skills) ||
      s.skills.length > 32 ||
      s.skills.some((id) => typeof id !== "string") ||
      !Array.isArray(s.attachments) ||
      s.attachments.length > 4 ||
      s.attachments.some((p) => typeof p !== "string")
    )
      throw new LocalizedError("Invalid chat session");
    if (
      s.attachmentDetails !== undefined &&
      (!s.attachmentDetails ||
        typeof s.attachmentDetails !== "object" ||
        Array.isArray(s.attachmentDetails) ||
        Object.keys(s.attachmentDetails).length > 4 ||
        Object.entries(s.attachmentDetails).some(
          ([path, info]) =>
            !s.attachments.includes(path) ||
            !info ||
            typeof info.name !== "string" ||
            info.name.length > 255 ||
            !["image", "model", "audio", "text"].includes(info.kind) ||
            !Number.isFinite(info.size) ||
            info.size < 0 ||
            info.size > 16 * 1024 * 1024 ||
            (info.preview !== undefined &&
              (typeof info.preview !== "string" ||
                info.preview.length > 140000 ||
                !/^data:image\/(png|jpeg);base64,[A-Za-z0-9+/]+=*$/.test(
                  info.preview,
                ))),
        ))
    )
      throw new LocalizedError("Invalid attachment details");
  }
  const generations = new Set();
  for (const r of c.surfaces) {
    if (
      typeof r.id !== "string" ||
      typeof r.generation !== "string" ||
      generations.has(r.generation) ||
      typeof r.owner !== "string" ||
      !c.sessions.some((s) => s.id === r.sessionID) ||
      ![
        "receiving",
        "ready",
        "submitting",
        "submitted",
        "failed",
        "cancelled",
      ].includes(r.status)
    )
      throw new LocalizedError("Invalid persisted surface");
    generations.add(r.generation);
    validateSurface(r);
  }
}

export const defaultChat = () => ({
  version: 1,
  activeSessionID: "main",
  sessions: [
    {
      id: "main",
      title: t("Main conversation"),
      mode: "build",
      permission: "auto",
      skills: [],
      draft: "",
      attachments: [],
    },
  ],
  surfaces: [],
  events: [],
});
export const chatState = (snapshot) =>
  snapshot?.messages.find((m) => m.kind === "studio-state")?.studio ||
  defaultChat();
export const sessionMessages = (snapshot, id) =>
  snapshot.messages.filter(
    (m) => m.kind !== "studio-state" && (m.sessionID || "main") === id,
  );
export const identity = (s) => `${s.providerID}:${s.modelID}`;
export function editChat(studio, update) {
  studio.document.chat(update);
  studio.changed();
}
export function switchSession(studio, id) {
  if (!studio.chat.sessions.some((s) => s.id === id))
    throw new LocalizedError("Chat session not found");
  cancelAnnotation(studio);
  editChat(studio, (c) => {
    c.sessions.find((s) => s.id === c.activeSessionID).draft = studio.prompt;
    c.activeSessionID = id;
  });
  studio.prompt = studio.session.draft || "";
  studio.emit();
}
export function newSession(studio) {
  if (studio.chat.sessions.length >= 20)
    throw new LocalizedError("At most 20 conversations per project");
  const id = crypto.randomUUID();
  editChat(studio, (c) =>
    c.sessions.push({
      id,
      title: t("Conversation {0}", c.sessions.length + 1),
      mode: "build",
      permission: "auto",
      skills: [],
      draft: "",
      attachments: [],
    }),
  );
  switchSession(studio, id);
}
