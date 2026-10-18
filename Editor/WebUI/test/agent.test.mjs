import test from "node:test";
import assert from "node:assert/strict";
import { runAgent, runTool } from "../src/agent.js";
import { Document, template, file, scene } from "../src/documents.js";
import { decode } from "../src/platform.js";

test("agent file and scene tools enter the same document undo history", async () => {
  const document = new Document(template(2));
  let edits = 0;
  const studio = {
    document,
    get snapshot() {
      return document.snapshot;
    },
    get scene() {
      return scene(document.snapshot);
    },
    changed() {
      edits++;
    },
    editScene(fn) {
      document.scene(fn);
      edits++;
    },
  };
  await runTool(studio, "editor_file_write", {
    path: "Sources/Agent.ada",
    content: "// test",
  });
  const player = studio.scene.entities.find((e) => e.name === "Player");
  await runTool(studio, "editor_scene_set", {
    entity: player.id,
    component: "AdaTransform.Transform",
    field: "position",
    value: [7, 0, 0],
  });
  assert.equal(edits, 2);
  assert.equal(
    studio.scene.entities.find((e) => e.id === player.id).components[
      "AdaTransform.Transform"
    ].position[0],
    7,
  );
  document.undo();
  assert.equal(
    studio.scene.entities.find((e) => e.id === player.id).components[
      "AdaTransform.Transform"
    ].position[0],
    0,
  );
  assert.equal(
    decode(file(studio.snapshot, "Sources/Agent.ada").data),
    "// test",
  );
  document.undo();
  assert.equal(file(studio.snapshot, "Sources/Agent.ada"), undefined);
  await assert.rejects(
    runTool(studio, "editor_publish", {}),
    /Недоступный инструмент/,
  );
  await assert.rejects(
    runTool(studio, "editor_file_write", {
      path: "../escape.ada",
      content: "bad",
    }),
    /Недопустимый/,
  );
});
test("agent clears running state even when appending to a full conversation fails", async () => {
  let saved = false,
    failure;
  const studio = {
    providerID: "fixture",
    model: { tools: true },
    billingMode: "ada",
    document: {},
    snapshot: { messages: [] },
    append() {
      throw new Error("История чата превышает лимит проекта");
    },
    emit() {},
    fail(e) {
      failure = e.message;
    },
    async save(checkpoint) {
      saved = checkpoint;
    },
  };
  await runAgent(studio, "Обнови игру");
  assert.equal(studio.running, false);
  assert.equal(studio.agent, null);
  assert.equal(saved, true);
  assert.match(failure, /История/);
});
