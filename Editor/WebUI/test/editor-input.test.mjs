import test from "node:test";
import assert from "node:assert/strict";
import { StudioEditor } from "../../../Plugins/AdaWebExportPlugin/Runtime/studio-editor.js";
import * as M from "../../../Plugins/AdaWebExportPlugin/Runtime/studio-editor-math.js";

function viewport() {
  globalThis.innerWidth = 1000;
  globalThis.innerHeight = 600;
  globalThis.document = {
    elementFromPoint: () => ({ closest: () => ({ getAttribute: () => "0" }) }),
  };
  const editor = Object.create(StudioEditor.prototype),
    events = [],
    commands = [];
  const matrix = [...M.identity],
    camera = [...M.identity];
  camera[14] = -10;
  Object.assign(editor, {
    enabled: true,
    revision: "scene-1",
    selected: "object",
    tool: "move",
    local: false,
    snapping: false,
    keys: new Set(),
    svg: { hasPointerCapture: () => false },
    draw() {},
    notify: (...event) => events.push(event),
    state: {
      camera,
      projection: [
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        100 / 99.9,
        1,
        0,
        0,
        -10 / 99.9,
        0,
      ],
      entities: [
        {
          id: "object",
          matrix,
          parent: [...M.identity],
          position: [0, 0, 0],
          rotation: [0, 0, 0, 1],
          scale: [1, 1, 1],
          min: [-0.5, -0.5, -0.5],
          max: [0.5, 0.5, 0.5],
        },
      ],
    },
    native(value) {
      commands.push(value);
      if (value.type === "transform") {
        const e = this.state.entities[0];
        Object.assign(e, structuredClone(value.transform));
        e.matrix = [...M.identity];
        e.matrix.splice(12, 3, ...e.position);
      }
      return this.state;
    },
  });
  const input = (phase, x = 270, more = {}) =>
    editor.input({
      revision: "scene-1",
      phase,
      x,
      y: 150,
      width: 500,
      height: 300,
      button: 0,
      pointerId: 1,
      ...more,
    });
  return { editor, events, commands, input };
}
test("captured input maps Studio coordinates to engine coordinates and commits one gesture", () => {
  const h = viewport();
  h.input("down");
  for (const x of [275, 280, 285, 290, 295]) h.input("move", x, { button: -1 });
  assert.equal(h.events.length, 0);
  h.input("up", 295);
  assert.equal(h.events.length, 1);
  assert.equal(h.events[0][0], "transform");
  assert.ok(Math.abs(h.events[0][1].transform.position[0] - 1) < 1e-6);
  assert.equal(h.events[0][1].revision, "scene-1");
});
test("pointer cancellation rolls back live edits without a document commit", () => {
  const h = viewport();
  h.input("down");
  h.input("move", 295, { button: -1 });
  h.input("cancel");
  assert.equal(h.events.length, 0);
  assert.deepEqual(h.editor.state.entities[0].position, [0, 0, 0]);
  assert.equal(h.editor.drag, null);
});
test("input rejects invalid coordinates and ignores stale scenes or Play mode", () => {
  const h = viewport();
  assert.throws(() => h.input("down", Infinity), /Invalid editor pointer/);
  assert.throws(
    () => h.input("down", 270, { button: 8 }),
    /Invalid editor pointer/,
  );
  assert.deepEqual(h.input("down", 270, { revision: "old" }), { ok: false });
  h.editor.enabled = false;
  assert.deepEqual(h.input("down"), { ok: false });
  assert.equal(h.commands.length, 0);
});
test("right-drag looks around and never commits a scene transform", () => {
  const h = viewport();
  globalThis.requestAnimationFrame = () => 0;
  h.input("down", 270, { button: 2 });
  h.input("move", 295, { button: -1 });
  h.input("up", 295, { button: 2 });
  const command = h.commands.find((c) => c.type === "camera");
  assert.ok(command);
  assert.ok(command.rotation[1] > 0);
  assert.equal(h.events.length, 0);
  assert.equal(h.editor.drag, null);
});
