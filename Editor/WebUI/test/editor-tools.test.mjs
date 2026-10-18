import test from "node:test";
import assert from "node:assert/strict";
import { Studio } from "../src/studio.js";
import { Document, template } from "../src/documents.js";

function workspace() {
  const s = Object.create(Studio.prototype);
  s.document = new Document(template(3));
  s.view = "editor";
  s.playing = false;
  s.running = false;
  s.renderedGeneration = 0;
  s.emit = () => {};
  s.changed = () => {};
  s.preview = { ready: false };
  return s;
}
test("a completed gizmo drag is exactly one document undo and does not move authored cameras", () => {
  const s = workspace(),
    player = s.scene.entities.find((e) => e.name === "Player");
  const before = structuredClone(s.snapshot),
    camera = structuredClone(s.scene.entities.find((e) => e.name === "Камера"));
  const transform = {
    position: [3, 1, -2],
    rotation: [0, 0, 0, 1],
    scale: [2, 1, 1],
  };
  s.editorEvent("transform", { id: player.id, transform });
  assert.equal(s.document.undoStack.length, 1);
  assert.deepEqual(
    s.scene.entities.find((e) => e.id === player.id).components[
      "AdaTransform.Transform"
    ],
    transform,
  );
  assert.deepEqual(
    s.scene.entities.find((e) => e.id === camera.id),
    camera,
  );
  s.document.undo();
  assert.deepEqual(s.snapshot, before);
  s.document.redo();
  assert.deepEqual(
    s.scene.entities.find((e) => e.id === player.id).components[
      "AdaTransform.Transform"
    ],
    transform,
  );
});
test("stale or agent-overlapping drags reload the scene instead of overwriting a newer edit", async () => {
  const s = workspace();
  let reloads = 0;
  s.syncViewport = async () => {
    reloads++;
  };
  const player = s.scene.entities.find((e) => e.name === "Player");
  s.document.scene(
    (value) =>
      (value.entities.find((e) => e.id === player.id).name = "Agent revision"),
  );
  const before = structuredClone(s.snapshot);
  await s.editorEvent("transform", {
    id: player.id,
    transform: {
      position: [9, 0, 0],
      rotation: [0, 0, 0, 1],
      scale: [1, 1, 1],
    },
  });
  assert.equal(reloads, 1);
  assert.deepEqual(s.snapshot, before);
});
test("duplicate retains a subtree, transforms and references to its external parent", () => {
  const s = workspace(),
    parent = s.scene.entities.find((e) => e.name === "Player");
  s.document.scene((value) =>
    value.entities.push({
      ...structuredClone(parent),
      id: "child",
      name: "Child",
      parent: parent.id,
    }),
  );
  s.selected = parent.id;
  s.duplicateEntity();
  const copy = s.scene.entities.find((e) => e.id === s.selected),
    child = s.scene.entities.find(
      (e) => e.name === "Child" && e.id !== "child",
    );
  assert.ok(copy);
  assert.ok(child);
  assert.equal(child.parent, copy.id);
  assert.notEqual(copy.id, parent.id);
  assert.deepEqual(copy.components, parent.components);
  s.document.undo();
  assert.equal(s.scene.entities.length, 28);
});
