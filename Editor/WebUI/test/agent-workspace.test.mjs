import test from "node:test";
import assert from "node:assert/strict";
import { readFile, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { agentResources } from "../scripts/agent-resources.mjs";
import { Studio } from "../src/studio.js";
import {
  Document,
  template,
  file,
  exportZIP,
  importZIP,
} from "../src/documents.js";
import { chatState, sessionMessages } from "../src/chat.js";
import { runAgent, runTool, tools } from "../src/agent.js";
import {
  catalogID,
  receive,
  get,
  set,
  decodeFences,
  actionEnvelope,
} from "../src/a2ui.js";
import { sceneRevision } from "../src/scene-tools.js";
import { decode } from "../src/platform.js";
import { resolveLanguage, t } from "../src/localization.js";
test("agent localization follows the shared language preference without translating user text", () => {
  assert.equal(resolveLanguage("system", ["de-DE", "ru-RU", "en-US"]), "ru");
  assert.equal(resolveLanguage("en", ["ru-RU"]), "en");
  assert.equal(resolveLanguage("system", ["de-DE"]), "en");
  assert.equal(t("Conversation {0}", "Мира"), "Conversation Мира");
});
let catalog;
test.before(async () => {
  const folder = await mkdtemp(path.join(tmpdir(), "ada-web-agent-"));
  await agentResources(folder);
  catalog = JSON.parse(
    await readFile(path.join(folder, "agent-resources.json"), "utf8"),
  );
  await rm(folder, { recursive: true });
});
function harness() {
  globalThis.window = { addEventListener() {} };
  const s = new Studio();
  s.billingMode = "byok";
  s.apiKey = "fixture-key";
  s.document = new Document(template(3));
  s.workspace = { id: "project", revision: 1 };
  s.account = { id: "owner" };
  s.changed = () => {};
  s.emit = () => {};
  s.save = async () => {};
  s.providerID = "provider";
  s.modelID = "model";
  s.providers = [
    { id: "provider", models: [{ id: "model", tools: true, vision: true }] },
  ];
  globalThis.fetch = async (url) => {
    assert.equal(url, "./agent-resources.json");
    return Response.json(catalog);
  };
  s.updateChat(() => {});
  return s;
}
const envelope = (type, value) => ({ version: "v0.9.1", [type]: value });
test("attachments cannot write into another project after asynchronous file reading", async () => {
  for (const text of [true, false]) {
    const s = harness();
    let finish;
    const pending = new Promise((resolve) => {
      finish = resolve;
    });
    const input = {
      name: text ? "design.md" : "image.png",
      size: 1,
      text: () => pending,
      arrayBuffer: () => pending,
    };
    const attachment = s.attachFile(input);
    s.document = new Document(template(2));
    const files = s.snapshot.files.length;
    finish(text ? "notes" : new Uint8Array([1]).buffer);
    await assert.rejects(attachment, /different project/);
    assert.equal(s.snapshot.files.length, files);
  }
});
const create = (id = "form") =>
  envelope("createSurface", {
    surfaceId: id,
    catalogId: catalogID,
    sendDataModel: true,
  });
const components = (id = "form", button = "submit") =>
  envelope("updateComponents", {
    surfaceId: id,
    components: [
      {
        id: "root",
        component: "Column",
        children: ["name", "count", "button"],
      },
      {
        id: "name",
        component: "TextField",
        text: { path: "/npc/name" },
        placeholder: "NPC name",
      },
      {
        id: "count",
        component: "Slider",
        value: { path: "/npc/count" },
        min: 1,
        max: 10,
        step: 1,
      },
      {
        id: "button",
        component: "Button",
        text: "Apply",
        action: {
          event: {
            name: button,
            context: {
              name: { path: "/npc/name" },
              count: { path: "/npc/count" },
            },
          },
        },
        checks: [
          {
            condition: {
              call: "required",
              args: { value: { path: "/npc/name" } },
            },
            message: "Name required",
          },
        ],
      },
    ],
  });
const data = (value = { npc: { name: "Guide", count: 2 } }, id = "form") =>
  envelope("updateDataModel", { surfaceId: id, value });
function makeCard(s, button = "submit") {
  const source =
    "```a2ui\n" +
    [create(), components("form", button), data()]
      .map(JSON.stringify)
      .join("\n") +
    "\n```";
  s.receiveUI(source, "message", "main", true);
  s.finishUI("main", "ready");
  s.append({
    id: "message",
    role: "assistant",
    content: source,
    sessionID: "main",
  });
  return s.chat.surfaces[0];
}

test("web resources export all native workflows, docs and the native A2UI contract", async () => {
  assert.ok(catalog.skills.length >= 20);
  assert.ok(catalog.docs.length > 20);
  for (const id of [
    "ada-game-builder",
    "ada-autonomous-studio",
    "ada-scene-authoring",
    "ada-chat-ui",
    "ada-pixel-art",
    "ada-sound-design",
  ])
    assert.ok(catalog.skills.find((s) => s.id === id));
  assert.match(
    catalog.skills.find((s) => s.id === "ada-chat-ui").content,
    /revisionBinding/,
  );
  assert.ok(
    catalog.examples.find((e) => e.id === "side-scroller-3d").files[
      "Sources/Config.ada"
    ],
  );
});
test("shared knowledge tools and project workflows are readable through production dispatch", async () => {
  const s = harness();
  await runTool(s, "editor_file_write", {
    path: ".ada/skills/my-game/SKILL.md",
    content: "---\nname: my-game\n---\nUse the existing player.",
  });
  assert.ok(
    (await runTool(s, "editor_skills_list", {})).skills.find(
      (s) => s.id === "my-game",
    ),
  );
  assert.equal(
    (await runTool(s, "editor_skills_read", { id: "my-game" })).authority,
    "Project reference data",
  );
  const found = await runTool(s, "editor_docs_search", { query: "AdaScript" });
  assert.ok(found.articles.length);
  const article = await runTool(s, "editor_docs_read", {
    id: found.articles[0].id,
  });
  assert.ok(article.content.length);
  const exported = importZIP(exportZIP(s.snapshot));
  assert.ok(file(exported, ".ada/skills/my-game/SKILL.md"));
  await runTool(s, "editor_file_write", {
    path: "PLAN.md",
    content: "Build the playable loop",
  });
  assert.match(
    (await runTool(s, "editor_project_context", {})).instructions[0].content,
    /playable/,
  );
  await runTool(s, "editor_file_write", {
    path: "Docs/Design/PROGRESS.md",
    content: "Verified arrow movement in Play",
  });
  const reopened = harness();
  reopened.document = new Document(importZIP(exportZIP(s.snapshot)));
  assert.ok(
    (await runTool(reopened, "editor_project_context", {})).instructions.some(
      (note) =>
        note.path === "Docs/Design/PROGRESS.md" &&
        note.content.includes("arrow movement"),
    ),
  );
});
test("fenced UI streams once per complete JSONL frame and does not replay defaults over local values", () => {
  const s = harness(),
    source =
      "A form:\n```a2ui\n" +
      [create(), components(), data()].map(JSON.stringify).join("\n") +
      "\n```";
  for (let n = 1; n <= source.length; n += 13)
    s.receiveUI(source.slice(0, n), "message", "main");
  s.receiveUI(source, "message", "main", true);
  s.finishUI("main", "ready");
  const card = s.chat.surfaces[0];
  s.editSurface(card.id, card.generation, "/npc/name", "Changed locally");
  s.receiveUI(source, "message", "main", true);
  assert.equal(s.chat.surfaces.length, 1);
  assert.equal(s.chat.surfaces[0].data.npc.name, "Changed locally");
  assert.equal(s.chat.events.filter((e) => e.type === "a2ui-error").length, 0);
  const text = "```text\n```a2ui\n" + JSON.stringify(create()) + "\n```\n```";
  assert.equal(decodeFences(text, true).frames.length, 0);
});
test("malformed UI updates are atomic; cycles, shared mounts and type conflicts retain the valid surface", () => {
  const s = harness();
  const card = makeCard(s),
    before = structuredClone(card);
  for (const invalid of [
    { id: "root", component: "HTML", html: "<script>bad</script>" },
    { id: "root", component: "Column", children: ["root"] },
    { id: "root", component: "Column", children: ["name", "count", "other"] },
    { id: "name", component: "TextField", text: { path: "/npc/count" } },
  ]) {
    const list = structuredClone(s.chat.surfaces);
    if (invalid.children?.includes("other"))
      list[0].components.other = {
        id: "other",
        component: "Column",
        children: ["name"],
      };
    const baseline = structuredClone(list);
    assert.throws(() =>
      receive(
        list,
        envelope("updateComponents", {
          surfaceId: "form",
          components: [invalid],
        }),
        { sessionID: "main", owner: "provider:model", messageID: "new" },
      ),
    );
    assert.deepEqual(list, baseline);
  }
  const bad =
    "```a2ui\n" +
    JSON.stringify(
      envelope("updateComponents", {
        surfaceId: "form",
        components: [{ id: "root", component: "iframe" }],
      }),
    ) +
    "\n```";
  s.receiveUI(bad, "bad", "main", true);
  assert.deepEqual(s.chat.surfaces[0].components, before.components);
  assert.match(s.chat.surfaces[0].error, /Unsupported/);
});
test("JSON pointers preserve dots, escapes and arrays and reject prototype pollution and sparse writes", () => {
  let model = { "a/b": { "x.y": [1, 2] } };
  model = set(model, "/a~1b/x.y/2", 3);
  assert.equal(get(model, "/a~1b/x.y/2"), 3);
  set(model, "/a~1b/x.y/0", null, true);
  assert.equal(model["a/b"]["x.y"][0], null);
  assert.throws(() => set(model, "/__proto__/polluted", true));
  assert.throws(() => set(model, "/a~1b/x.y/9", 3));
  assert.equal({}.polluted, undefined);
});
test("surface ownership, generations, sessions, validation and action metadata are enforced", async () => {
  const s = harness(),
    card = makeCard(s);
  const event = actionEnvelope(card, "button");
  assert.equal(event.envelope.action.context.name, "Guide");
  assert.deepEqual(Object.keys(event.metadata.a2uiClientDataModel.surfaces), [
    "form",
  ]);
  s.editSurface(card.id, card.generation, "/npc/name", "");
  assert.throws(() => actionEnvelope(s.chat.surfaces[0], "button"), /invalid/);
  s.editSurface(card.id, card.generation, "/npc/name", "Keeper");
  assert.throws(
    () => s.editSurface(card.id, "stale", "/npc/name", "bad"),
    /Card unavailable/,
  );
  s.providerID = "different";
  await assert.rejects(
    s.submitSurface(card.id, card.generation, "button"),
    /Card unavailable/,
  );
  s.providerID = "provider";
  s.newSession();
  await assert.rejects(
    s.submitSurface(card.id, card.generation, "button"),
    /Card unavailable/,
  );
  s.switchSession("main");
  s.prompt = "Unsent draft";
  let submission;
  s.send = async (text, options) => {
    submission = { text, options };
    assert.equal(s.prompt, "Unsent draft");
    return true;
  };
  await s.submitSurface(card.id, card.generation, "button");
  assert.match(submission.text, /Keeper/);
  assert.equal(submission.options.preserveDraft, true);
  assert.equal(s.prompt, "Unsent draft");
  assert.equal(s.chat.surfaces[0].status, "submitted");
});
test("local A2UI scene tools check revisions, apply one undo transaction and support guarded card Undo", async () => {
  const s = harness(),
    player = s.scene.entities.find((e) => e.name === "Player"),
    revision = await sceneRevision(s.snapshot);
  const controls = components("form", "editor.scene.setColor");
  controls.updateComponents.components[3].action.event.context = {
    path: (await runTool(s, "editor_scene_get", {})).path,
    expectedRevision: { path: "/scene/revision" },
    revisionBinding: "/scene/revision",
    entityID: player.id,
    typeName: "AdaScene.Mesh3DComponent",
    field: "color",
    color: { path: "/color" },
  };
  const source =
    "```a2ui\n" +
    [
      create(),
      controls,
      data({
        npc: { name: "Guide", count: 2 },
        scene: { revision },
        color: "#ff0000",
      }),
    ]
      .map(JSON.stringify)
      .join("\n") +
    "\n```";
  s.receiveUI(source, "message", "main", true);
  s.finishUI("main", "ready");
  const card = s.chat.surfaces[0],
    before = structuredClone(s.scene);
  await s.submitSurface(card.id, card.generation, "button");
  assert.equal(s.document.undoStack.length, 1);
  assert.equal(
    s.scene.entities.find((e) => e.id === player.id).components[
      "AdaScene.Mesh3DComponent"
    ].color.red,
    1,
  );
  await s.undoSurface(card.id, card.generation);
  assert.deepEqual(s.scene, before);
  s.editScene((scene) => {
    scene.entities[0].name += " changed";
  });
  await assert.rejects(
    s.submitSurface(card.id, card.generation, "button"),
    /Scene changed/,
  );
  assert.equal(s.document.undoStack.length, 3);
});
test("chat session drafts and card input survive project undo and reopen without replay", () => {
  const s = harness(),
    card = makeCard(s);
  s.editSurface(card.id, card.generation, "/npc/name", "Local");
  s.prompt = "First draft";
  s.newSession();
  s.prompt = "Second draft";
  s.switchSession("main");
  assert.equal(s.prompt, "First draft");
  s.document.write("Sources/Changed.ada", "// edit");
  s.document.undo();
  assert.equal(s.chat.surfaces[0].data.npc.name, "Local");
  const reopened = new Document(s.snapshot);
  assert.equal(chatState(reopened.snapshot).surfaces[0].data.npc.name, "Local");
  assert.equal(chatState(reopened.snapshot).sessions[1].draft, "Second draft");
});
test("explicit ask permissions wait for the user and cancel safely", async () => {
  const s = harness();
  s.updateChat((c) => {
    c.sessions[0].permission = "ask";
  });
  s.runningSessionID = "main";
  const controller = new AbortController();
  let allowed = false;
  const pending = s
    .requestTool(
      "editor_file_write",
      { path: "Sources/Test.ada" },
      controller.signal,
    )
    .then(() => (allowed = true));
  await Promise.resolve();
  assert.equal(allowed, false);
  s.permissionRequest.decide("once");
  await pending;
  assert.equal(allowed, true);
  const denied = s.requestTool("editor_file_write", {}, controller.signal);
  controller.abort();
  await assert.rejects(denied, /declined/);
  assert.equal(s.permissionRequest, null);
  s.updateChat((c) => {
    c.sessions[0].mode = "plan";
  });
  await assert.rejects(
    s.requestTool("editor_file_write", {}, new AbortController().signal),
    /Discuss mode/,
  );
});
test("agent turns remain attached to their originating session while another conversation is opened", async () => {
  const s = harness();
  let release, started;
  const arrived = new Promise((resolve) => (started = resolve)),
    gate = new Promise((resolve) => (release = resolve));
  globalThis.fetch = async (url, options) => {
    if (url === "./agent-resources.json") return Response.json(catalog);
    assert.equal(url, "/v1/ai/generate");
    const request = JSON.parse(options.body);
    assert.ok(request.messages[0].content.includes("ada-game-builder"));
    assert.ok(
      request.tools.some((t) => t.function.name === "editor_skills_read"),
    );
    started();
    await gate;
    return new Response(
      "data: " +
        JSON.stringify({ type: "text", text: "First session response" }) +
        "\n\ndata: " +
        JSON.stringify({ type: "complete" }) +
        "\n\n",
      { headers: { "Content-Type": "text/event-stream" } },
    );
  };
  const run = runAgent(s, "First goal");
  await arrived;
  s.newSession();
  const other = s.session.id;
  s.prompt = "Second draft";
  release();
  await run;
  assert.equal(s.session.id, other);
  assert.equal(s.prompt, "Second draft");
  assert.equal(sessionMessages(s.snapshot, other).length, 0);
  assert.equal(
    sessionMessages(s.snapshot, "main").at(-1).content,
    "First session response",
  );
  assert.equal(s.running, false);
});
test("A2UI rejects a too-large durable undo record before changing any scene file", async () => {
  const s = harness(),
    revision = await sceneRevision(s.snapshot),
    player = s.scene.entities.find((e) => e.name === "Player");
  const c = components("form", "editor.scene.spawn");
  c.updateComponents.components[3].action.event.context = {
    path: (await runTool(s, "editor_scene_get", {})).path,
    expectedRevision: { path: "/scene/revision" },
    revisionBinding: "/scene/revision",
    entityID: player.id,
    count: 1,
    spacing: 2,
  };
  const source =
    "```a2ui\n" +
    [
      create(),
      c,
      data({ npc: { name: "Guide", count: 2 }, scene: { revision } }),
    ]
      .map(JSON.stringify)
      .join("\n") +
    "\n```";
  s.receiveUI(source, "message", "main", true);
  s.finishUI("main", "ready");
  const current = JSON.stringify(s.snapshot.messages).length;
  s.updateChat((c) => {
    c.events.push({
      id: "large",
      sessionID: "main",
      type: "tool",
      summary: "x".repeat(4 * 1024 * 1024 - current - 1500),
    });
  });
  const before = structuredClone(s.scene),
    card = s.chat.surfaces[0];
  await assert.rejects(
    s.submitSurface(card.id, card.generation, "button"),
    /limit/,
  );
  assert.deepEqual(s.scene, before);
  assert.equal(s.document.undoStack.length, 0);
});
test("invalid persisted surfaces fail validation instead of crashing the renderer", () => {
  const s = harness();
  makeCard(s);
  const malformed = structuredClone(s.snapshot);
  chatState(malformed).surfaces[0].components.root.children = ["root"];
  assert.throws(() => new Document(malformed), /Cyclic/);
});
test("a full real conversation cannot leave the agent stuck running during cleanup", async () => {
  const s = harness(),
    snapshot = structuredClone(s.snapshot);
  snapshot.messages.push(
    ...Array.from({ length: 999 }, () => ({
      id: crypto.randomUUID(),
      role: "assistant",
      content: "",
    })),
  );
  s.document = new Document(snapshot);
  await runAgent(s, "Another request");
  assert.equal(s.running, false);
  assert.equal(s.agent, null);
});
test("cancelling a streamed form persists an interrupted card without replaying it", async () => {
  const s = harness();
  let arrived;
  const started = new Promise((resolve) => (arrived = resolve));
  const partial =
    "```a2ui\n" +
    [create(), components(), data()].map(JSON.stringify).join("\n") +
    "\n";
  globalThis.fetch = async (url, options) => {
    if (url === "./agent-resources.json") return Response.json(catalog);
    return new Response(
      new ReadableStream({
        start(controller) {
          controller.enqueue(
            new TextEncoder().encode(
              "data: " +
                JSON.stringify({ type: "text", text: partial }) +
                "\n\n",
            ),
          );
          options.signal.addEventListener("abort", () =>
            controller.error(new DOMException("Cancelled", "AbortError")),
          );
          arrived();
        },
      }),
    );
  };
  const run = runAgent(s, "Form request");
  await started;
  await new Promise((resolve) => setImmediate(resolve));
  s.stopAgent();
  await run;
  assert.equal(s.running, false);
  assert.equal(s.chat.surfaces[0].status, "cancelled");
  assert.match(sessionMessages(s.snapshot, "main").at(-1).content, /a2ui/);
  const card = s.chat.surfaces[0];
  assert.throws(
    () => s.editSurface(card.id, card.generation, "/npc/name", "No"),
    /Card unavailable/,
  );
  s.restoreSurface(card.id, card.generation);
  assert.equal(s.chat.surfaces[0].status, "ready");
});

test("Create uses the selected world template and passes player mode into the real agent request", async () => {
  for (const dimension of [2, 3]) {
    const s = harness();
    s.document = null;
    let created, request;
    s.createSnapshot = async (snapshot) => {
      created = snapshot;
      s.document = new Document(snapshot);
      s.workspace = { id: "new-project", revision: 1 };
    };
    const resources = globalThis.fetch;
    globalThis.fetch = async (url, options) => {
      if (url === "/v1/ai/generate") {
        request = JSON.parse(options.body);
        return new Response(
          'data: {"type":"text","text":"Ready"}\ndata: {"type":"complete"}\n',
          { headers: { "Content-Type": "text/event-stream" } },
        );
      }
      return resources(url, options);
    };
    const prompt = "My original idea";
    assert.equal(
      await runAgent(s, prompt, {
        creation: { dimension, players: "multiplayer" },
      }),
      true,
    );
    const meta = JSON.parse(decode(file(created, ".ada/project.json").data));
    assert.equal(meta.runtime.plugins.preset, `game${dimension}d`);
    assert(
      request.messages.some(
        (message) =>
          message.content.includes(`World: ${dimension}D`) &&
          message.content.includes("Players: multiplayer"),
      ),
    );
    const authored = s.snapshot.messages.find(
      (message) => message.role === "user" && message.displayContent === prompt,
    );
    assert(authored.content.startsWith(prompt));
    assert.equal(authored.displayContent, prompt);
  }
});

test("staged media survive admission and Cloud errors, then reach the agent with real image input and saved asset paths", async () => {
  const s = harness();
  s.document = null;
  s.prompt = "Use my reference, character and soundtrack";
  const preview = "data:image/jpeg;base64,AQID";
  const staged = [
    {
      id: "picture",
      path: "Assets/Imports/reference.png",
      data: btoa("original image bytes"),
      name: "reference.png",
      kind: "image",
      size: 20,
      preview,
    },
    {
      id: "model",
      path: "Assets/Imports/character.glb",
      data: btoa("model bytes"),
      name: "character.glb",
      kind: "model",
      size: 11,
    },
    {
      id: "audio",
      path: "Assets/Imports/music.wav",
      data: btoa("music bytes"),
      name: "music.wav",
      kind: "audio",
      size: 11,
    },
  ];
  s.homeAttachments = staged;
  s.apiKey = "";
  await assert.rejects(runAgent(s, s.prompt), /API key/);
  assert.equal(s.homeAttachments, staged);
  assert.equal(s.document, null);
  assert.ok(s.prompt);
  s.apiKey = "fixture-key";
  s.createSnapshot = async () => {
    throw new Error("Cloud offline");
  };
  await assert.rejects(runAgent(s, s.prompt), /Cloud offline/);
  assert.equal(s.homeAttachments, staged);
  assert.equal(s.document, null);
  assert.ok(s.prompt);
  let created, request;
  s.createSnapshot = async (snapshot) => {
    created = snapshot;
    s.document = new Document(snapshot);
    s.workspace = { id: "media-project", revision: 1 };
  };
  const resources = globalThis.fetch;
  globalThis.fetch = async (url, options) => {
    if (url === "/v1/ai/generate") {
      request = JSON.parse(options.body);
      return new Response(
        'data: {"type":"text","text":"Ready"}\ndata: {"type":"complete"}\n',
      );
    }
    return resources(url, options);
  };
  assert.equal(await runAgent(s, s.prompt), true);
  assert.equal(s.homeAttachments.length, 0);
  for (const item of staged)
    assert.equal(file(created, item.path).data, item.data);
  assert.equal(chatState(created).sessions[0].attachments.length, 3);
  const message = request.messages.find((message) =>
    message.images?.includes(preview),
  );
  assert.ok(message, "the image is a model input, not only a filename");
  for (const item of staged) assert.ok(message.content.includes(item.path));
  assert.deepEqual(
    s.snapshot.messages
      .find((message) => message.attachments?.length)
      .attachments.map((item) => item.kind),
    ["image", "model", "audio"],
  );
  assert.equal(s.session.attachments.length, 0);
});

test("sending from Create saves the retained project and creates a separate game without touching its chat", async () => {
  const s = harness(),
    previous = s.document;
  previous.write("Docs/kept.md", "Keep this edit");
  previous.chat((chat) => {
    chat.sessions[0].draft = "Old project draft";
  });
  s.prompt = "Old project draft";
  s.homePrompt = "A new 2D adventure";
  const item = {
    id: "new-file",
    path: "Assets/Imports/new.glb",
    data: btoa("model bytes"),
    name: "new.glb",
    kind: "model",
    size: 11,
  };
  s.homeAttachments = [item];
  const original = JSON.stringify(previous.snapshot),
    undo = previous.undoStack.length;
  const options = {
    newProject: true,
    creation: { dimension: 2, players: "single" },
  };
  const order = [];
  s.save = async () => {
    order.push("save");
    throw new Error("Cannot save old project");
  };
  s.createSnapshot = async () => {
    throw new Error("Must not create before saving");
  };
  await assert.rejects(
    runAgent(s, s.homePrompt, options),
    /Cannot save old project/,
  );
  assert.equal(s.document, previous);
  assert.equal(s.homePrompt, "A new 2D adventure");
  assert.equal(s.prompt, "Old project draft");
  assert.equal(s.homeAttachments.length, 1);
  s.save = async () => {
    order.push("save");
  };
  s.createSnapshot = async () => {
    order.push("create");
    throw new Error("Cloud offline");
  };
  await assert.rejects(runAgent(s, s.homePrompt, options), /Cloud offline/);
  assert.equal(s.document, previous);
  assert.equal(s.homePrompt, "A new 2D adventure");
  assert.equal(JSON.stringify(previous.snapshot), original);
  order.length = 0;
  let created, request;
  s.createSnapshot = async (snapshot) => {
    order.push("create");
    created = snapshot;
    s.document = new Document(snapshot);
    s.workspace = { id: "new-game", revision: 1 };
    s.prompt = s.session.draft;
    s.selected = null;
    s.latestCodeSelection = "";
  };
  const resources = globalThis.fetch;
  globalThis.fetch = async (url, input) => {
    if (url === "/v1/ai/generate") {
      request = JSON.parse(input.body);
      return new Response(
        'data: {"type":"text","text":"Ready"}\ndata: {"type":"complete"}\n',
      );
    }
    return resources(url, input);
  };
  assert.equal(await runAgent(s, s.homePrompt, options), true);
  assert.deepEqual(order.slice(0, 2), ["save", "create"]);
  assert.notEqual(s.document, previous);
  assert.equal(s.workspace.id, "new-game");
  assert.equal(
    JSON.parse(decode(file(created, ".ada/project.json").data)).runtime.plugins
      .preset,
    "game2d",
  );
  assert.equal(file(created, item.path).data, item.data);
  assert.equal(s.homePrompt, "");
  assert.equal(s.homeAttachments.length, 0);
  assert.equal(JSON.stringify(previous.snapshot), original);
  assert.equal(previous.undoStack.length, undo);
  const content = request.messages.map((message) => message.content).join("\n");
  assert(content.includes("A new 2D adventure"));
  assert(!content.includes("Old project draft"));
});
