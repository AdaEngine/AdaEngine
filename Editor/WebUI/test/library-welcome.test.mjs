import assert from "node:assert/strict";
import { build } from "esbuild";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { after, test } from "node:test";

// Exercise the actual React home and Studio state in a separate SSR harness.
// No test-only state or launch path is included in the shipped application.
const root = fileURLToPath(new URL("..", import.meta.url));
const scratch = await mkdtemp(join(tmpdir(), "studio-library-welcome-"));
after(() => rm(scratch, { recursive: true, force: true }));
const locales = {};
for (const language of ["en", "ru"])
  locales[language] = JSON.parse(
    await readFile(
      new URL(
        `../../Sources/AdaEditor/Assets/Localization/${language}.json`,
        import.meta.url,
      ),
      "utf8",
    ),
  );
await build({
  stdin: {
    contents: `import React from "react";import {renderToStaticMarkup} from "react-dom/server";import {Home} from "./src/ui/home.jsx";import {studio} from "./src/ui/state.js";export function render(state,section){Object.assign(studio,{account:null,config:{},projects:[],document:null,status:"signedout"},state);return renderToStaticMarkup(React.createElement(Home,{section}));}`,
    loader: "jsx",
    resolveDir: root,
  },
  bundle: true,
  platform: "node",
  format: "cjs",
  loader: { ".css": "empty" },
  define: { __STUDIO_AGENT_LOCALES__: JSON.stringify(locales) },
  outfile: join(scratch, "home.cjs"),
  logLevel: "silent",
});
globalThis.window = { addEventListener() {} };
let language = "en";
globalThis.localStorage = { getItem: () => language };
const { render } = createRequire(import.meta.url)(join(scratch, "home.cjs"));
const ready = {
  account: { id: "owner" },
  status: "saved",
  config: { enabled: true },
};

test("signed-out My projects explains the workspace and offers sign-in and browsing", () => {
  const html = render({}, "projects");
  assert.match(html, /<h1>A home for your worlds<\/h1>/);
  assert.match(html, /save your progress/);
  assert.match(html, /href="\/account\?continue=%2Fprojects"/);
  assert.match(html, /Explore games/);
  assert.match(html, /mascot-guide-v1.png/);
  assert.equal((html.match(/class="library-feature"/g) || []).length, 3);
  assert.doesNotMatch(html, /class="project-list"/);
});
test("signed-out Create keeps the copy, mascot and sign-in action in one hero", () => {
  const html = render({}, "create");
  assert.match(html, /library-create-hero/);
  assert.match(html, /<h1>What will you create today\?<\/h1>/);
  assert.match(html, /library-intro-copy[\s\S]*href="\/account\?continue=%2Fcreate"/);
  assert.match(html, /Sign in to create and save your own worlds/);
  assert.doesNotMatch(html, /hero-orbit|home-top|home-version|class="composer/);
});
test("an authenticated empty workspace offers creation and ZIP import without fake projects", () => {
  const html = render(ready, "projects");
  assert.match(html, /Your first world starts here/);
  assert.match(html, /Create your first world/);
  assert.match(html, /Upload project/);
  assert.match(html, /accept=".zip"/);
  assert.doesNotMatch(html, /href="\/account\?continue=%2Fcreate"|class="project-list"/);
});
test("existing projects render as real entries rather than the welcome state", () => {
  const html = render(
    {
      ...ready,
      projects: [
        { id: "one", title: "<My world>", updatedAt: 1750000000, revision: 3 },
      ],
    },
    "projects",
  );
  assert.match(html, /class="project-list"/);
  assert.match(html, /&lt;My world&gt;/);
  assert.match(html, /Version 3/);
  assert.doesNotMatch(
    html,
    /library-projects-empty|Your first world starts here/,
  );
});
test("loading and unavailable workspaces never masquerade as signed-out or empty", () => {
  const loading = render({ status: "loading" }, "projects");
  assert.match(loading, /Loading your projects/);
  assert.doesNotMatch(loading, /href="\/account\?continue=%2Fcreate"|Create your first world/);
  const offline = render({ status: "offline" }, "projects");
  assert.match(offline, /We could not load your workspace/);
  assert.match(offline, /Try again/);
  assert.doesNotMatch(offline, /href="\/account\?continue=%2Fcreate"|Create your first world/);
  const disabled = render(
    { ...ready, status: "offline", config: { enabled: false } },
    "projects",
  );
  assert.match(disabled, /Browser Studio is not enabled on this server/);
  assert.doesNotMatch(
    disabled,
    /Check your connection|Create your first world/,
  );
});
test("new welcome copy follows the shared Russian language preference", () => {
  language = "ru";
  try {
    const html = render({}, "projects");
    assert.ok(html.includes(locales.ru["A home for your worlds"]));
    assert.ok(html.includes(locales.ru["Explore games"]));
    assert.doesNotMatch(html, /A home for your worlds|Explore games/);
  } finally {
    language = "en";
  }
});
