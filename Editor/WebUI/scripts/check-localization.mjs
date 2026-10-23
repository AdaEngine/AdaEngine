import ts from "typescript";
import { readFile, readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

export async function inspectLocalization(
  root = fileURLToPath(new URL("../", import.meta.url)),
) {
  const files = [];
  async function walk(directory) {
    for (const item of await readdir(directory, { withFileTypes: true })) {
      const file = path.join(directory, item.name);
      if (item.isDirectory()) await walk(file);
      else if (/\.jsx?$/.test(file)) files.push(file);
    }
  }
  await walk(path.join(root, "src"));
  const keys = new Set(),
    violations = [];
  for (const file of files) {
    const source = await readFile(file, "utf8");
    const ast = ts.createSourceFile(
      file,
      source,
      ts.ScriptTarget.Latest,
      true,
      file.endsWith(".jsx") ? ts.ScriptKind.JSX : ts.ScriptKind.JS,
    );
    const visit = (node) => {
      if (
        ts.isStringLiteralLike(node) ||
        ts.isTemplateHead(node) ||
        ts.isTemplateMiddle(node) ||
        ts.isTemplateTail(node) ||
        ts.isJsxText(node)
      ) {
        const value = node.text;
        // Language names are native autonyms, not UI prose to translate.
        const autonym =
          ts.isJsxText(node) &&
          value.trim() === "Русский" &&
          node.parent.openingElement?.attributes.properties.some(
            (p) => p.name?.text === "value" && p.initializer?.text === "ru",
          );
        if (/[А-Яа-яЁё]/u.test(value) && !autonym)
          violations.push(
            `${path.relative(root, file)}:${ast.getLineAndCharacterOfPosition(node.getStart(ast)).line + 1}: ${value.slice(0, 100)}`,
          );
      }
      if (
        (ts.isCallExpression(node) || ts.isNewExpression(node)) &&
        ["t", "LocalizedError", "translatedText"].includes(node.expression.getText(ast))
      ) {
        const key = node.arguments?.[0];
        if (key && ts.isStringLiteralLike(key)) keys.add(key.text);
      }
      ts.forEachChild(node, visit);
    };
    visit(ast);
  }
  if (violations.length)
    throw new Error(
      `Hardcoded Russian outside localization catalogs:\n${violations.join("\n")}`,
    );
  return { keys };
}
if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const { keys } = await inspectLocalization();
  console.log(
    `WebUI localization source check OK: ${keys.size} explicit messages`,
  );
}
