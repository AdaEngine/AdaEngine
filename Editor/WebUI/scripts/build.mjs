import { build } from "esbuild";
import { mkdir, copyFile, readFile, readdir } from "node:fs/promises";
import { agentResources } from "./agent-resources.mjs";
await mkdir("dist", { recursive: true });
await agentResources("dist");
const keys = new Set();
for (const folder of ["src", "src/ui"])
  for (const name of await readdir(folder)) {
    if (!/\.jsx?$/.test(name)) continue;
    const source = await readFile(`${folder}/${name}`, "utf8");
    for (const match of source.matchAll(/\bt\(\s*"([^"\\]+)"/g))
      keys.add(match[1]);
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
await copyFile("index.html", "dist/index.html");
// Copy the canonical brand assets unchanged; do not redraw the AdaEngine mark.
await copyFile("../../Assets/logo_dark.svg", "dist/ada-logo.svg");
await copyFile("../../Assets/logo_light.svg", "dist/ada-logo-light.svg");
await copyFile(
  "../Web/Sources/AdaEditorWeb/Resources/AdaScriptRecipes.md",
  "dist/recipes.md",
);
console.log("Ada Studio Web → dist/ (no editor WASM)");
