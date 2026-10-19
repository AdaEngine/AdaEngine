import test from "node:test";
import assert from "node:assert/strict";
import { build } from "esbuild";
import React from "react";
import { renderToString } from "react-dom/server";
import { mkdtemp, mkdir, readFile, rm } from "node:fs/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import path from "node:path";

let presentation,
  folder,
  language = "en";
test.before(async () => {
  const root = fileURLToPath(new URL("../", import.meta.url));
  await mkdir(path.join(root, ".local"), { recursive: true });
  folder = await mkdtemp(path.join(root, ".local/presentation-test-"));
  const catalogs = {};
  for (const name of ["en", "ru"])
    catalogs[name] = JSON.parse(
      await readFile(
        path.join(
          root,
          `../Sources/AdaEditor/Assets/Localization/${name}.json`,
        ),
        "utf8",
      ),
    );
  const file = path.join(folder, "presentation.mjs");
  await build({
    stdin: {
      contents: `export {Workspace} from './src/ui/workspace.jsx'; export {Composer} from './src/ui/assistant.jsx'; export {Settings,History,LeaveProject} from './src/ui/dialogs.jsx'; export {studio} from './src/ui/state.js'; export {Document,template} from './src/documents.js';`,
      resolveDir: root,
      loader: "jsx",
    },
    bundle: true,
    platform: "node",
    format: "esm",
    packages: "external",
    outfile: file,
    define: { __STUDIO_AGENT_LOCALES__: JSON.stringify(catalogs) },
  });
  globalThis.window = { addEventListener() {} };
  globalThis.localStorage = { getItem: () => language };
  presentation = await import(pathToFileURL(file));
  const { studio, Document, template } = presentation;
  studio.document = new Document(template(3));
  studio.workspace = { id: "presentation", revision: 1 };
  studio.billingMode = "codex";
});
test.after(async () => {
  if (folder) await rm(folder, { recursive: true, force: true });
});

test("scene startup and live status follow the selected app language", () => {
  const { Workspace, studio } = presentation;
  for (const [lang, starting, ready] of [
    ["en", "Starting AdaEngine…", "AdaEngine · Scene editor"],
    ["ru", "Запускаем AdaEngine…", "AdaEngine · Редактор сцены"],
  ]) {
    language = lang;
    studio.runtime = "idle";
    studio.preview.hasFrame = false;
    let html = renderToString(React.createElement(Workspace));
    assert.ok(html.includes(starting));
    assert.doesNotMatch(html, /class="brand-mark"/);
    studio.runtime = "ready";
    studio.preview.hasFrame = true;
    html = renderToString(React.createElement(Workspace));
    assert.ok(html.includes(ready));
  }
});

test("composer activity is scoped to its running conversation and clears when the turn ends", () => {
  const { Composer, studio } = presentation;
  language = "en";
  studio.running = true;
  studio.runningSessionID = studio.session.id;
  let html = renderToString(React.createElement(Composer));
  assert.match(html, /composer-working/);
  assert.match(html, /aria-busy="true"/);
  studio.runningSessionID = "another-conversation";
  assert.doesNotMatch(
    renderToString(React.createElement(Composer)),
    /composer-working/,
  );
  studio.running = false;
  assert.doesNotMatch(
    renderToString(React.createElement(Composer)),
    /composer-working|aria-busy/,
  );
});

test("assistant settings follow the app language throughout the dialog", () => {
  const { Settings, studio } = presentation;
  studio.billingMode = "byok";
  studio.running = false;
  studio.providers = [
    {
      id: "fixture",
      title: "Fixture",
      models: [{ id: "plain", title: "Plain", tools: false }],
    },
  ];
  studio.providerID = "fixture";
  studio.modelID = "plain";
  for (const [lang, title, provider, placeholder, close] of [
    [
      "en",
      "Your assistant",
      "Provider",
      "Selected provider API key",
      "Close window",
    ],
    [
      "ru",
      "Ваш ассистент",
      "Провайдер",
      "Ключ выбранного провайдера",
      "Закрыть окно",
    ],
  ]) {
    language = lang;
    const html = renderToString(React.createElement(Settings));
    for (const text of [title, provider, placeholder, close])
      assert.ok(html.includes(text), text);
    if (lang === "en") {
      assert.ok(html.includes("Plain — no tools"));
      assert.ok(!html.includes("Свой API-ключ"));
      assert.ok(!html.includes("Ключ хранится"));
    }
  }
});
