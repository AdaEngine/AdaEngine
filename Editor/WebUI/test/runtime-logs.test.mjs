import test from "node:test";
import assert from "node:assert/strict";
import { RuntimeLogBuffer } from "../src/runtime-logs.js";

test("polls preserve repeated output, reconcile rollover and do not re-add cleared logs", () => {
  const buffer = new RuntimeLogBuffer(),
    source = {};
  assert.equal(buffer.update(["ready", "tick", "tick"], source), true);
  assert.deepEqual(
    buffer.lines.map((line) => line.text),
    ["ready", "tick", "tick"],
  );
  assert.equal(buffer.update(["ready", "tick", "tick"], source), false);
  buffer.clear();
  buffer.update(["ready", "tick", "tick"], source);
  assert.equal(buffer.lines.length, 0);
  buffer.update(["tick", "tick", "error"], source);
  assert.deepEqual(
    buffer.lines.map((line) => line.text),
    ["error"],
  );
  buffer.update(["error", "ready"], source);
  assert.deepEqual(
    buffer.lines.map((line) => line.text),
    ["error", "ready"],
  );
});

test("a replacement Player starts a new cursor and retained output stays bounded", () => {
  const buffer = new RuntimeLogBuffer();
  buffer.update(["ready"], {});
  buffer.update(["ready"], {});
  assert.equal(buffer.lines.length, 2);
  const source = {};
  for (let step = 0; step < 12; step++)
    buffer.update(
      Array.from({ length: 200 }, (_, i) => `${step}:${i}`),
      source,
    );
  assert.equal(buffer.lines.length, 1000);
  assert.equal(new Set(buffer.lines.map((line) => line.id)).size, 1000);
  assert.equal(buffer.lines.at(-1).text, "11:199");
  assert.throws(() => buffer.update([{ unexpected: true }], source));
});
