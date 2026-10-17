import { build } from "esbuild";
import { mkdir, copyFile } from "node:fs/promises";
await mkdir("dist", { recursive: true });
await build({
  entryPoints: ["src/app.jsx"],
  bundle: true,
  minify: true,
  format: "esm",
  target: "es2022",
  outdir: "dist",
  entryNames: "studio",
  legalComments: "eof",
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
