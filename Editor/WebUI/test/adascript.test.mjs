import test from "node:test";
import assert from "node:assert/strict";
import { StringStream } from "@codemirror/language";
import { adaScriptParser } from "../src/adascript.js";

function tokens(text) {
  const state = adaScriptParser.startState(),
    result = [];
  for (const line of text.split("\n")) {
    const stream = new StringStream(line, 2);
    while (!stream.eol()) {
      stream.start = stream.pos;
      const type = adaScriptParser.token(stream, state);
      if (type) result.push([stream.current(), type]);
    }
  }
  return result;
}
test("AdaScript keywords, engine types, annotations and functions have distinct syntax tags", () => {
  const result = tokens(
    '@component class Player { var speed = 3; func update() { self.move("hello"); } }',
  );
  for (const item of [
    ["@component", "meta"],
    ["class", "keyword"],
    ["Player", "type"],
    ["3", "number"],
    ["update", "def"],
    ["self", "keyword"],
    ['"hello"', "string"],
  ])
    assert.ok(
      result.some((t) => t[0] === item[0] && t[1] === item[1]),
      JSON.stringify(item),
    );
});
test("multiline comments, escapes and comment-like strings do not leak token state", () => {
  const result = tokens(
    '/* class\nvar */ var a = "// \\"ok\\""; // false\nreturn true;',
  );
  assert.ok(result.some((t) => t[0] === "return" && t[1] === "keyword"));
  assert.ok(!result.some((t) => t[0] === "class" && t[1] === "keyword"));
  assert.ok(result.some((t) => t[0] === "// false" && t[1] === "comment"));
});
