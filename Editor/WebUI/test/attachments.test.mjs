import test from "node:test";
import assert from "node:assert/strict";
import {
  attachmentKind,
  attachFiles,
  prepareAttachment,
  removeAttachment,
  pcmWAV,
  putAttachments,
} from "../src/attachments.js";
import {
  Document,
  template,
  exportZIP,
  importZIP,
  file,
} from "../src/documents.js";
import { chatState } from "../src/chat.js";
import { bytes, base64 } from "../src/platform.js";
import { runTool } from "../src/agent.js";

const input = (name, data) => ({
  name,
  size: data.byteLength,
  arrayBuffer: async () => data.slice().buffer,
});
const model = () => {
  const json = new TextEncoder().encode(
    '{"asset":{"version":"2.0"},"scenes":[{}]} ',
  );
  const padded = Math.ceil(json.length / 4) * 4,
    data = new Uint8Array(20 + padded),
    view = new DataView(data.buffer);
  view.setUint32(0, 0x46546c67, true);
  view.setUint32(4, 2, true);
  view.setUint32(8, data.length, true);
  view.setUint32(12, padded, true);
  view.setUint32(16, 0x4e4f534a, true);
  data.fill(32, 20);
  data.set(json, 20);
  return data;
};
const audio = {
  numberOfChannels: 2,
  length: 4,
  sampleRate: 44100,
  getChannelData: (channel) =>
    Float32Array.from(channel ? [0, -0.5, 0.5, 1] : [0, 0.25, -1, 1]),
};
function studio(document = null) {
  return {
    document,
    homeAttachments: [],
    emit() {},
    changed() {},
    get snapshot() {
      return this.document?.snapshot;
    },
    get session() {
      return chatState(this.snapshot).sessions[0];
    },
    updateChat(update) {
      this.document.chat(update);
    },
  };
}

test("pre-project attachments preserve file names and bytes, can be removed and are imported atomically with the new project", async () => {
  const s = studio(),
    glb = model(),
    wav = pcmWAV(audio);
  await attachFiles(s, [input("герой.glb", glb), input("music.wav", wav)]);
  assert.equal(s.document, null);
  assert.deepEqual(
    s.homeAttachments.map((item) => item.kind),
    ["model", "audio"],
  );
  assert.equal(s.homeAttachments[0].name, "герой.glb");
  assert.deepEqual(bytes(s.homeAttachments[0].data), glb);
  const snapshot = template(2);
  putAttachments(snapshot, s.homeAttachments, "main", "Use my assets");
  const reopened = new Document(JSON.parse(JSON.stringify(snapshot))).snapshot;
  const saved = chatState(reopened).sessions[0];
  const zipped = importZIP(exportZIP(snapshot));
  assert.deepEqual(bytes(file(zipped, s.homeAttachments[0].path).data), glb);
  assert.equal(saved.draft, "Use my assets");
  assert.equal(saved.attachments.length, 2);
  assert.equal(saved.attachmentDetails[saved.attachments[0]].name, "герой.glb");
  assert.deepEqual(bytes(file(reopened, saved.attachments[1]).data), wav);
  const doc = new Document(reopened),
    existing = studio(doc);
  removeAttachment(existing, saved.attachments[0]);
  assert.equal(existing.session.attachments.length, 1);
  assert.ok(
    file(doc.snapshot, saved.attachments[0]),
    "removing context keeps the imported project asset",
  );
  removeAttachment(s, s.homeAttachments[0].id);
  assert.equal(s.homeAttachments.length, 1);
  assert.equal(s.attachmentBusy, false);
  const report = await runTool(existing, "editor_audio_inspect", {
    path: saved.attachments[1],
  });
  assert.equal(report.channels, 2);
  assert.equal(report.sampleRate, 44100);
  assert.equal(report.durationSeconds, 4 / 44100);
  const reportModel = await runTool(existing, "editor_model_inspect", {
    path: saved.attachments[0],
  });
  assert.equal(reportModel.scenes.length, 1);
});

test("invalid batches, size limits and overlapping reads never leave partially attached files", async () => {
  const s = studio();
  await assert.rejects(
    attachFiles(s, [
      input("ok.glb", model()),
      input("bad.exe", new Uint8Array([1])),
    ]),
    /Unsupported attachment/,
  );
  assert.equal(s.homeAttachments.length, 0);
  let read = false;
  await assert.rejects(
    attachFiles(s, [
      {
        name: "large.wav",
        size: 17 * 1024 * 1024,
        arrayBuffer: async () => {
          read = true;
        },
      },
    ]),
    /16 MB/,
  );
  assert.equal(read, false);
  await assert.rejects(
    attachFiles(
      s,
      Array.from({ length: 5 }, () => input("asset.glb", model())),
    ),
    /four files/,
  );
  let release;
  const reading = attachFiles(s, [
    {
      name: "asset.glb",
      size: 1,
      arrayBuffer: () =>
        new Promise((resolve) => {
          release = resolve;
        }),
    },
  ]);
  assert.equal(s.attachmentBusy, true);
  await assert.rejects(
    attachFiles(s, [input("next.glb", model())]),
    /Wait for the current operation/,
  );
  s.document = new Document(template(3));
  release(model().buffer);
  await assert.rejects(reading, /different project/);
  assert.equal(s.homeAttachments.length, 0);
  assert.equal(s.attachmentBusy, false);
});

test("audio conversion creates a bounded PCM16 WAV accepted by the actual audio inspector", async () => {
  const before = globalThis.OfflineAudioContext;
  let decoded = false;
  globalThis.OfflineAudioContext = class {
    async decodeAudioData(data) {
      decoded = true;
      assert.equal(data.byteLength, 3);
      return audio;
    }
  };
  try {
    const item = await prepareAttachment(
      input("theme.mp3", new Uint8Array([1, 2, 3])),
    );
    assert.equal(decoded, true);
    assert.equal(item.name, "theme.wav");
    assert.equal(item.converted, true);
    const s = studio(new Document(template(2)));
    s.document.edit((snapshot) => putAttachments(snapshot, [item]));
    const report = await runTool(s, "editor_audio_inspect", {
      path: item.path,
    });
    assert.equal(report.peak, 1);
    assert.equal(report.channels, 2);
    globalThis.OfflineAudioContext = class {
      async decodeAudioData() {
        throw new Error("decoder failed");
      }
    };
    await assert.rejects(
      prepareAttachment(input("bad.m4a", new Uint8Array([1]))),
      /Could not read this audio/,
    );
    assert.throws(
      () => pcmWAV({ ...audio, length: 16 * 1024 * 1024 }),
      /exceeds 16 MB/,
    );
    assert.throws(
      () => pcmWAV({ ...audio, numberOfChannels: 6 }),
      /mono or stereo/,
    );
  } finally {
    globalThis.OfflineAudioContext = before;
  }
});

test("large images keep the original while a small explicit vision input survives project reopen", async () => {
  const imageBefore = globalThis.Image,
    documentBefore = globalThis.document;
  const preview = `data:image/jpeg;base64,${base64(new Uint8Array(60000))}`;
  let drawn = 0;
  globalThis.Image = class {
    naturalWidth = 3200;
    naturalHeight = 2400;
    async decode() {}
  };
  globalThis.document = {
    createElement: () => ({
      getContext: () => ({
        fillRect() {},
        drawImage() {
          drawn++;
        },
      }),
      toDataURL: () => preview,
    }),
  };
  try {
    const original = new Uint8Array(600000);
    original[400000] = 217;
    const item = await prepareAttachment(input("reference.PNG", original));
    assert.ok(drawn);
    assert.equal(item.preview, preview);
    assert.deepEqual(bytes(item.data), original);
    const snapshot = template(3);
    putAttachments(snapshot, [item]);
    const reopened = new Document(JSON.parse(JSON.stringify(snapshot)))
      .snapshot;
    assert.equal(
      chatState(reopened).sessions[0].attachmentDetails[item.path].preview,
      preview,
    );
    const broken = structuredClone(reopened);
    broken.messages.find(
      (message) => message.kind === "studio-state",
    ).studio.sessions[0].attachmentDetails[item.path].preview =
      "javascript:bad";
    assert.throws(() => new Document(broken), /Invalid attachment details/);
    assert.equal(attachmentKind("MODEL.VOX"), "model");
  } finally {
    globalThis.Image = imageBefore;
    globalThis.document = documentBefore;
  }
});
