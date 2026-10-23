import test from "node:test";
import assert from "node:assert/strict";
import { zipSync, unzipSync, strToU8 } from "fflate";
import {
  Document,
  template,
  scene,
  scenePath,
  file,
  metadata,
  exportZIP,
  importZIP,
  textFile,
  validate,
  validPath,
} from "../src/documents.js";
import { decode, encode } from "../src/platform.js";

test("2D and 3D templates satisfy the source snapshot contract", () => {
  for (const dimension of [2, 3]) {
    const snapshot = template(dimension);
    validate(snapshot);
    assert.equal(
      metadata(snapshot).runtime.plugins.preset,
      `game${dimension}d`,
    );
    assert.ok(scene(snapshot).entities.find((e) => e.name === "Player"));
  }
});
test("conversation saves do not invalidate the engine scene", () => {
  const doc = new Document(template(2));
  doc.append({ role: "user", content: "Hello" });
  assert.equal(doc.generation, 1);
  assert.equal(doc.contentGeneration, 0);
  doc.write("Sources/Game.ada", "// Edit");
  assert.equal(doc.contentGeneration, 1);
  doc.undo();
  assert.equal(doc.contentGeneration, 2);
  doc.redo();
  assert.equal(doc.contentGeneration, 3);
});
test("manual and agent edits share undo, while conversation survives undo and redo", () => {
  const doc = new Document(template(3));
  doc.scene(
    (s) =>
      (s.entities.find((e) => e.name === "Player").components[
        "AdaTransform.Transform"
      ].position[0] = 4),
  );
  doc.append({ role: "user", content: "Передвинь игрока" });
  doc.write("Sources/Behavior.ada", "// agent edit");
  doc.undo();
  assert.equal(file(doc.snapshot, "Sources/Behavior.ada"), undefined);
  doc.undo();
  assert.equal(
    scene(doc.snapshot).entities.find((e) => e.name === "Player").components[
      "AdaTransform.Transform"
    ].position[0],
    0,
  );
  assert.equal(doc.snapshot.messages[0].content, "Передвинь игрока");
  doc.redo();
  doc.redo();
  assert.equal(
    decode(file(doc.snapshot, "Sources/Behavior.ada").data),
    "// agent edit",
  );
  assert.equal(doc.snapshot.messages.length, 1);
});
test("invalid scene edits are atomic and do not enter undo", () => {
  const doc = new Document(template(3)),
    before = structuredClone(doc.snapshot);
  assert.throws(
    () => doc.scene((s) => (s.entities[0].parent = s.entities[0].id)),
    /hierarchy/,
  );
  assert.deepEqual(doc.snapshot, before);
  assert.equal(doc.undoStack.length, 0);
  assert.throws(() => doc.write("../escape.ada", "bad"), /Invalid/);
  assert.deepEqual(doc.snapshot, before);
});
test("YAML scenes from native Studio remain editable after DOM transactions", () => {
  const snapshot = template(2);
  file(snapshot, scenePath(snapshot)).data = encode(
    "format: ada.scene\nschemaVersion: 1\nscene:\n  name: YAML\nentities:\n  - id: camera\n    name: Camera\n    parent: null\n    components:\n      AdaTransform.Transform:\n        position: [0, 1, 2]\n",
  );
  const doc = new Document(snapshot);
  doc.scene((s) => (s.entities[0].name = "Камера"));
  assert.equal(scene(doc.snapshot).entities[0].name, "Камера");
});
test("ZIP round trip creates a new identity and excludes auth settings and chat", () => {
  const snapshot = template(3),
    meta = metadata(snapshot);
  meta.ai = { apiKey: "secret-proof" };
  meta.editor = { token: "secret-proof" };
  meta.run = { credential: "secret-proof" };
  meta.paths.build = "C:/private";
  file(snapshot, ".ada/project.json").data = encode(JSON.stringify(meta));
  snapshot.messages.push({ role: "user", content: "private chat" });
  const zip = exportZIP(snapshot),
    entries = unzipSync(zip),
    imported = importZIP(zip);
  assert.equal(Object.keys(entries).length, snapshot.files.length);
  assert.equal(
    new TextDecoder()
      .decode(entries[".ada/project.json"])
      .includes("secret-proof"),
    false,
  );
  assert.notEqual(metadata(imported).project.id, meta.project.id);
  assert.deepEqual(imported.messages, []);
  assert.equal(metadata(imported).paths.build, undefined);
  validate(imported);
});
test("stored and deflated archives are accepted, CRC-corrupt archives rejected", () => {
  const snapshot = template(2);
  for (const level of [0, 6]) {
    const zip = zipSync(
      Object.fromEntries(
        snapshot.files.map((f) => [f.path, strToU8(decode(f.data))]),
      ),
      { level },
    );
    assert.equal(importZIP(zip).title, snapshot.title);
    // Corrupt one CRC in the central directory without changing compressed bytes.
    const corrupt = zip.slice(),
      view = new DataView(corrupt.buffer);
    let cursor = 0;
    while (view.getUint32(cursor, true) !== 0x02014b50) cursor++;
    corrupt[cursor + 16] ^= 1;
    assert.throws(() => importZIP(corrupt), /Invalid ZIP/);
  }
});
test("ZIP import rejects traversal, executable files, duplicates, oversize entries and truncation", () => {
  for (const name of [
    "../escape.ada",
    "Assets/../../escape.png",
    "Assets/index.html",
    "Sources/run.swift",
    "/absolute.png",
  ]) {
    assert.equal(validPath(name), false);
    assert.throws(() => importZIP(zipSync({ [name]: strToU8("bad") })));
  }
  assert.throws(
    () =>
      importZIP(
        zipSync({ "Assets/a.png": new Uint8Array(16 * 1024 * 1024 + 1) }),
      ),
    /size/,
  );
  assert.throws(
    () =>
      importZIP(
        zipSync({ "Assets/a.png": strToU8("a"), "Assets/A.png": strToU8("b") }),
      ),
    /path/,
  );
  assert.throws(() => importZIP(exportZIP(template(3)).slice(0, -4)));
});
test("required metadata and last AdaScript source cannot be deleted", () => {
  const doc = new Document(template(2));
  assert.throws(() =>
    doc.edit(
      (s) => (s.files = s.files.filter((f) => f.path !== ".ada/project.json")),
    ),
  );
  assert.throws(() =>
    doc.edit(
      (s) => (s.files = s.files.filter((f) => !f.path.startsWith("Sources/"))),
    ),
  );
  assert.equal(doc.undoStack.length, 0);
});
