import { build } from "esbuild";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { mkdir, copyFile, readFile, cp, writeFile } from "node:fs/promises";
import { agentResources } from "./agent-resources.mjs";
import { inspectLocalization } from "./check-localization.mjs";
await mkdir("dist", { recursive: true });
await agentResources("dist");
const panels =
  process.env.ADA_CLOUD_PANELS_DIST ||
  fileURLToPath(
    new URL("../../../../My Projects/adawebsite/dist-panels", import.meta.url),
  );
const { keys } = await inspectLocalization();
try {
  for (const key of JSON.parse(
    await readFile(resolve(panels, "cloud-panel-messages.json"), "utf8"),
  ))
    keys.add(key);
} catch (error) {
  throw new Error(
    "Build adawebsite with npm run build:panels first, or set ADA_CLOUD_PANELS_DIST",
    { cause: error },
  );
}
const locales = {};
for (const language of ["en", "ru"]) {
  const catalog = JSON.parse(
    await readFile(
      `../Sources/AdaEditor/Assets/Localization/${language}.json`,
      "utf8",
    ),
  );
  locales[language] = Object.fromEntries(
    [...keys].map((key) => {
      if (!catalog[key])
        throw new Error(`Missing ${language} Studio translation: ${key}`);
      return [key, catalog[key]];
    }),
  );
}
await build({
  entryPoints: ["src/app.jsx"],
  bundle: true,
  minify: true,
  format: "esm",
  target: "es2022",
  outdir: "dist",
  entryNames: "studio",
  legalComments: "eof",
  define: { __STUDIO_AGENT_LOCALES__: JSON.stringify(locales) },
});
// Keep the export's stable filenames, but invalidate browser asset caches on rebuild.
let html = await readFile("index.html", "utf8");
for (const name of ["studio.js", "studio.css"]) {
  const version = createHash("sha256")
    .update(await readFile(`dist/${name}`))
    .digest("hex")
    .slice(0, 12);
  html = html.replace(`./${name}`, `./${name}?v=${version}`);
}
await writeFile("dist/index.html", html);
await cp("assets/playground", "dist/playground", { recursive: true });
// Copy the canonical brand assets unchanged; do not redraw the AdaEngine mark.
await copyFile("../../Assets/logo_dark.svg", "dist/ada-logo.svg");
await copyFile("../../Assets/logo_light.svg", "dist/ada-logo-light.svg");
await copyFile(
  "../Web/Sources/AdaEditorWeb/Resources/AdaScriptRecipes.md",
  "dist/recipes.md",
);
console.log("Ada Studio Web → dist/ (no editor WASM)");

try {
  await copyFile(resolve(panels, "cloud-panels.js"), "dist/cloud-panels.js");
  await copyFile(resolve(panels, "style.css"), "dist/cloud-panels.css");
} catch (error) {
  throw new Error(
    "Build adawebsite with npm run build:panels first, or set ADA_CLOUD_PANELS_DIST",
    { cause: error },
  );
}
await writeFile(
  "dist/playground-build.json",
  JSON.stringify({
    formatVersion: 1,
    shell: createHash("sha256")
      .update(await readFile("dist/studio.js"))
      .digest("hex"),
    panels: createHash("sha256")
      .update(await readFile("dist/cloud-panels.js"))
      .digest("hex"),
  }),
);
