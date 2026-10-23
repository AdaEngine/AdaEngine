import assert from "node:assert/strict";
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { agentResources } from "../scripts/agent-resources.mjs";

const repository = fileURLToPath(new URL("../../..", import.meta.url));

test("resource export ignores filesystem metadata without dropping skills or examples", async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), "studio-resources-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  for (const relative of [
    "Editor/Sources/AdaEditor/Agent/EditorAgentA2UIModels.swift",
    "Editor/Sources/AdaEditor/Assets/Documentation/catalog.json",
    "Sources/AdaScriptCompilerCore/AdaScriptAPICatalog.swift",
    "Sources/AdaA2UI/Resources/catalog.json",
  ]) {
    const destination = path.join(root, relative);
    await mkdir(path.dirname(destination), { recursive: true });
    await cp(path.join(repository, relative), destination);
  }
  const assets = path.join(root, "Editor/Sources/AdaEditor/Assets");
  const contract = JSON.parse(
    await readFile(
      path.join(repository, "Editor/WebUI/assets/agent-contract.json"),
      "utf8",
    ),
  );
  // This fixture deliberately contains one tiny source corpus; the real export
  // snapshot and its full fingerprint are checked in native-contract tests.
  const source = "Sources/AdaScriptCompilerCore/AdaScriptAPICatalog.swift";
  contract.sourceHashes = { [source]: contract.sourceHashes[source] };
  await mkdir(path.join(root, "Editor/WebUI/assets"), { recursive: true });
  await writeFile(
    path.join(root, "Editor/WebUI/assets/agent-contract.json"),
    JSON.stringify(contract),
  );
  await mkdir(path.join(assets, "AgentSkills/example"), { recursive: true });
  await writeFile(
    path.join(assets, "AgentSkills/example/SKILL.md"),
    "---\nname: example\n---\nKeep notes in `Design/` and recipes in `Generators/`. Read `DESIGN.md`.",
  );
  await mkdir(path.join(assets, "Examples/game/Sources"), { recursive: true });
  await writeFile(path.join(assets, "Examples/game/README.md"), "Example game");
  await writeFile(
    path.join(assets, "Examples/game/Sources/main.gravity"),
    "var score = 0;",
  );
  for (const folder of [
    "AgentSkills",
    "Examples",
    "Examples/game",
    "Examples/game/Sources",
  ]) {
    await writeFile(
      path.join(assets, folder, ".DS_Store"),
      Buffer.from([0, 255, 0]),
    );
  }
  await writeFile(
    path.join(assets, "AgentSkills/README.md"),
    "Not a skill directory",
  );
  await writeFile(
    path.join(assets, "Examples/README.md"),
    "Not an example directory",
  );
  await mkdir(path.join(assets, "Examples/game/.ada"));
  await writeFile(path.join(assets, "Examples/game/.ada/project.json"), "{}");
  const output = path.join(root, "dist");
  await agentResources(output, root);
  const resources = JSON.parse(
    await readFile(path.join(output, "agent-resources.json"), "utf8"),
  );
  assert.deepEqual(
    resources.skills.map((skill) => skill.id),
    ["example", "ada-chat-ui"],
  );
  assert.match(resources.skills[0].content, /`Docs\/Design\/`/);
  assert.match(resources.skills[0].content, /`Docs\/Generators\/`/);
  assert.match(resources.skills[0].content, /`DESIGN\.md`/);
  assert.doesNotMatch(resources.skills[0].content, /`(?:Design|Generators)\/`/);
  assert.equal(resources.examples.length, 4);
  for (const example of resources.examples) {
    assert.ok(example.files[".ada/project.json"]);
    assert.ok(example.files["Assets/Scenes/Main.ascn"]);
    assert.ok(!Object.keys(example.files).some((p) => p.includes(".DS_Store")));
    assert.ok(!Object.values(example.files).includes("var score = 0;"));
  }
  const recipes = await readFile(path.join(output, "recipes.md"), "utf8");
  assert.match(recipes, /editor_project_apply/);
  assert.match(recipes, /editor_input_describe/);
  assert.match(recipes, /HUD recipes are not supported/);
  assert.doesNotMatch(recipes, /scriptBindings|HudModel/);
  assert.equal(resources.apiSource, undefined);
  assert.equal(resources.contract.examples, undefined);
});
