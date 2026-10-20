import { LocalizedError } from "./localization.js";
import { base64, bytes } from "./platform.js";
import { defaultChat } from "./chat.js";

export const attachmentAccept =
  ".png,.jpg,.jpeg,.webp,.glb,.vox,.wav,.ogg,.mp3,.m4a,.aac,.flac,.md,.txt,.ada";
export const maximumAttachments = 4;
const maximumBytes = 16 * 1024 * 1024;
export function attachmentKind(name) {
  if (/\.(png|jpe?g|webp)$/i.test(name)) return "image";
  if (/\.(glb|vox)$/i.test(name)) return "model";
  if (/\.(wav|ogg|mp3|m4a|aac|flac)$/i.test(name)) return "audio";
  if (/\.(md|txt|ada)$/i.test(name)) return "text";
  throw new LocalizedError(
    "Unsupported attachment. Choose an image, GLB/VOX model, audio or text file.",
  );
}
export function pcmWAV(audio) {
  const channels = audio.numberOfChannels,
    frames = audio.length;
  if (channels > 2) throw new LocalizedError("Choose mono or stereo audio.");
  const size = 44 + frames * channels * 2;
  if (!channels || !frames || size > maximumBytes)
    throw new LocalizedError(
      "Converted audio exceeds 16 MB. Choose a shorter recording.",
    );
  const output = new Uint8Array(size),
    view = new DataView(output.buffer);
  const tag = (at, value) => {
    for (let i = 0; i < value.length; i++) output[at + i] = value.charCodeAt(i);
  };
  tag(0, "RIFF");
  view.setUint32(4, size - 8, true);
  tag(8, "WAVE");
  tag(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, channels, true);
  view.setUint32(24, audio.sampleRate, true);
  view.setUint32(28, audio.sampleRate * channels * 2, true);
  view.setUint16(32, channels * 2, true);
  view.setUint16(34, 16, true);
  tag(36, "data");
  view.setUint32(40, size - 44, true);
  const samples = Array.from({ length: channels }, (_, index) =>
    audio.getChannelData(index),
  );
  for (let frame = 0, offset = 44; frame < frames; frame++)
    for (let channel = 0; channel < channels; channel++, offset += 2) {
      const sample = Math.max(-1, Math.min(1, samples[channel][frame]));
      view.setInt16(
        offset,
        Math.round(sample * (sample < 0 ? 32768 : 32767)),
        true,
      );
    }
  return output;
}
async function audioToWAV(data) {
  const Context =
    globalThis.OfflineAudioContext || globalThis.webkitOfflineAudioContext;
  if (!Context)
    throw new LocalizedError(
      "Audio conversion is unavailable in this browser. Choose WAV or OGG.",
    );
  try {
    const context = new Context(2, 1, 44100);
    return pcmWAV(
      await context.decodeAudioData(
        data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength),
      ),
    );
  } catch (error) {
    if (error instanceof LocalizedError) throw error;
    throw new LocalizedError(
      "Could not read this audio file. Choose WAV or OGG, or try another recording.",
    );
  }
}
async function readImage(data, name) {
  const mime = /\.webp$/i.test(name)
    ? "image/webp"
    : /\.png$/i.test(name)
      ? "image/png"
      : "image/jpeg";
  const source = new Image();
  source.src = `data:${mime};base64,${base64(data)}`;
  try {
    await source.decode();
  } catch {
    throw new LocalizedError(
      "Could not read this image. Choose a PNG, JPEG or WebP file.",
    );
  }
  return source;
}
export async function imagePreview(data, name) {
  const source = await readImage(data, name);
  const canvas = document.createElement("canvas");
  const scale = Math.min(
    1,
    1280 / Math.max(source.naturalWidth, source.naturalHeight),
  );
  canvas.width = Math.max(1, Math.round(source.naturalWidth * scale));
  canvas.height = Math.max(1, Math.round(source.naturalHeight * scale));
  const context = canvas.getContext("2d");
  if (!context)
    throw new LocalizedError(
      "Image processing is unavailable in this browser.",
    );
  // Flatten transparent areas onto a neutral background for the vision thumbnail only.
  context.fillStyle = "#eeeeee";
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.drawImage(source, 0, 0, canvas.width, canvas.height);
  for (const quality of [0.8, 0.6, 0.4]) {
    const preview = canvas.toDataURL("image/jpeg", quality);
    if (preview.length <= 140000) return preview;
  }
  const small = document.createElement("canvas");
  const smaller = Math.min(1, 512 / Math.max(canvas.width, canvas.height));
  small.width = Math.max(1, Math.round(canvas.width * smaller));
  small.height = Math.max(1, Math.round(canvas.height * smaller));
  small.getContext("2d").drawImage(canvas, 0, 0, small.width, small.height);
  const preview = small.toDataURL("image/jpeg", 0.4);
  if (preview.length > 140000)
    throw new LocalizedError(
      "Could not prepare this image for the assistant. Try a smaller image.",
    );
  return preview;
}
export async function prepareAttachment(input, assertCurrent = () => {}) {
  const kind = attachmentKind(input.name);
  if (kind === "text" && input.size > 100000)
    throw new LocalizedError("The text attachment exceeds 100 KB");
  if (input.size > maximumBytes)
    throw new LocalizedError("An attachment can be up to 16 MB.");
  let data = new Uint8Array(await input.arrayBuffer());
  assertCurrent();
  if (kind === "text" && data.length > 100000)
    throw new LocalizedError("The text attachment exceeds 100 KB");
  if (data.length > maximumBytes)
    throw new LocalizedError("An attachment can be up to 16 MB.");
  let name = input.name,
    converted = false;
  if (/\.(mp3|m4a|aac|flac)$/i.test(name)) {
    data = await audioToWAV(data);
    name = name.replace(/\.[^.]+$/, ".wav");
    converted = true;
  }
  if (/\.webp$/i.test(name)) {
    const source = await readImage(data, name),
      canvas = document.createElement("canvas");
    canvas.width = source.naturalWidth;
    canvas.height = source.naturalHeight;
    canvas.getContext("2d").drawImage(source, 0, 0);
    const encoded = canvas.toDataURL("image/png").split(",")[1];
    data = bytes(encoded);
    name = name.replace(/\.webp$/i, ".png");
    converted = true;
  }
  if (data.length > maximumBytes)
    throw new LocalizedError("An attachment can be up to 16 MB.");
  const id = crypto.randomUUID(),
    safeName = name
      .replace(/[^a-zA-Z0-9_.-]/g, "_")
      .slice(-160)
      .replace(/\.ada$/i, ".txt");
  const path = `${kind === "text" ? "Docs/Attachments" : "Assets/Imports"}/${id}_${safeName}`;
  const preview = kind === "image" ? await imagePreview(data, name) : undefined;
  assertCurrent();
  return {
    id,
    path,
    data: base64(data),
    name: name.slice(0, 255),
    kind,
    size: data.length,
    converted,
    ...(preview ? { preview } : {}),
  };
}
export function attachmentEntries(studio, home = !studio.document) {
  if (home) return studio.homeAttachments || [];
  const session = studio.session;
  return (session.attachments || []).flatMap((path) => {
    const asset = studio.snapshot.files.find((file) => file.path === path);
    if (!asset) return [];
    const details = session.attachmentDetails?.[path];
    return [
      {
        id: path,
        path,
        data: asset.data,
        name: path
          .split("/")
          .at(-1)
          .replace(/^[0-9a-f-]{36}_/, ""),
        kind: /\.(png|jpe?g|webp)$/i.test(path)
          ? "image"
          : /\.(glb|gltf|vox)$/i.test(path)
            ? "model"
            : /\.(wav|ogg|mp3|m4a)$/i.test(path)
              ? "audio"
              : "text",
        size: bytes(asset.data).length,
        ...details,
      },
    ];
  });
}
export function putAttachments(snapshot, items, sessionID = "main", draft) {
  snapshot.files.push(...items.map(({ path, data }) => ({ path, data })));
  let marker = snapshot.messages.find(
    (message) => message.kind === "studio-state",
  );
  if (!marker) {
    marker = {
      id: crypto.randomUUID(),
      role: "assistant",
      content: "",
      kind: "studio-state",
      studio: defaultChat(),
    };
    snapshot.messages.push(marker);
  }
  const session = marker.studio.sessions.find(
    (session) => session.id === sessionID,
  );
  if (!session) throw new LocalizedError("Chat session not found");
  session.attachments = [
    ...new Set([
      ...session.attachments.filter((path) =>
        snapshot.files.some((file) => file.path === path),
      ),
      ...items.map((item) => item.path),
    ]),
  ];
  session.attachmentDetails ||= {};
  session.attachmentDetails = Object.fromEntries(
    Object.entries(session.attachmentDetails).filter(([path]) =>
      session.attachments.includes(path),
    ),
  );
  for (const { path, data, id, ...details } of items)
    session.attachmentDetails[path] = details;
  if (draft !== undefined) session.draft = draft;
}
export async function attachFiles(studio, inputs, { home = false } = {}) {
  const files = Array.from(inputs);
  if (!files.length) return [];
  if (studio.admitting || studio.running || studio.attachmentBusy)
    throw new LocalizedError(
      "Wait for the current operation before attaching files.",
    );
  const origin = studio.document,
    owner = home ? null : origin,
    sessionID = owner ? studio.session.id : null;
  const existing = attachmentEntries(studio, home || !owner);
  if (existing.length + files.length > maximumAttachments)
    throw new LocalizedError("You can attach up to four files");
  const assertCurrent = () => {
    if (studio.document !== origin)
      throw new LocalizedError("A different project is open");
  };
  studio.attachmentBusy = true;
  studio.emit();
  try {
    const prepared = [];
    for (const file of files)
      prepared.push(await prepareAttachment(file, assertCurrent));
    assertCurrent();
    if (owner) {
      owner.edit((snapshot) => putAttachments(snapshot, prepared, sessionID));
      studio.changed();
    } else {
      if (
        [...existing, ...prepared].reduce((sum, item) => sum + item.size, 0) >
        63 * 1024 * 1024
      )
        throw new LocalizedError("Attachments exceed 63 MB in total.");
      studio.homeAttachments = [...existing, ...prepared];
      studio.emit();
    }
    return prepared.map((item) => item.path);
  } finally {
    studio.attachmentBusy = false;
    studio.emit();
  }
}
export function removeAttachment(studio, id, home = !studio.document) {
  if (home) {
    studio.homeAttachments = studio.homeAttachments.filter(
      (item) => item.id !== id,
    );
    studio.emit();
  } else
    studio.updateChat((chat) => {
      const session = chat.sessions.find(
        (session) => session.id === studio.session.id,
      );
      session.attachments = session.attachments.filter((path) => path !== id);
      if (session.attachmentDetails) delete session.attachmentDetails[id];
    });
}
