import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  Document,
  template,
  scene,
  scenePath,
  file,
} from "../src/documents.js";
import { normalizeScene } from "../src/authoring-validation.js";
import { runTool } from "../src/agent.js";
import { sceneRevision } from "../src/scene-tools.js";
import { decode } from "../src/platform.js";

const contract = JSON.parse(
  await readFile(new URL("../assets/agent-contract.json", import.meta.url)),
);
globalThis.fetch = async () => Response.json({ contract });
function studio(dimension = 3) {
  const s = {
    document: new Document(template(dimension)),
    changed() {},
    preview: {
      frame: {},
      async message(_, payload) {
        if (payload.name === "inspect-sources")
          return {
            schemas: [
              {
                typeName: "game.player",
                kind: "component",
                fields: [{ name: "speed", path: ["speed"], kind: "float" }],
                defaultPayload: { speed: 120 },
              },
            ],
          };
        assert.equal(payload.name, "validate-component-values");
        return { valid: true };
      },
    },
  };
  Object.defineProperty(s, "snapshot", { get: () => s.document.snapshot });
  Object.defineProperty(s, "scene", { get: () => scene(s.snapshot) });
  return s;
}
test("builtin fields, dependencies, resource paths, enum cases and vector lengths reject before a document transaction", async () => {
  const cases = [
    ["AdaTransform.Transform", { position: [1, 2] }, "component.value"],
    ["AdaTransform.Transform", { positon: [1, 2, 3] }, "component.field"],
    ["AdaScene.Mesh3DComponent", { mesh: "Cone" }, "component.value"],
    ["AdaScene.Mesh3DComponent", { size: -1 }, "component.range"],
    ["AdaScene.Mesh3DComponent", { size: 100001 }, "component.range"],
    ["AdaRender.Camera", { renderOrder: 2147483648 }, "component.integer"],
    [
      "AdaScene.Model3DSource",
      { source: "@res://missing.glb" },
      "component.asset",
    ],
    ["AdaAudio.AudioSource", { source: "" }, "component.asset"],
    ["Nonexistent.Component", {}, "component.unknown"],
  ];
  for (const [typeName, payload, code] of cases) {
    const s = studio();
    const before = structuredClone(s.snapshot);
    const id = s.scene.entities.find((e) => e.name === "Player").id;
    await assert.rejects(
      runTool(s, "editor_scene_apply", {
        expectedRevision: await sceneRevision(s.snapshot),
        operations: [{ op: "setComponent", entityID: id, typeName, payload }],
      }),
      (error) => {
        assert.equal(error.code, code);
        assert.equal(error.diagnostics[0].entityID, id);
        assert.equal(error.diagnostics[0].component, typeName);
        return true;
      },
    );
    assert.deepEqual(s.snapshot, before);
    assert.equal(s.document.undoStack.length, 0);
  }
});
test("existing texture paths normalize to the native resource root without admitting missing or escaping files", async () => {
  for (const texture of [
    "Sprites/player.png",
    "Assets/Sprites/player.png",
    "@res://Sprites/player.png",
  ]) {
    const s = studio(2);
    s.document.write("Assets/Sprites/player.png", "fixture bytes");
    const id = s.scene.entities[1].id;
    await runTool(s, "editor_scene_apply", {
      expectedRevision: await sceneRevision(s.snapshot),
      operations: [
        {
          op: "setComponent",
          entityID: id,
          typeName: "AdaSprite.Sprite",
          payload: { texture },
        },
      ],
    });
    assert.equal(
      s.scene.entities[1].components["AdaSprite.Sprite"].texture,
      "@res://Sprites/player.png",
    );
    for (const invalid of [
      "Sprites/missing.png",
      "@res://../Sources/Game.ada",
      "Assets/../Sources/Game.ada",
      "https://example.test/player.png",
    ]) {
      const before = structuredClone(s.snapshot);
      await assert.rejects(
        runTool(s, "editor_scene_apply", {
          expectedRevision: await sceneRevision(s.snapshot),
          operations: [
            {
              op: "setComponent",
              entityID: id,
              typeName: "AdaSprite.Sprite",
              payload: { texture: invalid },
            },
          ],
        }),
        (error) => error.code === "component.asset",
      );
      assert.deepEqual(s.snapshot, before);
    }
  }
});
test("missing Transform is actionable and native component rejection leaves the last good document and Undo alone", async () => {
  const s = studio(2);
  const before = structuredClone(s.snapshot);
  s.preview.message = async () => ({
    valid: false,
    diagnostics: [
      {
        entityID: "player",
        component: "AdaSprite.Sprite",
        path: "entities.player.components.AdaSprite.Sprite.imageMode",
        message: "Native enum decoding failed",
      },
    ],
  });
  await assert.rejects(
    runTool(s, "editor_scene_apply", {
      expectedRevision: await sceneRevision(s.snapshot),
      operations: [
        {
          op: "renameEntity",
          entityID: s.scene.entities[0].id,
          name: "Renamed",
        },
      ],
    }),
    (e) => e.code === "component.native",
  );
  assert.deepEqual(s.snapshot, before);
  assert.equal(s.document.undoStack.length, 0);
  await assert.rejects(
    runTool(s, "editor_scene_apply", {
      expectedRevision: await sceneRevision(s.snapshot),
      operations: [
        {
          op: "createEntity",
          name: "Body",
          components: { "AdaPhysics.PhysicsBody2DComponent": {} },
        },
      ],
    }),
    (e) => e.code === "component.dependency",
  );
});
test("native 64-bit values and enum spellings normalize losslessly and round-trip through ordinary Undo", async () => {
  const s = studio(2),
    id = s.scene.entities[1].id;
  await runTool(s, "editor_scene_apply", {
    expectedRevision: await sceneRevision(s.snapshot),
    operations: [
      {
        op: "addComponent",
        entityID: id,
        typeName: "AdaPhysics.PhysicsBody2DComponent",
        payload: {
          mode: "static",
          filter: { collisionBitMask: "18446744073709551615" },
        },
      },
    ],
  });
  const body =
    s.scene.entities[1].components["AdaPhysics.PhysicsBody2DComponent"];
  assert.deepEqual(body.mode, { static: {} });
  assert.equal(body.filter.collisionBitMask, 18446744073709551615n);
  assert.match(
    decode(file(s.snapshot, scenePath(s.snapshot)).data),
    /18446744073709551615/,
  );
  assert.equal(s.document.undoStack.length, 1);
  s.document.undo();
  assert.equal(
    s.scene.entities[1].components["AdaPhysics.PhysicsBody2DComponent"],
    undefined,
  );
  s.document.redo();
  assert.equal(
    s.scene.entities[1].components["AdaPhysics.PhysicsBody2DComponent"].filter
      .collisionBitMask,
    18446744073709551615n,
  );
  const bad = structuredClone(s.snapshot);
  const d = new Document(bad);
  d.scene((value) => {
    value.entities[1].components[
      "AdaPhysics.PhysicsBody2DComponent"
    ].filter.collisionBitMask = Number(18446744073709551615n);
  });
  assert.throws(
    () => normalizeScene(d.snapshot, contract),
    (e) => e.code === "component.integer",
  );
});
test("new sources and component attachment validate the proposed source set, commit one Undo and reject stale responses", async () => {
  const source =
    '@component(id: "game.player") struct PlayerState { @export var speed = 120.0; }';
  const s = studio(2),
    before = structuredClone(s.snapshot),
    id = s.scene.entities[1].id;
  await runTool(s, "editor_project_apply", {
    expectedGeneration: 0,
    files: [{ path: "Sources/Player.ada", content: source }],
    operations: [
      {
        op: "addComponent",
        entityID: id,
        typeName: "game.player",
        payload: { speed: 200 },
      },
    ],
  });
  assert.equal(s.scene.entities[1].components["game.player"].speed, 200);
  assert.equal(s.document.undoStack.length, 1);
  s.document.undo();
  assert.deepEqual(s.snapshot, before);
  let finish;
  s.preview.message = () =>
    new Promise((resolve) => {
      finish = resolve;
    });
  const pending = runTool(s, "editor_scene_apply", {
    expectedRevision: await sceneRevision(s.snapshot),
    operations: [{ op: "renameEntity", entityID: id, name: "Stale" }],
  });
  while (!finish) await new Promise((resolve) => setImmediate(resolve));
  s.document.write("Docs/User.md", "User edit");
  finish({ valid: true });
  await assert.rejects(pending, /Project changed/);
  assert.equal(s.scene.entities[1].name, "Player");
  assert.equal(s.document.undoStack.length, 1);
});
test("whole scene writes and legacy tools cannot bypass validation; operation schemas reject typos", async () => {
  for (const tool of [
    "editor_file_write",
    "editor_scene_add",
    "editor_scene_set",
    "editor_scene_apply",
  ]) {
    const s = studio(2),
      id = s.scene.entities[1].id;
    const bad = s.scene;
    bad.entities[1].components["AdaTransform.Transform"].position = [0];
    const args =
      tool === "editor_file_write"
        ? { path: scenePath(s.snapshot), content: JSON.stringify(bad) }
        : tool === "editor_scene_add"
          ? {
              name: "Invalid",
              components: { "AdaTransform.Transform": { position: [0] } },
            }
          : tool === "editor_scene_set"
            ? {
                entity: id,
                component: "AdaTransform.Transform",
                field: "position",
                value: [0],
              }
            : {
                expectedRevision: await sceneRevision(s.snapshot),
                operations: [
                  { op: "renameEntity", entityID: id, naem: "Typo" },
                ],
              };
    await assert.rejects(
      runTool(s, tool, args),
      (e) => e.code?.startsWith("component.") || e.code === "scene.operation",
    );
    assert.equal(s.document.undoStack.length, 0);
  }
});

test("runtime configuration uses its advertised field types and deep patches retain the active scene", async () => {
  const s = studio(2);
  const before = structuredClone(s.snapshot);
  for (const runtime of [
    { moduleName: 7 },
    { entry: { typo: "bad" } },
    { plugins: { enable: ["multiplayer", "multiplayer"] } },
    { window: { size: { width: -1 } } },
  ]) {
    await assert.rejects(
      runTool(s, "editor_project_configure", { runtime }),
      (e) => e.code === "runtime.value",
    );
    assert.deepEqual(s.snapshot, before);
    assert.equal(s.document.undoStack.length, 0);
  }
  await runTool(s, "editor_project_configure", {
    runtime: { entry: { startupSystem: "game.setup" } },
  });
  const project = JSON.parse(
    decode(file(s.snapshot, ".ada/project.json").data),
  );
  assert.equal(project.runtime.entry.scene, "Assets/Scenes/Main.ascn");
  assert.equal(project.runtime.entry.startupSystem, "game.setup");
  assert.equal(s.document.undoStack.length, 1);
});

test("source entity-reference defaults remain native defaults instead of unsupported scene payload fields", () => {
  const s = studio(2);
  s.document.scene((value) => {
    value.entities[1].components["game.reference"] = { target: -1 };
  });
  const schemas = [
    {
      typeName: "game.reference",
      kind: "component",
      defaultPayload: { target: -1 },
      fields: [{ name: "target", path: ["target"], kind: "entityReference" }],
    },
  ];
  const normalized = normalizeScene(s.snapshot, contract, schemas);
  assert.deepEqual(
    normalized.value.entities[1].components["game.reference"],
    {},
  );
  s.document.scene((value) => {
    value.entities[1].components["game.reference"].target = "another-entity";
  });
  assert.throws(
    () => normalizeScene(s.snapshot, contract, schemas),
    (e) => e.code === "component.reference",
  );
});
