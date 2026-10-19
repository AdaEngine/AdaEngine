import test from "node:test";
import assert from "node:assert/strict";
import {
  slashQuery,
  completeSlash,
  commandMatches,
  mentionedSkills,
} from "../src/slash-commands.js";

test("slash completion follows a collapsed caret without treating URLs or paths as commands", () => {
  for (const text of ["/", "/ada-b", "Please use /ada-b", "Plan:\n/ada-b"])
    assert.equal(
      slashQuery(text, text.length)?.query,
      text.endsWith("/") ? "" : "ada-b",
    );
  for (const text of [
    "https://example.test/ada-b",
    "Sources/Game.ada",
    "some/ada-b",
    "/ada-b ",
  ])
    assert.equal(slashQuery(text, text.length), null);
  assert.equal(slashQuery("/ada-b", 1, 3), null);
  assert.equal(slashQuery("/ada-b", 1.5), null);
  assert.equal(slashQuery("/ada-b", 100), null);
});

test("selection replaces the full token, retains surrounding text and leaves the caret ready to type", () => {
  const text = "Please /ada-broken preserve this";
  const token = slashQuery(text, text.indexOf("broken") + 2);
  const result = completeSlash(text, token, "ada-build-run");
  assert.equal(result.text, "Please /ada-build-run preserve this");
  assert.equal(result.text.slice(result.caret), "preserve this");
  assert.deepEqual(completeSlash("/", slashQuery("/", 1), "ada-coding"), {
    text: "/ada-coding ",
    caret: 12,
  });
  assert.throws(() => completeSlash("/", slashQuery("/", 1), "../bad"));
});

test("search ranks names ahead of descriptions and explicit commands work after ordinary text", () => {
  const catalog = [
    { id: "ada-game", description: "Build a game" },
    { id: "ada-build-run", description: "Check a project" },
    { id: "project-build", description: "Check another project" },
  ];
  assert.deepEqual(
    commandMatches(catalog, "build").map((s) => s.id),
    ["ada-build-run", "project-build", "ada-game"],
  );
  assert.deepEqual(
    commandMatches(catalog, "ada-build").map((s) => s.id),
    ["ada-build-run"],
  );
  assert.deepEqual(commandMatches(catalog, "unknown"), []);
  assert.deepEqual(
    mentionedSkills(
      "Use /ada-coding then /ada-build-run. /ada-coding\nhttps://site/ada-game Sources/File.ada",
    ),
    ["ada-coding", "ada-build-run"],
  );
});
