import assert from "node:assert/strict";
import test from "node:test";
import {
  filterGames,
  gameLaunchURL,
  publicationAvailable,
} from "../src/playground.js";
const release = {
  mode: "ugc",
  approved: true,
  expiresAt: null,
  releaseId: "release",
  url: "https://games.example/play",
};
test("Play requires an active release and rejects executable URLs", () => {
  const game = { id: "game", title: "A & B", publication: release };
  assert.equal(gameLaunchURL(game), release.url);
  for (const patch of [
    { approved: false },
    { revoked: true },
    { releaseId: null },
    { url: "javascript:alert(1)" },
    { url: "data:text/html,game" },
  ])
    assert.equal(
      gameLaunchURL({ ...game, publication: { ...release, ...patch } }),
      null,
    );
  assert.equal(
    publicationAvailable({ mode: "temporary", expiresAt: 10 }, 10001),
    false,
  );
  assert.equal(
    publicationAvailable({ mode: "temporary", expiresAt: 11 }, 10001),
    true,
  );
  const native = new URL(
    gameLaunchURL({
      ...game,
      publication: {
        ...release,
        pageId: "page",
        uploadId: "upload",
        runtime: { kind: "adascript", apiVersion: 2 },
      },
    }),
  );
  assert.equal(native.protocol, "adaeditor:");
  assert.equal(native.searchParams.get("game"), "page");
  assert.equal(native.searchParams.get("release"), "upload");
  assert.equal(native.searchParams.get("title"), "A & B");
});
test("public search combines platform, tags and sorting without mutating catalog order", () => {
  const games = [
    {
      id: "1",
      title: "Forest",
      owner: "alice",
      tags: ["  Exploration "],
      likes: 8,
      publication: { ...release, runtime: { kind: "adascript" } },
    },
    {
      id: "2",
      title: "Arcade",
      owner: "bob",
      tags: ["2D"],
      likes: 12,
      publication: release,
    },
  ];
  assert.deepEqual(
    filterGames(games, "all", "", "likes").map((g) => g.id),
    ["2", "1"],
  );
  assert.deepEqual(
    filterGames(games, "studio", "ALICE", "catalog").map((g) => g.id),
    ["1"],
  );
  assert.deepEqual(filterGames(games, "browser", "alice", "catalog"), []);
  assert.deepEqual(
    filterGames(games, "tag:exploration", "forest", "title").map((g) => g.id),
    ["1"],
  );
  assert.deepEqual(
    games.map((g) => g.id),
    ["1", "2"],
  );
});
