import test from "node:test";
import assert from "node:assert/strict";
import { Studio } from "../src/studio.js";
import { Document, template } from "../src/documents.js";
import { runAgent } from "../src/agent.js";

test("commands inserted after ordinary text load the real workflow into the agent request", async () => {
  globalThis.window = { addEventListener() {} };
  const studio = new Studio();
  studio.billingMode = "byok";
  studio.apiKey = "fixture";
  studio.document = new Document(template(3));
  studio.workspace = { id: "slash-test", revision: 1 };
  studio.account = { id: "owner" };
  studio.providerID = "test";
  studio.modelID = "model";
  studio.providers = [{ id: "test", models: [{ id: "model", tools: true }] }];
  studio.save = async () => {};
  studio.emit = () => {};
  studio.changed = () => {};
  let expected;
  globalThis.fetch = async (url, options) => {
    if (url === "./agent-resources.json")
      return Response.json({
        skills: [
          {
            id: "my-workflow",
            description: "A test workflow",
            content: "EXPLICIT_WORKFLOW_CONTENT",
          },
        ],
      });
    assert.equal(url, "/v1/ai/generate");
    const request = JSON.parse(options.body);
    assert.equal(
      request.messages[0].content.includes(
        "[my-workflow]\nEXPLICIT_WORKFLOW_CONTENT",
      ),
      expected,
    );
    return new Response(
      'data: {"type":"text","text":"Ready"}\n\ndata: {"type":"complete"}\n\n',
      { headers: { "Content-Type": "text/event-stream" } },
    );
  };
  expected = true;
  assert.equal(
    await runAgent(studio, "Please use /my-workflow to inspect this game"),
    true,
  );
  expected = false;
  assert.equal(
    await runAgent(studio, "Read https://example.test/my-workflow"),
    true,
  );
});
