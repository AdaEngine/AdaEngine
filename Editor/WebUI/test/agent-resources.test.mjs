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
  await mkdir(path.join(assets, "AgentSkills/example"), { recursive: true });
  await writeFile(
    path.join(assets, "AgentSkills/example/SKILL.md"),
    "---\nname: example\n---\nSkill content",
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
  assert.equal(resources.examples.length, 1);
  assert.equal(resources.examples[0].id, "game");
  assert.deepEqual(resources.examples[0].files, {
    ".ada/project.json": "{}",
    "README.md": "Example game",
    "Sources/main.gravity": "var score = 0;",
  });
});
