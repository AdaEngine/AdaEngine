import test from "node:test";
import assert from "node:assert/strict";
import { Studio } from "../src/studio.js";
import { Document, template, scenePath } from "../src/documents.js";
import { runAgent } from "../src/agent.js";
const anchor = { x: 200, y: 180 };
const image = "data:image/jpeg;base64," + "A".repeat(90000);
function harness() {
  globalThis.window = { addEventListener() {} };
  const s = new Studio();
  s.billingMode = "byok";
  s.apiKey = "fixture-key";
  s.document = new Document(template(3));
  s.changed = () => {};
  s.emit = () => {};
  s.save = async () => {};
  s.account = { id: "owner" };
  s.providerID = "provider";
  s.modelID = "model";
  s.providers = [
    { id: "provider", models: [{ id: "model", tools: true, vision: true }] },
  ];
  s.updateChat(() => {});
  s.preview.ready = true;
  s.preview.editorRevision = "render-1";
  return s;
}
function add(s, note = "Make the object brighter") {
  const entity = s.scene.entities.find((e) => e.name === "Player");
  s.annotateEntity(entity.id, anchor);
  s.annotationDraft.note = note;
  assert.equal(s.addAnnotation(), true);
  return s.session.annotations.at(-1);
}
test("numbered annotations edit in place, retain IDs and survive deletion and reopen", () => {
  const s = harness();
  const first = add(s, "First note"),
    second = add(s, "Second note");
  assert.equal(first.number, 1);
  assert.equal(second.number, 2);
  assert.equal(s.annotationMode, true);
  s.editAnnotation(second.id, anchor);
  s.annotationDraft.note = "Updated second note";
  s.addAnnotation();
  assert.equal(s.session.annotations.length, 2);
  assert.equal(s.session.annotations[1].id, second.id);
  assert.equal(s.session.annotations[1].number, 2);
  assert.equal(s.prompt.includes("Second note"), false);
  s.removeAnnotation(first.id);
  const third = add(s, "Third note");
  assert.equal(third.number, 3);
  s.document = new Document(s.snapshot);
  assert.deepEqual(
    s.session.annotations.map((r) => r.number),
    [2, 3],
  );
});
test("popup editing uses the current manually edited annotation block", () => {
  const s = harness(),
    first = add(s, "Original"),
    second = add(s, "Other note");
  s.prompt = s.prompt.replace("Original", "Manually corrected");
  s.editAnnotation(first.id, anchor);
  assert.equal(s.annotationDraft.note, "Manually corrected");
  s.annotationDraft.note = "Final correction";
  s.addAnnotation();
  assert.ok(s.prompt.includes("Final correction"));
  assert.ok(s.prompt.includes(second.fragment));
  assert.equal(s.prompt.includes("Manually corrected"), false);
});
test("annotation notes enter the existing composer and persistent session without sending or editing the scene", () => {
  const s = harness(),
    before = structuredClone(s.scene);
  let sends = 0;
  s.send = () => ++sends;
  s.prompt = "Keep the current game objective.";
  const item = add(s);
  assert.equal(sends, 0);
  assert.equal(s.snapshot.messages.filter((m) => m.role === "user").length, 0);
  assert.deepEqual(s.scene, before);
  assert.equal(s.document.undoStack.length, 0);
  assert.ok(s.prompt.startsWith("Keep the current game objective."));
  assert.ok(s.prompt.includes("Make the object brighter"));
  assert.equal(
    item.target.entityID,
    s.scene.entities.find((e) => e.name === "Player").id,
  );
  assert.equal(item.target.path, scenePath(s.snapshot));
  const restored = new Document(s.snapshot);
  s.document = restored;
  assert.equal(s.session.annotations[0].id, item.id);
  assert.equal(s.session.draft, s.prompt);
  s.newSession();
  assert.equal(s.session.annotations?.length || 0, 0);
  s.switchSession("main");
  assert.equal(s.prompt, s.session.draft);
  assert.equal(s.session.annotations.length, 1);
  s.removeAnnotation(item.id);
  assert.equal(s.prompt, "Keep the current game objective.");
  assert.equal(s.session.annotations.length, 0);
  assert.equal(s.annotationMode, false);
});
test("A2UI annotations identify the actual component without submitting its action or changing values", () => {
  const s = harness();
  s.receiveUI(
    "```a2ui\n" +
      [
        {
          version: "v0.9.1",
          createSurface: {
            surfaceId: "npc",
            catalogId: "https://adaengine.org/a2ui/catalogs/forms/v1",
          },
        },
        {
          version: "v0.9.1",
          updateComponents: {
            surfaceId: "npc",
            components: [
              { id: "root", component: "Column", children: ["apply"] },
              {
                id: "apply",
                component: "Button",
                text: "Apply color",
                action: { event: { name: "submit_npc" } },
              },
            ],
          },
        },
      ]
        .map(JSON.stringify)
        .join("\n") +
      "\n```",
    "message",
    "main",
    true,
  );
  s.finishUI("main", "ready");
  const card = s.chat.surfaces[0];
  s.annotateUI(card.id, card.generation, "apply", anchor);
  s.annotationDraft.note = "Make this button larger";
  s.addAnnotation();
  assert.equal(s.chat.surfaces[0].status, "ready");
  assert.deepEqual(s.chat.surfaces[0].data, {});
  assert.equal(s.session.annotations[0].target.componentID, "apply");
  assert.equal(s.session.annotations[0].target.surfaceID, "npc");
  assert.equal(s.session.annotations[0].target.componentType, "Button");
  assert.throws(
    () => s.annotateUI("npc", "old-generation", "apply", anchor),
    /no longer available/,
  );
});
test("marked preview capture uses normalized coordinates and discards cancelled or stale captures", async () => {
  const s = harness(),
    calls = [],
    id = s.scene.entities.find((e) => e.name === "Player").id;
  s.preview.message = async (type, payload) => {
    calls.push({ type, payload });
    return type === "editor" ? { entityID: id } : image;
  };
  await s.annotatePreview({ x: 0.25, y: 0.5 }, anchor);
  assert.equal(s.annotationDraft.target.entityID, id);
  assert.equal(s.annotationDraft.image, image);
  assert.equal(s.annotationDraft.busy, false);
  assert.deepEqual(
    calls.map((c) => c.type),
    ["editor", "capture"],
  );
  assert.equal(calls[0].payload.revision, "render-1");
  assert.deepEqual(calls[1].payload.point, { x: 0.25, y: 0.5 });
  s.cancelAnnotation();
  s.playing = true;
  let finish;
  s.preview.message = () => new Promise((resolve) => (finish = resolve));
  const capture = s.annotatePreview({ x: 0.2, y: 0.3 }, anchor);
  s.cancelAnnotation();
  finish(image);
  await capture;
  assert.equal(s.annotationDraft, null);
  const stale = s.annotatePreview({ x: 0.2, y: 0.3 }, anchor);
  s.preview.editorRevision = "render-2";
  finish(image);
  await stale;
  assert.match(s.annotationDraft.error, /preview changed/);
  assert.equal(s.addAnnotation(), false);
});
test("only Send sends annotations, preserves edited composer text, and budgets marked images separately", async () => {
  const s = harness();
  add(s, "OLD_POPUP_TEXT");
  const note = s.session.annotations[0];
  s.updateChat((c) => {
    c.sessions[0].annotations[0].image = image;
  });
  add(s, "Second annotation");
  s.updateChat((c) => {
    c.sessions[0].annotations[1].image = image;
  });
  s.prompt = s.prompt.replace("OLD_POPUP_TEXT", "EDITED_COMPOSER_TEXT");
  let request;
  globalThis.fetch = async (url, options) => {
    if (url === "./agent-resources.json") return Response.json({ skills: [] });
    assert.equal(url, "/v1/ai/generate");
    request = JSON.parse(options.body);
    return new Response(
      'data: {"type":"text","text":"Received"}\n\ndata: {"type":"complete"}\n\n',
    );
  };
  await runAgent(s, s.prompt);
  const sent = request.messages.find(
    (m) => m.content.includes("EDITED_COMPOSER_TEXT") && m.images,
  );
  assert.ok(sent);
  assert.equal(sent.images.length, 2);
  assert.ok(sent.content.includes(note.target.entityID));
  assert.ok(sent.content.includes('"imageIndex":2'));
  assert.ok(sent.content.includes('"number":1'));
  assert.ok(sent.content.includes('"number":2'));
  assert.equal(request.messages.filter((m) => m.images).length, 1);
  assert.equal(sent.content.includes("OLD_POPUP_TEXT"), false);
  assert.equal(s.session.annotations.length, 0);
});
test("annotation context remains in the composer during unrelated A2UI replies, and removal preserves manual edits", async () => {
  const s = harness();
  const item = add(s, "Original note");
  s.prompt = s.prompt.replace("Original note", "Manually edited note");
  const draft = s.prompt;
  globalThis.fetch = async (url) =>
    url === "./agent-resources.json"
      ? Response.json({ skills: [] })
      : new Response(
          'data: {"type":"text","text":"UI reply"}\n\ndata: {"type":"complete"}\n\n',
        );
  await runAgent(s, "[A2UI user action]", { preserveDraft: true });
  assert.equal(s.prompt, draft);
  assert.equal(s.session.annotations.length, 1);
  s.removeAnnotation(item.id);
  assert.equal(s.prompt, draft);
});
test("annotation limits reject before changing a persisted draft", () => {
  const s = harness();
  for (let i = 0; i < 8; i++) add(s, "Note " + i);
  const prompt = s.prompt;
  assert.throws(() => add(s), /eight annotations/);
  assert.equal(s.prompt, prompt);
  assert.equal(s.session.annotations.length, 8);
  s.editAnnotation(s.session.annotations[7].id, anchor);
  s.annotationDraft.note = "Updated eighth note";
  assert.equal(s.addAnnotation(), true);
  assert.equal(s.session.annotations.length, 8);
  assert.equal(s.session.annotations[7].number, 8);
});
test("adding and removing a note preserve whitespace in the existing composer", () => {
  const s = harness();
  const draft = "Keep this code block:\n```ada\n  // note\n```\n\n\n";
  s.prompt = draft;
  const item = add(s);
  assert.ok(s.prompt.startsWith(draft));
  s.removeAnnotation(item.id);
  assert.equal(s.prompt, draft);
});
