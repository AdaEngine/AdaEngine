import assert from "node:assert/strict";
import test from "node:test";
import { Document, template } from "../src/documents.js";
import { Studio } from "../src/studio.js";
function harness() {
  const studio = Object.create(Studio.prototype);
  studio.document = new Document(template(3));
  studio.preview = { host: {}, hasFrame: true, load: async () => {} };
  studio.editorCommand = async () => {};
  studio.emit = () => {};
  studio.renderedGeneration = -1;
  return studio;
}
test("accepted and rejected loads report their exact source generation without treating saved bytes as runtime acceptance", async () => {
  const s = harness();
  await s.syncViewport(true);
  assert.equal(s.runtimeValidation.valid, true);
  assert.equal(s.runtimeValidation.generation, 0);
  assert.match(s.runtimeValidation.sceneRevision, /^[a-f0-9]{64}$/);
  assert.equal(s.runtimeValidation.editMode, true);
  s.document.write("Sources/Bad.ada", "bad source");
  s.preview.load = async () => {
    throw new Error("Sources/Bad.ada:3: Undefined value");
  };
  await assert.rejects(s.syncViewport(true), /Undefined value/);
  assert.equal(s.runtimeValidation.valid, false);
  assert.equal(s.runtimeValidation.generation, 1);
  assert.equal(s.renderedGeneration, 0);
  assert.equal(s.preview.hasFrame, true);
  assert.equal(s.document.undoStack.length, 1);
  assert.match(s.runtimeValidation.diagnostics[0].message, /Bad.ada/);
});
test("late success and error responses cannot overwrite diagnostics for a newer document generation or another project", async () => {
  for (const reject of [false, true]) {
    for (const replace of [false, true]) {
      const s = harness();
      let finish, fail;
      s.preview.load = () =>
        new Promise((resolve, reject) => {
          finish = resolve;
          fail = reject;
        });
      const request = s.syncViewport(true);
      while (!finish) await new Promise((resolve) => setImmediate(resolve));
      if (replace) s.document = new Document(template(2));
      else s.document.write("Docs/User.txt", "Newer edit");
      const current = { valid: true, marker: "current" };
      s.runtimeValidation = current;
      s.viewportError = "Current diagnostics";
      if (reject) fail(new Error("Old response"));
      else finish();
      if (reject) await assert.rejects(request, /Old response/);
      else await request;
      assert.equal(s.runtimeValidation, current);
      assert.equal(s.renderedGeneration, -1);
      assert.equal(s.viewportError, "Current diagnostics");
    }
  }
});

test("gameplay input reports revision and rejects a late result after source edits", async () => {
  const { runTool } = await import("../src/agent.js");
  const s = harness();
  s.playing = false;
  await assert.rejects(
    runTool(s, "editor_play_input", { key: "Space", phase: "press" }),
    /Start Play/,
  );
  s.playing = true;
  s.preview.ready = true;
  s.renderedGeneration = 0;
  s.preview.message = async (_, payload) =>
    payload?.name === "runtime-diagnostics"
      ? { diagnostics: [] }
      : { ok: true };
  const accepted = await runTool(s, "editor_play_input", {
    key: "Space",
    phase: "press",
  });
  assert.equal(accepted.ok, true);
  assert.equal(accepted.generation, 0);
  assert.match(accepted.sceneRevision, /^[a-f0-9]{64}$/);
  let finish;
  s.preview.message = (type) =>
    type === "input"
      ? new Promise((resolve) => {
          finish = resolve;
        })
      : Promise.resolve({ diagnostics: [] });
  const pending = runTool(s, "editor_play_input", {
    key: "Space",
    phase: "press",
  });
  while (!finish) await new Promise((resolve) => setImmediate(resolve));
  s.document.write("Sources/New.ada", "// newer source");
  finish({ ok: true });
  await assert.rejects(pending, /Project changed/);
});

test("long Unicode runtime output stays within the model context budget and retains recent errors", async () => {
  const { boundedRuntimeLines } = await import("../src/runtime-output.js");
  const output = Array.from(
    { length: 200 },
    (_, i) => i + ":" + "界🙂".repeat(5000),
  );
  output.push("Newest failure: Sources/Player.ada");
  const bounded = boundedRuntimeLines(output);
  assert.ok(bounded.length <= 40);
  assert.ok(
    bounded.reduce((n, line) => n + new TextEncoder().encode(line).length, 0) <=
      12000,
  );
  assert.equal(bounded.at(-1), output.at(-1));
});

test("the retained frame of a rejected candidate cannot be presented as current gameplay evidence", async () => {
  const { runTool } = await import("../src/agent.js");
  const s = harness();
  s.playing = true;
  s.providers = [{ id: "fixture", models: [{ id: "vision", vision: true }] }];
  s.providerID = "fixture";
  s.modelID = "vision";
  s.preview.ready = true;
  s.renderedGeneration = 0;
  s.document.write("Sources/Invalid.ada", "broken current source");
  let called = false;
  s.preview.message = async () => {
    called = true;
    return { ok: true };
  };
  for (const name of ["editor_play_input", "editor_play_capture"])
    await assert.rejects(
      runTool(s, name, { key: "Space", phase: "press" }),
      /scene has not loaded yet/,
    );
  assert.equal(called, false);
});
