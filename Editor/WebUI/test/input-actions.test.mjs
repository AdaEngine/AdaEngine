import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { normalizeInputActions, describeInput } from "../src/input-actions.js";
import { runTool } from "../src/agent.js";
import { Document, template, metadata, file } from "../src/documents.js";

const contract = JSON.parse(
  await readFile(new URL("../assets/agent-contract.json", import.meta.url)),
);
globalThis.fetch = async () => Response.json({ contract });
const action = (bindings, extra = {}) => [{ name: "Jump", bindings, ...extra }];

test("every native binding can be authored by name without guessing its persisted encoding", () => {
  for (const binding of contract.input.bindings) {
    const normalized = normalizeInputActions(
      action([{ kind: binding.kind, name: binding.name }]),
      contract.input,
    );
    assert.deepEqual(
      normalized[0].bindings,
      [binding.encoded],
      binding.kind + ":" + binding.name,
    );
    assert.deepEqual(
      normalizeInputActions(normalized, contract.input),
      normalized,
    );
  }
  const space = normalizeInputActions(
    action([{ kind: "key", name: "space" }]),
    contract.input,
  );
  assert.deepEqual(space, [
    { name: "Jump", deadZone: 0.2, bindings: [{ key: { _0: " " } }] },
  ]);
});

test("invalid names, dead zones, unsupported enum values and duplicate aliases have field diagnostics", () => {
  const cases = [
    [null, "input.actions.type"],
    [action([], { name: " Jump" }), "input.action.name"],
    [action([], { name: "a\n" }), "input.action.name"],
    [[...action([]), ...action([])], "input.action.name"],
    [action([], { deadZone: 1 }), "input.action.deadZone"],
    [action([], { deadZone: Infinity }), "input.action.deadZone"],
    [action([], { deadZone: "0.2" }), "input.action.deadZone"],
    [action(null), "input.bindings.type"],
    [action([{ key: { _0: "space" } }]), "input.binding.unsupported"],
    [action([{ kind: "key", name: "none" }]), "input.binding.unsupported"],
    [
      action([{ kind: "mouseButton", name: "scrollWheel" }]),
      "input.binding.unsupported",
    ],
    [
      action([{ kind: "key", name: "space", typo: true }]),
      "input.binding.unsupported",
    ],
    [
      action([{ kind: "key", name: "space" }, { key: { _0: " " } }]),
      "input.binding.duplicate",
    ],
  ];
  for (const [value, code] of cases)
    assert.throws(
      () => normalizeInputActions(value, contract.input),
      (error) => {
        assert.equal(error.code, code);
        assert.match(error.diagnostics[0].path, /^inputActions/);
        assert.equal(error.diagnostics[0].repairTool, "editor_input_describe");
        return true;
      },
    );
});

test("input discovery is bounded, paginated and supports Russian authoring terms", () => {
  const first = describeInput(contract.input, {});
  assert.equal(first.total, 146);
  assert.equal(first.bindings.length, 30);
  assert.equal(first.nextOffset, 30);
  const second = describeInput(contract.input, { offset: first.nextOffset });
  assert.notDeepEqual(first.bindings, second.bindings);
  assert.deepEqual(
    describeInput(contract.input, { query: "пробел" }).bindings[0].encoded,
    { key: { _0: " " } },
  );
  assert.equal(
    describeInput(contract.input, { query: "unknown_binding_name" }).total,
    0,
  );
});

function studio() {
  const s = { document: new Document(template(2)), changed() {} };
  Object.defineProperty(s, "snapshot", { get: () => s.document.snapshot });
  return s;
}

test("configuration, whole-file writes and patches reject invalid input before committing Undo or document state", async () => {
  for (const tool of [
    "editor_project_configure",
    "editor_file_write",
    "editor_file_patch",
  ]) {
    const s = studio();
    const before = structuredClone(s.snapshot);
    const invalid = action([{ key: { _0: "space" } }]);
    const project = { ...metadata(s.snapshot), inputActions: invalid };
    const args =
      tool === "editor_project_configure"
        ? { inputActions: invalid }
        : tool === "editor_file_write"
          ? { path: ".ada/project.json", content: JSON.stringify(project) }
          : {
              path: ".ada/project.json",
              oldText: '"inputActions": []',
              newText: '"inputActions": ' + JSON.stringify(invalid),
            };
    await assert.rejects(
      runTool(s, tool, args),
      (error) => error.code === "input.binding.unsupported",
    );
    assert.deepEqual(s.snapshot, before);
    assert.equal(s.document.undoStack.length, 0);
  }
});

test("valid input uses one ordinary Undo transaction and saved canonical data survives reopening", async () => {
  const s = studio();
  const before = file(s.snapshot, ".ada/project.json").data;
  await runTool(s, "editor_project_configure", {
    inputActions: action([
      { kind: "key", name: "space" },
      { kind: "touch", name: "touch" },
    ]),
  });
  assert.deepEqual(metadata(s.snapshot).inputActions[0].bindings, [
    { key: { _0: " " } },
    { touch: {} },
  ]);
  assert.equal(s.document.undoStack.length, 1);
  assert.deepEqual(
    metadata(new Document(structuredClone(s.snapshot)).snapshot).inputActions,
    metadata(s.snapshot).inputActions,
  );
  s.document.undo();
  assert.equal(file(s.snapshot, ".ada/project.json").data, before);
});
