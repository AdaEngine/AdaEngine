import test from "node:test";
import assert from "node:assert/strict";
import { providersForMode, setBillingMode } from "../src/provider-settings.js";

function studio() {
  return {
    providers: [
      { id: "cloud", hosted: true, models: [{ id: "api-model", tools: true }] },
      {
        id: "local-codex",
        transport: "codex",
        models: [{ id: "codex-model", tools: true }],
      },
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
  assert.deepEqual(
    providersForMode(s).map((p) => p.id),
    ["local-codex"],
  );
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

test("development metadata makes Local Codex selectable before Cloud sign-in without bypassing identity", async () => {
  const { Studio } = await import("../src/studio.js");
  const originalFetch = globalThis.fetch,
    originalWindow = globalThis.window;
  globalThis.window = { addEventListener() {} };
  const calls = [];
  const provider = {
    id: "local-codex",
    title: "Codex",
    transport: "codex",
    models: [{ id: "listed", title: "Listed", tools: true }],
  };
  globalThis.fetch = async (url) => {
    calls.push(url);
    if (url === "/__dev/studio-config")
      return Response.json({
        development: true,
        codexEnabled: true,
        providers: [provider],
      });
    if (url === "/v1/me" || url === "/v1/auth/refresh")
      return Response.json({ error: { message: "Sign in" } }, { status: 401 });
    throw new Error("Unexpected request: " + url);
  };
  try {
    const s = new Studio();
    await s.start();
    assert.equal(s.status, "signedout");
    assert.equal(s.account, null);
    assert.equal(s.billingMode, "codex");
    assert.equal(s.providerID, "local-codex");
    assert.equal(s.modelID, "listed");
    assert.equal(s.development.codexEnabled, true);
    assert(calls.includes("/v1/me"));
    assert(!calls.includes("/v1/ai/generate"));
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.window = originalWindow;
  }
});

test("a hosted deployment or disabled local server cannot invent a Codex provider", async () => {
  const { developmentAssistant } = await import("../src/provider-settings.js");
  assert.equal(
    await developmentAssistant(
      async () =>
        new Response("<html>app</html>", {
          headers: { "Content-Type": "text/html" },
        }),
    ),
    null,
  );
  assert.equal(
    await developmentAssistant(async () => new Response("", { status: 404 })),
    null,
  );
  const disabled = await developmentAssistant(async () =>
    Response.json({ development: true, codexEnabled: false, providers: [] }),
  );
  assert.deepEqual(disabled.providers, []);
});
