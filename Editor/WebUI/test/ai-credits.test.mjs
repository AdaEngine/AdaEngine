import test from "node:test";
import assert from "node:assert/strict";
import {
  refreshAICredits,
  requireHostedAI,
  validateBalance,
} from "../src/ai-credits.js";
import { providersForMode } from "../src/provider-settings.js";

const balance = (change = {}) => ({
  accountID: "owner",
  allowance: 500_000_000,
  spent: 25_000_000,
  reserved: 5_000_000,
  available: 470_000_000,
  scale: 1_000_000,
  cycleStart: 1700000000,
  cycleEnd: 1702592000,
  suspended: false,
  closed: false,
  ...change,
});
const catalog = {
  enabled: true,
  capabilities: ["llm"],
  microcreditsPerCredit: 1_000_000,
};
const studio = () => ({ account: { id: "owner" }, emit() {} });

test("balance validation rejects another account and malformed or inconsistent counters", () => {
  assert.equal(validateBalance(balance(), "owner").available, 470_000_000);
  for (const value of [
    balance({ accountID: "other" }),
    balance({ available: 500_000_000 }),
    balance({ scale: 1 }),
    balance({ spent: -1 }),
  ])
    assert.throws(() => validateBalance(value, "owner"));
});
test("missing service differs from an exhausted real balance", async () => {
  const s = studio();
  await refreshAICredits(s, async () => {
    throw new Error("404");
  });
  assert.equal(s.aiPhase, "unavailable");
  assert.equal(s.aiBalance, null);
  await refreshAICredits(s, async (path) =>
    path.endsWith("catalog")
      ? catalog
      : balance({ spent: 500_000_000, reserved: 0, available: 0 }),
  );
  assert.equal(s.aiPhase, "ready");
  assert.equal(s.aiBalance.available, 0);
  s.refreshAI = async () => {};
  await assert.rejects(requireHostedAI(s), /used up/);
});
test("a response for a previous account cannot restore its balance", async () => {
  const s = studio();
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const pending = refreshAICredits(s, async (path) => {
    await gate;
    return path.endsWith("catalog") ? catalog : balance();
  });
  s.account = { id: "other" };
  await refreshAICredits(s, async (path) =>
    path.endsWith("catalog")
      ? catalog
      : balance({
          accountID: "other",
          spent: 0,
          reserved: 0,
          available: 500_000_000,
        }),
  );
  release();
  await pending;
  assert.equal(s.aiBalance.accountID, "other");
  assert.equal(s.aiBalance.available, 500_000_000);
});
test("Cloud Pro is required and BYOK remains independent of hosted availability", async () => {
  const s = studio();
  s.refreshAI = async () => {};
  s.aiCatalog = catalog;
  s.aiBalance = balance({ allowance: 0, spent: 0, reserved: 0, available: 0 });
  await assert.rejects(requireHostedAI(s), /Cloud Pro/);
  s.providers = [
    { id: "hosted", hosted: true },
    { id: "byok", hosted: false },
    { id: "local", transport: "codex" },
  ];
  assert.deepEqual(
    providersForMode(s, "ada").map((p) => p.id),
    ["hosted"],
  );
  assert.deepEqual(
    providersForMode(s, "byok").map((p) => p.id),
    ["hosted", "byok"],
  );
});

test("blocked hosted admission preserves the editable draft and opens subscription details", async () => {
  const { runAgent } = await import("../src/agent.js");
  const s = studio();
  s.billingMode = "ada";
  s.prompt = "Create my game";
  s.aiCatalog = catalog;
  s.aiBalance = balance({ allowance: 0, spent: 0, reserved: 0, available: 0 });
  s.refreshAI = async () => {};
  await assert.rejects(runAgent(s, s.prompt), /Cloud Pro/);
  assert.equal(s.prompt, "Create my game");
  assert.equal(s.settings, true);
  assert.equal(s.running, undefined);
});

test("double Send cannot start overlapping credit admission", async () => {
  const { runAgent } = await import("../src/agent.js");
  const s = studio(); s.billingMode = "ada";
  s.aiCatalog = catalog; s.aiBalance = balance();
  let release, checks = 0;
  const gate = new Promise((resolve) => { release = resolve; });
  s.refreshAI = async () => { checks++; await gate; };
  const first = runAgent(s, "Create a game");
  await runAgent(s, "Create a game");
  assert.equal(checks, 1);
  release();
  await assert.rejects(first, /Choose a model/);
  assert.equal(s.admitting, false);
});
