import assert from "node:assert/strict";
import test from "node:test";
import {
  parseSceneValue,
  stringifySceneValue,
  sceneToolJSON,
} from "../src/scene-codec.js";
import {
  Document,
  template,
  scene,
  file,
  scenePath,
} from "../src/documents.js";
import { decode } from "../src/platform.js";

test("scene integers survive native JSON/YAML parsing, edits, Undo and reopening without rounding", () => {
  const document = new Document(template(2));
  const maximum = 18_446_744_073_709_551_615n;
  document.scene((value) => {
    value.entities[0].components["Fixture.Mask"] = {
      mask: maximum,
      label: maximum.toString(),
    };
  });
  const encoded = decode(
    file(document.snapshot, scenePath(document.snapshot)).data,
  );
  assert.match(encoded, /"mask": 18446744073709551615/);
  let payload = scene(document.snapshot).entities[0].components["Fixture.Mask"];
  assert.equal(payload.mask, maximum);
  assert.equal(payload.label, maximum.toString());
  document.scene((value) => {
    value.entities[0].name = "Changed";
  });
  document.undo();
  payload = scene(new Document(structuredClone(document.snapshot)).snapshot)
    .entities[0].components["Fixture.Mask"];
  assert.equal(payload.mask, maximum);
  assert.equal(
    typeof scene(document.snapshot).entities[0].components[
      "AdaTransform.Transform"
    ].position[0],
    "number",
  );
  assert.equal(parseSceneValue("mask: 18446744073709551615").mask, maximum);
  assert.equal(JSON.parse(sceneToolJSON(payload)).mask, maximum.toString());
});

test("ordinary JSON output remains compatible while native signed/unsigned literals and strings stay distinct", () => {
  const value = {
    text: "12345678901234567890",
    vector: [0, 1.5, true, null],
    nested: { enabled: false },
  };
  assert.equal(stringifySceneValue(value, 2), JSON.stringify(value, null, 2));
  const original = { max: 9223372036854775807n, min: -9223372036854775808n };
  assert.deepEqual(parseSceneValue(stringifySceneValue(original)), original);
  const cycle = {};
  cycle.self = cycle;
  assert.throws(() => stringifySceneValue(cycle), /Circular scene value/);
});
