import test from "node:test";
import assert from "node:assert/strict";
import { build } from "esbuild";
import { Window } from "happy-dom";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import path from "node:path";
import { inspectLocalization } from "../scripts/check-localization.mjs";

let folder, ui, window, React, root, act, host;
const webRoot = fileURLToPath(new URL("../", import.meta.url));
test.before(async () => {
  await mkdir(path.join(webRoot, ".local"), { recursive: true });
  folder = await mkdtemp(path.join(webRoot, ".local/localization-test-"));
  const catalogs = {};
  for (const lang of ["en", "ru"])
    catalogs[lang] = JSON.parse(
      await readFile(
        path.join(
          webRoot,
          `../Sources/AdaEditor/Assets/Localization/${lang}.json`,
        ),
        "utf8",
      ),
    );
  const output = path.join(folder, "ui.mjs");
  await build({
    stdin: {
      contents: `
    export {Inspector} from './src/ui/inspector.jsx';
    export {Home} from './src/ui/home.jsx';
    export {Composer} from './src/ui/assistant.jsx';
    export {promptCompletion} from './src/prompt-completion.js';
    export {Assets} from './src/ui/code-assets.jsx';
    export {ProjectOverview} from './src/ui/project-overview.jsx';
    export {Settings} from './src/ui/dialogs.jsx';
    export {SourceEditor} from './src/ui/source-editor.jsx';
    export {studio} from './src/ui/state.js';
    export {Document,template,scene} from './src/documents.js';
    export * from './src/localization.js';
    export {api} from './src/platform.js';
    export * from './src/editor-language.js';
    export {skillPresentation} from './src/skill-presentation.js';
    export {slashQuery,commandMatches} from './src/slash-commands.js';
  `,
      resolveDir: webRoot,
      loader: "jsx",
    },
    bundle: true,
    packages: "external",
    loader: { ".css": "empty" },
    platform: "node",
    format: "esm",
    outfile: output,
    define: { __STUDIO_AGENT_LOCALES__: JSON.stringify(catalogs) },
  });
  window = new Window({ url: "http://localhost:8080/" });
  for (const key of [
    "window",
    "document",
    "navigator",
    "HTMLElement",
    "Element",
    "Node",
    "MutationObserver",
    "localStorage",
    "sessionStorage",
    "getComputedStyle",
    "requestAnimationFrame",
    "cancelAnimationFrame",
  ])
    Object.defineProperty(globalThis, key, {
      value:
        key === "window"
          ? window
          : typeof window[key] === "function" &&
              /AnimationFrame|ComputedStyle/.test(key)
            ? window[key].bind(window)
            : window[key],
      configurable: true,
    });
  globalThis.IS_REACT_ACT_ENVIRONMENT = true;
  React = (await import("react")).default;
  act = React.act;
  ui = await import(pathToFileURL(output));
  host = document.createElement("div");
  document.body.append(host);
  root = (await import("react-dom/client")).createRoot(host);
});
test.after(async () => {
  if (root) await act(() => root.unmount());
  await window?.happyDOM.close();
  if (folder) await rm(folder, { recursive: true, force: true });
});
async function render(Component) {
  await act(() => root.render(React.createElement(Component)));
}
function language(lang) {
  ui.setLanguage(lang);
}
function prepare() {
  language("en");
  const { studio, Document, template } = ui;
  studio.document = new Document(template(3));
  studio.workspace = { id: "locale-test", revision: 7 };
  studio.selected =
    ui
      .scene(studio.snapshot)
      .entities.find((e) => e.components["AdaEngine.Transform"])?.id ??
    ui.scene(studio.snapshot).entities[0].id;
  studio.billingMode = "byok";
  studio.running = false;
  return studio;
}

test("mounted panels change language and retain authored values and uncommitted input", async () => {
  const s = prepare();
  // A Russian object name is user data even when the interface is English.
  s.document.scene((value) => {
    value.entities.find((e) => e.id === s.selected).name = "Мой объект";
  });
  const documentBefore = s.document;
  const Panels = () =>
    React.createElement(
      React.Fragment,
      null,
      React.createElement(ui.Inspector),
      React.createElement(ui.Assets),
      React.createElement(ui.ProjectOverview),
    );
  await render(Panels);
  assert.doesNotMatch(
    host.textContent.replaceAll("Мой объект", ""),
    /[А-Яа-яЁё]/u,
  );
  assert.match(host.textContent, /Project assets/);
  assert.match(host.textContent, /Duplicate/);
  assert.match(host.textContent, /Private project · revision 7/);
  const name = host.querySelector(".inspector-content > label input");
  assert.equal(name.value, "Мой объект");
  const field = host.querySelector(
    ".component .field-label input:not([type=number]):not([type=color])",
  );
  assert.ok(field);
  await act(() => {
    Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype,
      "value",
    ).set.call(field, "unsaved field");
    field.dispatchEvent(new window.Event("input", { bubbles: true }));
  });
  language("ru");
  await render(Panels);
  assert.ok(host.textContent.includes(ui.t("Project assets")));
  assert.ok(host.textContent.includes(ui.t("Duplicate")));
  assert.equal(host.querySelector(".inspector-content > label input"), name);
  assert.equal(name.value, "Мой объект");
  if (field) assert.equal(field.value, "unsaved field");
  assert.equal(s.document, documentBefore);
  language("en");
  await render(Panels);
  assert.match(host.textContent, /Project assets/);
  assert.equal(name.value, "Мой объект");
});

test("changing the language in mounted Settings refreshes other mounted panels without clearing the API key", async () => {
  const s = prepare();
  s.providers = [
    {
      id: "fixture",
      title: "Fixture",
      models: [{ id: "plain", title: "Plain", tools: true }],
    },
  ];
  s.providerID = "fixture";
  s.modelID = "plain";
  s.apiKey = "test-draft";
  function SettingsHost() {
    React.useSyncExternalStore(s.subscribe, s.getVersion);
    return React.createElement(
      React.Fragment,
      null,
      React.createElement(ui.Settings),
      React.createElement(ui.ProjectOverview),
    );
  }
  await render(SettingsHost);
  const key = host.querySelector("input[type=password]");
  const choice = host.querySelector('select[aria-label="Interface language"]');
  await act(() => {
    choice.value = "ru";
    choice.dispatchEvent(new window.Event("change", { bubbles: true }));
  });
  assert.equal(ui.currentLanguage(), "ru");
  assert.equal(
    host.querySelector("[role=dialog]").getAttribute("aria-label"),
    ui.t("Your assistant"),
  );
  assert.ok(
    host
      .querySelector(".project-overview")
      .textContent.includes(ui.t("YOUR PROJECT")),
  );
  assert.equal(host.querySelector("input[type=password]"), key);
  assert.equal(key.value, "test-draft");
  await act(() => {
    choice.value = "en";
    choice.dispatchEvent(new window.Event("change", { bubbles: true }));
  });
  assert.equal(
    host.querySelector("[role=dialog]").getAttribute("aria-label"),
    "Your assistant",
  );
  assert.equal(key.value, "test-draft");
  s.apiKey = "";
  await act(() => root.render(null));
});

test("application HTTP errors retain status while their message follows the current language", async () => {
  const original = globalThis.fetch;
  try {
    for (const [status, body, key] of [
      [500, {}, "Server error: {0}"],
      [
        402,
        {},
        "Not enough AI credits for this request. Check your balance in Cloud settings.",
      ],
      [
        403,
        { error: { message: "Active AI entitlement required" } },
        "Cloud Pro includes 500 AI credits per month. Subscribe to use Ada AI.",
      ],
    ]) {
      language("en");
      globalThis.fetch = async () => Response.json(body, { status });
      const error = await ui.api("/v1/ai/test").catch((error) => error);
      assert.equal(error.status, status);
      assert.equal(error.message, ui.t(key, status));
      language("ru");
      assert.equal(error.message, ui.t(key, status));
      assert.notEqual(error.message, key);
    }
  } finally {
    globalThis.fetch = original;
  }
});

test("existing application errors and viewport failures resolve in the current language", () => {
  const s = prepare();
  const error = new ui.LocalizedError("Unknown skill ID");
  s.fail(error);
  s.viewportError = error;
  assert.equal(s.error, "Unknown skill ID");
  language("ru");
  assert.equal(s.error, ui.t("Unknown skill ID"));
  assert.notEqual(s.error, "Unknown skill ID");
  assert.equal(s.viewportError, s.error);
  s.fail(new Error("ошибка из пользовательского кода"));
  language("en");
  assert.equal(s.error, "ошибка из пользовательского кода");
});

test("system language follows browser preference; new template names are localized only at creation", () => {
  language("system");
  Object.defineProperty(navigator, "languages", {
    value: ["ru-RU", "en"],
    configurable: true,
  });
  assert.equal(ui.currentLanguage(), "ru");
  const russian = ui.template(3);
  assert.equal(russian.title, "Долина ветров");
  language("en");
  assert.equal(ui.template(3).title, "Valley of winds");
  assert.equal(russian.title, "Долина ветров");
  assert.equal(ui.resolveLanguage("system", ["ja-JP"]), "en");
  localStorage.setItem("AdaEditor.language", "bad");
  assert.equal(ui.languagePreference(), "system");
});

test("workflow menu localizes bundled summaries and supports Russian search without changing instructions", () => {
  language("ru");
  const original = {
    id: "ada-assets",
    description: "Original workflow description",
    content: "Instructions",
  };
  const presented = ui.skillPresentation(original);
  assert.match(presented.description, /ресурсы/);
  assert.equal(presented.content, original.content);
  assert.equal(original.description, "Original workflow description");
  assert.equal(ui.commandMatches([presented], "ресурсы").length, 1);
  assert.equal(ui.slashQuery("/ресурсы", 8).query, "ресурсы");
  language("en");
  assert.equal(
    ui.skillPresentation(original).description,
    "Find, import and organize game assets.",
  );
});

test("open code search switches language without losing code, query, focus or caret", async () => {
  await act(() => root.render(null));
  language("en");
  const { EditorState, Compartment } = await import("@codemirror/state");
  const { EditorView } = await import("@codemirror/view");
  const { openSearchPanel, setSearchQuery, SearchQuery, getSearchQuery } =
    await import("@codemirror/search");
  const compartment = new Compartment();
  const parent = document.createElement("div");
  document.body.append(parent);
  const editor = new EditorView({
    parent,
    state: EditorState.create({
      doc: "// Русский комментарий\nvar score = 42;",
      selection: { anchor: 25 },
      extensions: compartment.of(ui.editorLanguageExtensions()),
    }),
  });
  try {
    openSearchPanel(editor);
    editor.dispatch({
      effects: setSearchQuery.of(
        new SearchQuery({
          search: "score",
          replace: "points",
          caseSensitive: true,
        }),
      ),
    });
    const input = editor.dom.querySelector('[name="search"]');
    input.focus();
    input.setSelectionRange(1, 4);
    language("ru");
    ui.refreshEditorLanguage(editor, compartment);
    assert.match(
      editor.dom.querySelector(".cm-search").textContent,
      /Заменить/,
    );
    assert.equal(editor.contentDOM.getAttribute("aria-label"), "Исходный код");
    assert.equal(getSearchQuery(editor.state).search, "score");
    assert.equal(getSearchQuery(editor.state).replace, "points");
    assert.equal(getSearchQuery(editor.state).caseSensitive, true);
    assert.equal(document.activeElement.getAttribute("name"), "search");
    assert.equal(document.activeElement.selectionStart, 1);
    assert.equal(document.activeElement.selectionEnd, 4);
    assert.equal(editor.state.selection.main.anchor, 25);
    assert.equal(
      editor.state.doc.toString(),
      "// Русский комментарий\nvar score = 42;",
    );
    const outside = document.createElement("input");
    document.body.append(outside);
    outside.focus();
    language("en");
    ui.refreshEditorLanguage(editor, compartment);
    assert.equal(document.activeElement, outside);
    assert.equal(getSearchQuery(editor.state).search, "score");
    assert.match(editor.dom.querySelector(".cm-search").textContent, /Replace/);
    outside.remove();
  } finally {
    editor.destroy();
    parent.remove();
  }
});

test("localization guard rejects literal and escaped Russian and accepts the native language name", async () => {
  const directory = path.join(folder, "guard");
  await mkdir(path.join(directory, "src"), { recursive: true });
  const file = path.join(directory, "src/fixture.jsx");
  for (const code of [
    'const x = "Привет";',
    'const x = "\\u041f\\u0440\\u0438\\u0432\\u0435\\u0442";',
    "const x = <p>Привет</p>;",
    "const x = `Привет ${name}`;",
  ]) {
    await writeFile(file, code);
    await assert.rejects(inspectLocalization(directory), /Hardcoded Russian/);
  }
  await writeFile(
    file,
    'const x = <option value="ru">Русский</option>; t("Find"); new LocalizedError("Invalid language");',
  );
  const inspected = await inspectLocalization(directory);
  assert.deepEqual([...inspected.keys].sort(), ["Find", "Invalid language"]);
});

test("Create offers game choices and accepts a local completion without sending it", async () => {
  const s = prepare();
  s.document = null;
  s.status = "saved";
  s.account = { id: "owner" };
  s.config = { enabled: true };
  s.creation = { dimension: 3, players: "single" };
  s.prompt = "";
  const originalSend = s.send,
    originalFetch = globalThis.fetch;
  const sends = [];
  s.send = async (...args) => sends.push(args);
  globalThis.fetch = async () => {
    throw new Error("Typing must not make an API request");
  };
  function CreateHost() {
    React.useSyncExternalStore(s.subscribe, s.getVersion);
    return React.createElement(ui.Home, { section: "create" });
  }
  const type = async (text) => {
    const textarea = host.querySelector("textarea");
    await act(() => {
      textarea.focus();
      Object.getOwnPropertyDescriptor(
        window.HTMLTextAreaElement.prototype,
        "value",
      ).set.call(textarea, text);
      textarea.dispatchEvent(new window.Event("input", { bubbles: true }));
    });
    await act(() => new Promise((resolve) => setTimeout(resolve, 340)));
    return textarea;
  };
  try {
    await render(CreateHost);
    assert.match(
      host.querySelector(".library-mascot img").src,
      /mascot-builder-v1/,
    );
    const dimension = host.querySelector('button[aria-label="Game dimension"]'),
      players = host.querySelector('button[aria-label="Player mode"]');
    assert.equal(
      dimension.closest(".composer-footer"),
      players.closest(".composer-footer"),
    );
    await act(() => dimension.click());
    assert.equal(dimension.getAttribute("aria-expanded"), "true");
    assert(
      document
        .querySelector("[role=menuitemradio][aria-checked=true]")
        .textContent.includes("3D"),
    );
    await act(() =>
      document.querySelectorAll("[role=menuitemradio]")[1].click(),
    );
    assert.equal(document.activeElement, dimension);
    await act(() => players.click());
    await act(() =>
      document.querySelectorAll("[role=menuitemradio]")[1].click(),
    );
    assert.deepEqual(s.creation, { dimension: 2, players: "multiplayer" });
    await act(() =>
      dimension.dispatchEvent(
        new window.KeyboardEvent("keydown", {
          key: "ArrowDown",
          bubbles: true,
          cancelable: true,
        }),
      ),
    );
    assert.equal(document.activeElement.getAttribute("aria-checked"), "true");
    await act(() =>
      document.activeElement.dispatchEvent(
        new window.KeyboardEvent("keydown", {
          key: "Home",
          bubbles: true,
          cancelable: true,
        }),
      ),
    );
    assert(document.activeElement.textContent.includes("3D"));
    assert.equal(s.creation.dimension, 2);
    await act(() =>
      document.activeElement.dispatchEvent(
        new window.KeyboardEvent("keydown", {
          key: "Escape",
          bubbles: true,
          cancelable: true,
        }),
      ),
    );
    assert.equal(document.querySelector("[role=menu]"), null);
    assert.equal(document.activeElement, dimension);
    await act(() => players.click());
    await act(() =>
      host
        .querySelector("textarea")
        .dispatchEvent(new window.Event("pointerdown", { bubbles: true })),
    );
    assert.equal(document.querySelector("[role=menu]"), null);

    const textarea = await type("Create a plat");
    assert.ok(host.querySelector(".completion-mirror"));
    assert.equal(textarea.value, "Create a plat");
    assert.equal(sends.length, 0);
    await act(() =>
      textarea.dispatchEvent(
        new window.KeyboardEvent("keydown", {
          key: "Tab",
          bubbles: true,
          cancelable: true,
        }),
      ),
    );
    assert.equal(
      textarea.value,
      "Create a platformer where I jump between floating islands and collect stars.",
    );
    assert.equal(sends.length, 0);
    await act(() =>
      textarea.dispatchEvent(
        new window.KeyboardEvent("keydown", {
          key: "Enter",
          bubbles: true,
          cancelable: true,
        }),
      ),
    );
    assert.deepEqual(sends[0], [
      textarea.value,
      { creation: { dimension: 2, players: "multiplayer" } },
    ]);
    await type("Create a plat");
    await act(() =>
      textarea.dispatchEvent(
        new window.KeyboardEvent("keydown", {
          key: "Escape",
          bubbles: true,
          cancelable: true,
        }),
      ),
    );
    assert.equal(host.querySelector(".completion-mirror"), null);
    await type("Create a puzzle");
    assert.ok(host.querySelector(".completion-mirror"));
    await act(() => {
      textarea.setSelectionRange(2, 2);
      textarea.dispatchEvent(
        new window.MouseEvent("mouseup", { bubbles: true }),
      );
      document.dispatchEvent(new window.Event("selectionchange"));
    });
    assert.equal(host.querySelector(".completion-mirror"), null);
    await type("Создай плат");
    assert.ok(
      host.querySelector(".completion-mirror").textContent.includes("прыгаю"),
    );
    assert.equal(textarea.value, "Создай плат");
    await act(() => textarea.blur());
    assert.equal(host.querySelector(".completion-mirror"), null);
    await act(() => {
      ui.setLanguage("ru");
      s.emit();
    });
    assert.ok(
      host
        .querySelector('button[aria-label="Размерность игры"]')
        .textContent.includes("2D"),
    );
    assert.ok(host.textContent.includes(ui.t("Multiplayer")));
  } finally {
    s.send = originalSend;
    globalThis.fetch = originalFetch;
    await act(() => root.render(null));
  }
});

test("completion preserves the exact prefix and never offers one inside selections, commands or URLs", () => {
  language("en");
  assert.equal(
    ui.promptCompletion("Create a plat", 13),
    "former where I jump between floating islands and collect stars.",
  );
  const input = "  cReAtE a plat";
  assert.equal(
    (input + ui.promptCompletion(input, input.length)).slice(0, input.length),
    input,
  );
  for (const text of ["/ada-", "https://", "Done.", "x", "Create a game /ada-"])
    assert.equal(ui.promptCompletion(text, text.length), "");
  assert.equal(ui.promptCompletion("Create a plat", 2), "");
  assert.equal(ui.promptCompletion("Create a plat", 13, 2), "");
});

test("Create accepts multiple picked, pasted and dropped media, shows removable chips and can send attachments without text", async () => {
  const s = prepare();
  s.document = null;
  s.homeAttachments = [];
  s.prompt = "";
  s.status = "saved";
  s.account = { id: "owner" };
  s.config = { enabled: true };
  const originalSend = s.send,
    calls = [];
  s.send = async (...args) => calls.push(args);
  function CreateHost() {
    React.useSyncExternalStore(s.subscribe, s.getVersion);
    return React.createElement(ui.Home, { section: "create" });
  }
  const settle = async () => {
    for (let i = 0; i < 5; i++)
      await new Promise((resolve) => setImmediate(resolve));
  };
  const media = (name) => new window.File([new Uint8Array([1, 2, 3])], name);
  try {
    await render(CreateHost);
    const picker = host.querySelector("input[type=file][multiple]"),
      plus = host.querySelector('button[aria-label="Attach a file"]');
    assert(picker);
    assert.equal(plus.disabled, false);
    assert(picker.accept.includes(".mp3"));
    assert(picker.accept.includes(".glb"));
    let opened = false;
    picker.click = () => {
      opened = true;
    };
    await act(() => plus.click());
    assert.equal(opened, true);
    Object.defineProperty(picker, "files", {
      value: [media("character.glb"), media("music.wav")],
      configurable: true,
    });
    await act(async () => {
      picker.dispatchEvent(new window.Event("change", { bubbles: true }));
      await settle();
    });
    assert.equal(s.homeAttachments.length, 2);
    assert.equal(host.querySelectorAll(".composer-attachment").length, 2);
    assert.ok(host.textContent.includes("character.glb"));
    assert.ok(host.textContent.includes("music.wav"));
    assert.equal(host.querySelector("button[type=submit]").disabled, false);
    await act(() =>
      host
        .querySelector('button[aria-label="Remove attachment character.glb"]')
        .click(),
    );
    assert.equal(s.homeAttachments.length, 1);
    const paste = new window.Event("paste", {
      bubbles: true,
      cancelable: true,
    });
    Object.defineProperty(paste, "clipboardData", {
      value: { files: [media("pasted.glb")] },
    });
    await act(async () => {
      host.querySelector("textarea").dispatchEvent(paste);
      await settle();
    });
    assert.equal(paste.defaultPrevented, true);
    assert.equal(s.homeAttachments.length, 2);
    const drop = new window.Event("drop", { bubbles: true, cancelable: true });
    Object.defineProperty(drop, "dataTransfer", {
      value: { files: [media("dropped.ogg")], types: ["Files"] },
    });
    await act(async () => {
      host.querySelector("form").dispatchEvent(drop);
      await settle();
    });
    assert.equal(drop.defaultPrevented, true);
    assert.equal(s.homeAttachments.length, 3);
    await act(() => host.querySelector("button[type=submit]").click());
    assert.equal(calls.length, 1);
    assert.equal(calls[0][0], "");
    assert.equal(s.homeAttachments.length, 3);
    await act(() => {
      language("ru");
      s.emit();
    });
    assert(host.querySelector('[aria-label="Убрать вложение music.wav"]'));
  } finally {
    s.send = originalSend;
    s.homeAttachments = [];
    await act(() => root.render(null));
  }
});
