import test from "node:test";
import assert from "node:assert/strict";
import { providersForMode, setBillingMode } from "../src/provider-settings.js";

function studio() {
  return {
    providers: [
      { id: "cloud", hosted: true, models: [{ id: "api-model", tools: true }] },
      { id: "local-codex", transport: "codex", models: [{ id: "codex-model", tools: true }] },
    ],
    billingMode: "byok",
    providerID: "cloud",
    modelID: "api-model",
    apiKey: "memory-only-key",
    emit() {},
  };
}

test("Codex selection uses its own models and preserves ordinary provider modes", () => {
  const s = studio();
  setBillingMode(s, "codex");
  assert.equal(s.providerID, "local-codex");
  assert.equal(s.modelID, "codex-model");
  assert.deepEqual(providersForMode(s).map((p) => p.id), ["local-codex"]);
  setBillingMode(s, "ada");
  assert.equal(s.providerID, "cloud");
  assert.equal(s.modelID, "api-model");
  assert.equal(s.apiKey, "memory-only-key");
  setBillingMode(s, "byok");
  assert.equal(s.providerID, "cloud");
});

test("a deployment without the local provider cannot silently route Codex to an API key", () => {
  const s = studio();
  s.providers = s.providers.slice(0, 1);
  setBillingMode(s, "codex");
  assert.equal(s.providerID, "");
  assert.equal(s.modelID, "");
  assert.equal(s.apiKey, "memory-only-key");
});
