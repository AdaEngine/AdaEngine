import { StreamLanguage } from "@codemirror/language";

// AdaScript's Gravity grammar plus the engine's public annotation syntax.
const keywords = new Set(
  "as async await break case class const continue else enum extern for from func if import in is not private public return self static struct super switch true false null undefined var while".split(
    " ",
  ),
);
export const adaScriptParser = {
  name: "AdaScript",
  startState: () => ({ block: false, quote: null, depth: 0 }),
  token(stream, state) {
    if (state.block) {
      while (!stream.eol()) {
        if (stream.match("*/")) {
          state.block = false;
          break;
        }
        stream.next();
      }
      return "comment";
    }
    if (stream.eatSpace()) return null;
    if (stream.match("//")) {
      stream.skipToEnd();
      return "comment";
    }
    if (stream.match("/*")) {
      state.block = true;
      return "comment";
    }
    if (stream.match(/@[a-zA-Z_][\w]*/)) return "meta";
    const char = stream.next();
    if (char === '"' || char === "'") {
      let escaped = false;
      while (!stream.eol()) {
        const next = stream.next();
        if (next === char && !escaped) break;
        escaped = !escaped && next === "\\";
      }
      return "string";
    }
    if (/\d/.test(char)) {
      stream.eatWhile(/[\w.]/);
      return "number";
    }
    if (/[a-zA-Z_]/.test(char)) {
      stream.eatWhile(/[\w]/);
      const word = stream.current();
      if (keywords.has(word))
        return ["true", "false", "null", "undefined"].includes(word)
          ? "atom"
          : "keyword";
      if (/^[A-Z]/.test(word)) return "type";
      if (stream.match(/^\s*\(/, false)) return "def";
      return "variableName";
    }
    if (char === "{") state.depth++;
    if (char === "}") state.depth = Math.max(0, state.depth - 1);
    if (/[+\-*/=<>!&|?:%]/.test(char)) return "operator";
    return null;
  },
  indent: (state, textAfter, context) =>
    Math.max(0, state.depth - (/^\s*}/.test(textAfter) ? 1 : 0)) * context.unit,
  languageData: {
    commentTokens: { line: "//", block: { open: "/*", close: "*/" } },
    closeBrackets: { brackets: ["(", "[", "{", '"', "'"] },
  },
};
export const adaScript = StreamLanguage.define(adaScriptParser);
