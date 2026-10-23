import test from "node:test";
import assert from "node:assert/strict";
import { Preview } from "../src/preview.js";

function harness(autoReply = true) {
  let listener;
  const frames = [],
    sent = [],
    states = [];
  globalThis.window = {
    addEventListener(type, callback) {
      if (type === "message") listener = callback;
    },
  };
  globalThis.location = {
    protocol: "http:",
    hostname: "localhost",
    origin: "http://localhost:18443",
  };
  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: { gpu: {} },
  });
  globalThis.document = {
    createElement() {
      const frame = {
        setAttribute() {},
        remove() {
          this.removed = true;
        },
        contentWindow: {
          postMessage(message, origin) {
            sent.push({ message, origin, frame });
            if (autoReply) queueMicrotask(() => reply(sent.at(-1)));
          },
        },
      };
      frames.push(frame);
      return frame;
    },
  };
  const reply = (item, changes = {}) =>
    listener({
      source: item.frame.contentWindow,
      origin: "http://127.0.0.1:18444",
      data: {
        protocol: "ada-studio-preview-v1",
        id: item.message.id,
        value: { ready: true },
      },
      ...changes,
    });
  const preview = new Preview((state) => states.push(state));
  preview.host = {
    append(frame) {
      queueMicrotask(() => frame.onload());
    },
  };
  return {
    preview,
    frames,
    sent,
    states,
    reply,
    dispatch: (event) => listener(event),
  };
}
const config = { previewURL: "http://127.0.0.1:18444/studio-preview.html" };
const snapshot = {
  title: "Scene",
  files: [{ path: ".ada/project.json", data: "e30=" }],
  messages: [{ content: "private chat" }],
  apiKey: "private key",
};

test("editor commits require the current iframe, allowed origin and rendered revision", async () => {
  const h = harness(),
    events = [];
  h.preview.onEditorEvent = (...args) => events.push(args);
  await h.preview.load(snapshot, config, true);
  const event = {
    source: h.preview.frame.contentWindow,
    origin: "http://127.0.0.1:18444",
    data: {
      protocol: "ada-studio-preview-v1",
      event: "editor",
      type: "select",
      value: { id: "player" },
      revision: h.preview.editorRevision,
    },
  };
  h.dispatch({ ...event, source: {} });
  h.dispatch({ ...event, origin: "http://evil.example" });
  h.dispatch({ ...event, data: { ...event.data, revision: "stale" } });
  assert.equal(events.length, 0);
  h.dispatch(event);
  assert.equal(events.length, 1);
  const update = h.preview.load(
    {
      ...snapshot,
      files: [...snapshot.files, { path: "Assets/test.txt", data: "" }],
    },
    config,
    true,
  );
  await update;
  h.dispatch(event);
  assert.equal(events.length, 1);
  h.preview.stop();
  h.dispatch(event);
  assert.equal(events.length, 1);
});

test("Editor, Play and changed snapshots retain one isolated engine frame", async () => {
  const h = harness();
  await h.preview.load(snapshot, config, true);
  const frame = h.preview.frame;
  await h.preview.load(snapshot, config, false);
  await h.preview.load(
    {
      ...snapshot,
      files: [...snapshot.files, { path: "Sources/Game.ada", data: "Lw==" }],
    },
    config,
    true,
  );
  assert.equal(h.frames.length, 1);
  assert.equal(h.preview.frame, frame);
  assert.equal(h.preview.hasFrame, true);
  assert.equal(h.preview.ready, true);
  assert.deepEqual(
    h.sent.map((s) => s.message.payload.editMode),
    [true, false, true],
  );
  for (const item of h.sent) {
    assert.equal("apiKey" in item.message.payload, false);
    assert.equal("messages" in item.message.payload, false);
  }
  h.preview.stop();
  assert.equal(frame.removed, true);
});
test("identical render requests are coalesced and unchanged scenes are retained", async () => {
  const h = harness();
  const first = h.preview.load(snapshot, config, true),
    second = h.preview.load(snapshot, config, true);
  assert.equal(first, second);
  await first;
  await h.preview.load(snapshot, config, true);
  assert.equal(h.sent.length, 1);
  h.preview.stop();
});
test("superseded in-flight requests cannot mark an old revision ready", async () => {
  const h = harness(false),
    first = h.preview.load(snapshot, config, true);
  first.catch(() => {});
  await new Promise(setImmediate);
  assert.equal(h.sent.length, 1);
  const last = h.preview.load(
    { ...snapshot, files: [{ path: "Sources/New.ada", data: "Lw==" }] },
    config,
    false,
  );
  h.reply(h.sent[0]);
  await assert.rejects(first, { name: "AbortError" });
  await new Promise(setImmediate);
  assert.equal(h.preview.ready, false);
  assert.equal(h.sent.length, 2);
  h.reply(h.sent[1]);
  await last;
  assert.equal(h.preview.ready, true);
  assert.equal(h.frames.length, 1);
  h.preview.stop();
});
test("foreign source and origin messages cannot acknowledge scene rendering", async () => {
  const h = harness(false),
    loaded = h.preview.load(snapshot, config, true);
  await new Promise(setImmediate);
  const request = h.sent[0];
  h.reply(request, { origin: "https://untrusted.example" });
  h.reply(request, { source: {} });
  assert.equal(h.preview.pending.size, 1);
  assert.equal(h.preview.ready, false);
  h.reply(request);
  await loaded;
  assert.equal(h.preview.pending.size, 0);
  h.preview.stop();
});
test("closing a project cancels rendering and rejects late responses", async () => {
  const h = harness(false),
    loaded = h.preview.load(snapshot, config, true);
  loaded.catch(() => {});
  await new Promise(setImmediate);
  h.preview.stop();
  await assert.rejects(loaded, { name: "AbortError" });
  h.reply(h.sent[0]);
  assert.equal(h.preview.ready, false);
  assert.equal(h.preview.frame, null);
});

test("startup failures require the isolated frame and reject pending and subsequent loads", async () => {
  const h = harness(false),
    loaded = h.preview.load(snapshot, config, true);
  loaded.catch(() => {});
  await new Promise(setImmediate);
  const event = {
    source: h.preview.frame.contentWindow,
    origin: "http://127.0.0.1:18444",
    data: {
      protocol: "ada-studio-preview-v1",
      event: "startup-error",
      message: "Missing Player module",
    },
  };
  h.dispatch({ ...event, source: {} });
  h.dispatch({ ...event, origin: "https://untrusted.example" });
  assert.equal(h.preview.pending.size, 1);
  h.dispatch(event);
  await assert.rejects(loaded, /Missing Player module/);
  assert.equal(h.preview.pending.size, 0);
  await assert.rejects(
    h.preview.load(snapshot, config, true),
    /Missing Player module/,
  );
  h.preview.stop();
  assert.equal(h.preview.startupError, null);
});

test("asynchronous runtime diagnostics require the current source, origin and accepted revision", async () => {
  const h = harness(),
    diagnostics = [];
  h.preview.onDiagnostics = (value) => diagnostics.push(value);
  await h.preview.load(snapshot, config, false);
  const event = {
    source: h.preview.frame.contentWindow,
    origin: "http://127.0.0.1:18444",
    data: {
      protocol: "ada-studio-preview-v1",
      event: "runtime-diagnostics",
      revision: h.preview.editorRevision,
      diagnostics: ["Invalid script field"],
    },
  };
  h.dispatch({ ...event, source: {} });
  h.dispatch({ ...event, origin: "http://untrusted.example" });
  h.dispatch({ ...event, data: { ...event.data, revision: "old" } });
  assert.equal(diagnostics.length, 0);
  h.dispatch(event);
  assert.deepEqual(diagnostics, [["Invalid script field"]]);
  h.preview.stop();
  h.dispatch(event);
  assert.equal(diagnostics.length, 1);
});
