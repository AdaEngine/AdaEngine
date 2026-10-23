import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { browserExamples } from "../scripts/browser-examples.mjs";
import { Document, scene, metadata, validPath } from "../src/documents.js";
import { encode } from "../src/platform.js";
import { knowledge } from "../src/knowledge.js";
const contract = JSON.parse(
  await readFile(new URL("../assets/agent-contract.json", import.meta.url)),
);
const examples = browserExamples(contract);
globalThis.fetch = async () => Response.json({ contract, examples });

test("all browser examples are complete portable projects, with only supported components and no missing binary assets", () => {
  assert.equal(examples.length, 4);
  for (const e of examples) {
    const snapshot = {
      formatVersion: 1,
      title: e.id,
      files: [
        ...Object.entries(e.files).map(([path, value]) => ({
          path,
          data: encode(value),
        })),
        ...Object.entries(e.assets).map(([path, data]) => ({ path, data })),
      ],
      messages: [],
    };
    const document = new Document(snapshot);
    assert.ok(document.snapshot.files.every((f) => validPath(f.path)));
    assert.ok(
      scene(document.snapshot).entities.every(
        (entity) =>
          !entity.components["AdaUI.UIComponent"] &&
          !entity.components["AdaScene.ScriptableComponents"],
      ),
    );
    assert.equal(metadata(document.snapshot).runtime.entry.view, undefined);
  }
  const runner = examples.find((e) => e.id === "side-scroller-3d");
  for (const cue of ["flap", "score", "crash"]) {
    const bytes = Buffer.from(
      runner.assets["Assets/Audio/" + cue + ".wav"],
      "base64",
    );
    assert.equal(bytes.subarray(0, 4).toString(), "RIFF");
    assert.equal(bytes.subarray(8, 12).toString(), "WAVE");
    assert.ok(bytes.length > 44);
  }
  assert.equal(runner.files["Sources/Systems/HudSystem.ada"], undefined);
  const keyboard = examples.find((e) => e.id === "keyboard-movement");
  assert.match(
    keyboard.files["Sources/Game.ada"],
    /@query\(PlayerState, Transform\)/,
  );
});
test("flappy retrieval finds the complete runner and read returns bounded asset metadata instead of base64 in context", async () => {
  const result = await knowledge({}, "editor_examples_list", {
    query: "flappy",
  });
  assert.equal(result.examples[0].id, "side-scroller-3d");
  assert.equal(result.examples[0].assets.length, 3);
  const read = await knowledge({}, "editor_examples_read", {
    id: result.examples[0].id,
  });
  assert.equal(read.importTool, "editor_examples_apply");
  assert.equal(read.assets.length, 3);
  assert.ok(read.assets.every((asset) => asset.bytes > 44 && !asset.data));
  assert.ok(read.files[".ada/project.json"]);
  assert.ok(read.files["Assets/Scenes/Main.ascn"]);
});
