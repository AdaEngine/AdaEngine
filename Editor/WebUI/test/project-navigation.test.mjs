import test from "node:test";
import assert from "node:assert/strict";
import { Studio } from "../src/studio.js";
import { template, file } from "../src/documents.js";
import { decode, recovery } from "../src/platform.js";

function harness(t) {
  const drafts = new Map(),
    listeners = new Map(),
    storage = new Map();
  let diskError = false,
    offline = false;
  globalThis.window = {
    addEventListener: (type, fn) => listeners.set(type, fn),
  };
  globalThis.localStorage = {
    setItem: (key, value) => storage.set(key, value),
    getItem: (key) => storage.get(key),
  };
  globalThis.indexedDB = {
    open() {
      const request = {};
      queueMicrotask(() => {
        request.result = {
          close() {},
          transaction() {
            const tx = { error: new Error("Storage quota exceeded") };
            const complete = (value, operation) => {
              const result = { result: value };
              queueMicrotask(() => {
                if (diskError) tx.onabort();
                else {
                  operation?.();
                  tx.oncomplete();
                }
              });
              return result;
            };
            tx.objectStore = () => ({
              get: (key) => complete(structuredClone(drafts.get(key))),
              put: (value, key) =>
                complete(key, () => drafts.set(key, structuredClone(value))),
              delete: (key) => complete(undefined, () => drafts.delete(key)),
            });
            return tx;
          },
        };
        request.onsuccess();
      });
      return request;
    },
  };
  const records = new Map([
    ["first", { id: "first", revision: 1, snapshot: template(3, "First") }],
    ["second", { id: "second", revision: 1, snapshot: template(2, "Second") }],
  ]);
  globalThis.fetch = async (path, options) => {
    if (offline) throw new Error("Network unavailable");
    if (path === "/v1/workspaces") return Response.json([...records.values()]);
    const id = path.split("/").at(-1);
    if (options.method === "PUT") {
      const body = JSON.parse(options.body),
        current = records.get(id);
      assert.equal(body.expectedRevision, current.revision);
      records.set(id, {
        ...current,
        snapshot: body.snapshot,
        revision: current.revision + 1,
      });
    }
    return Response.json(records.get(id));
  };
  const s = new Studio();
  s.account = { id: "owner" };
  s.install(records.get("first"), records.get("first").snapshot);
  t.after(() => clearTimeout(s.timer));
  return {
    s,
    drafts,
    records,
    listeners,
    disk: (value) => (diskError = value),
    offline: (value) => (offline = value),
  };
}

test("Home and project sections retain the document, undo, selection and Player", (t) => {
  const { s } = harness(t),
    doc = s.document,
    preview = s.preview;
  s.selected = s.scene.entities[0].id;
  const selected = s.selected;
  s.writeCode("// persistent edit");
  for (const view of ["assets", "code", "assistant", "editor"]) {
    s.assetPanel = true;
    s.navigate(view);
    assert.equal(s.view, view);
    assert.equal(s.assetPanel, false);
  }
  s.home();
  assert.equal(s.view, "overview");
  assert.equal(s.document, doc);
  assert.equal(s.preview, preview);
  assert.equal(s.selected, selected);
  assert.equal(s.document.undoStack.length, 1);
  assert.equal(
    decode(file(s.snapshot, s.activeFile).data),
    "// persistent edit",
  );
  s.undo();
  assert.notEqual(
    decode(file(s.snapshot, s.activeFile).data),
    "// persistent edit",
  );
});

test("leaving waits for cloud save; Continue and selecting the open project preserve undo", async (t) => {
  const { s, records } = harness(t),
    doc = s.document;
  s.writeCode("// save before leaving");
  await s.browseProjects();
  assert.equal(s.projectBrowser, true);
  assert.equal(records.get("first").revision, 2);
  assert.equal(
    decode(file(records.get("first").snapshot, s.activeFile).data),
    "// save before leaving",
  );
  await s.open(records.get("first"));
  assert.equal(s.document, doc);
  assert.equal(s.projectBrowser, false);
  assert.equal(s.document.undoStack.length, 1);
  await s.open(records.get("second"));
  await s.open(records.get("first"));
  assert.equal(
    decode(file(s.snapshot, s.activeFile).data),
    "// save before leaving",
  );
});

test("project list stays closed until in-flight edits are saved too", async (t) => {
  const { s, records } = harness(t);
  const send = globalThis.fetch;
  let release, arrived;
  const waiting = new Promise((resolve) => {
    arrived = resolve;
  });
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  globalThis.fetch = async (path, options) => {
    if (options.method === "PUT") {
      arrived();
      await gate;
    }
    return send(path, options);
  };
  s.writeCode("// first edit");
  const leaving = s.browseProjects();
  await waiting;
  assert.equal(s.projectBrowser, false);
  s.writeCode("// edited during save");
  release();
  await leaving;
  assert.equal(s.projectBrowser, true);
  assert.equal(records.get("first").revision, 3);
  assert.equal(
    decode(file(records.get("first").snapshot, s.activeFile).data),
    "// edited during save",
  );
});

test("failed cloud save keeps the project open until an explicit durable local exit", async (t) => {
  const { s, offline, drafts } = harness(t),
    doc = s.document;
  s.writeCode("// offline edit");
  offline(true);
  await s.browseProjects();
  assert.equal(s.projectBrowser, false);
  assert.match(s.leavePrompt, /Network/);
  assert.equal(s.document, doc);
  await s.browseProjects(true);
  assert.equal(s.projectBrowser, true);
  assert.equal(s.leavePrompt, "");
  assert.equal(
    decode(file(drafts.get("owner:first").snapshot, s.activeFile).data),
    "// offline edit",
  );
});

test("local storage failure never dismisses the project or claims a safe exit", async (t) => {
  const { s, offline, disk } = harness(t);
  s.writeCode("// keep me");
  offline(true);
  await s.browseProjects();
  disk(true);
  await s.browseProjects(true);
  assert.equal(s.projectBrowser, false);
  assert.match(s.leavePrompt, /quota/);
  assert.equal(decode(file(s.snapshot, s.activeFile).data), "// keep me");
});

test("reopening restores the explicitly saved local draft and uploads it after reconnect", async (t) => {
  const { s, offline, records } = harness(t);
  s.writeCode("// recover me");
  offline(true);
  await s.browseProjects(true);
  offline(false);
  s.install(records.get("second"), records.get("second").snapshot);
  await s.open(records.get("first"));
  assert.equal(decode(file(s.snapshot, s.activeFile).data), "// recover me");
  await s.save();
  assert.equal(await recovery("load", "owner", "first"), null);
  assert.equal(
    decode(file(records.get("first").snapshot, s.activeFile).data),
    "// recover me",
  );
});

test("tab close protection and active agent guards do not prevent switching project sections", async (t) => {
  const { s, listeners } = harness(t);
  let blocked = 0;
  const e = {
    preventDefault() {
      blocked++;
    },
  };
  listeners.get("beforeunload")(e);
  assert.equal(blocked, 0);
  s.writeCode("// unsaved");
  listeners.get("beforeunload")(e);
  assert.equal(blocked, 1);
  s.running = true;
  s.home();
  assert.equal(s.view, "overview");
  await assert.rejects(s.browseProjects(), /ассистента/);
  await assert.rejects(s.create(2), /ассистента/);
});
