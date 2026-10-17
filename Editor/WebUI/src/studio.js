import { runAgent, runTool } from "./agent.js";
import { json, recovery, Preview, base64, download } from "./platform.js";
import {
  Document,
  clone,
  file,
  metadata,
  scene,
  template,
  portable,
  exportZIP,
  importZIP,
  transform,
} from "./documents.js";
export class Studio {
  version = 0;
  listeners = new Set();
  account = null;
  config = {};
  projects = [];
  workspace = null;
  document = null;
  view = "editor";
  panel = "objects";
  selected = null;
  inspector = true;
  assistant = true;
  assetPanel = false;
  status = "loading";
  error = "";
  prompt = "";
  streamText = "";
  running = false;
  runtime = "idle";
  playing = false;
  viewportError = "";
  activity = [];
  providers = [];
  providerID = "";
  modelID = "";
  billingMode = "ada";
  apiKey = "";
  settings = false;
  history = false;
  checkpoints = [];
  activeFile = "Sources/Game.ada";
  savePromise = null;
  savedGeneration = 0;
  timer = null;
  recoveryQueue = Promise.resolve();
  agent = null;
  checkpointPending = false;
  latestCodeSelection = "";
  tool = "move";
  localAxes = false;
  snapTransforms = false;
  renderedGeneration = -1;
  constructor() {
    this.preview = new Preview((state) => {
      this.runtime = state;
      this.emit();
    });
    this.preview.onEditorEvent = (type, value) =>
      this.action(() => this.editorEvent(type, value));
    window.addEventListener("online", () => {
      if (this.document) this.save().catch((e) => this.fail(e));
    });
    window.addEventListener("pagehide", () => {
      this.agent?.abort();
      this.preview.stop();
    });
    window.addEventListener("keydown", (e) => {
      if (
        (e.metaKey || e.ctrlKey) &&
        e.key.toLowerCase() === "z" &&
        !document.activeElement?.closest(
          "input, textarea, [contenteditable=true]",
        )
      ) {
        e.preventDefault();
        e.shiftKey ? this.redo() : this.undo();
      }
    });
    window.addEventListener("keydown", (e) => {
      if (
        this.document &&
        this.view === "editor" &&
        !this.playing &&
        !e.target.closest?.("input, textarea, [contenteditable=true]") &&
        !e.ctrlKey &&
        !e.metaKey &&
        !e.altKey
      ) {
        const tool = { w: "move", e: "rotate", r: "scale", q: "hand" }[
          e.key.toLowerCase()
        ];
        if (tool) {
          e.preventDefault();
          this.tool = tool;
          this.emit();
          this.editorCommand();
        }
        if (e.key.toLowerCase() === "f") {
          e.preventDefault();
          this.editorCommand({ action: "focus" });
        }
      }
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "s") {
        e.preventDefault();
        this.save().catch((error) => this.fail(error));
      }
    });
  }
  subscribe = (fn) => {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  };
  getVersion = () => this.version;
  emit() {
    this.version++;
    for (const fn of this.listeners) fn();
  }
  fail(error) {
    if (error?.name === "AbortError") return;
    this.error = error.message || String(error);
    this.emit();
  }
  async action(fn) {
    try {
      return await fn();
    } catch (e) {
      this.fail(e);
    }
  }
  get snapshot() {
    return this.document?.snapshot;
  }
  get scene() {
    try {
      return this.snapshot ? scene(this.snapshot) : null;
    } catch {
      return null;
    }
  }
  get entity() {
    return this.scene?.entities.find((e) => e.id === this.selected);
  }
  get models() {
    return this.providers.find((p) => p.id === this.providerID)?.models ?? [];
  }
  get model() {
    return this.models.find((m) => m.id === this.modelID);
  }
  get sources() {
    return (
      this.snapshot?.files
        .filter((f) => f.path.startsWith("Sources/"))
        .sort((a, b) => a.path.localeCompare(b.path)) ?? []
    );
  }
  async start() {
    try {
      this.account = await json("/v1/me");
      this.config = await json("/v1/ai/studio-config");
      if (!this.config.enabled)
        throw new Error("Studio пока недоступен в этом окружении");
      this.providers = await json("/v1/ai/providers");
      this.providerID = this.providers[0]?.id ?? "";
      this.modelID = this.models.find((m) => m.tools)?.id ?? "";
      this.projects = await json("/v1/workspaces");
      this.status = "saved";
      this.emit();
      const last = localStorage.getItem(`studio:last:${this.account.id}`),
        existing = this.projects.find((p) => p.id === last);
      if (existing) await this.open(existing);
    } catch (e) {
      this.status = e.status === 401 ? "signedout" : "offline";
      this.fail(e);
    }
  }
  async refresh() {
    this.projects = await json("/v1/workspaces");
    this.emit();
  }
  async create(dimension = 3) {
    await this.save();
    await this.createSnapshot(template(dimension));
  }
  async createSnapshot(snapshot) {
    const clean = portable(snapshot),
      record = await json("/v1/workspaces", {
        operationID: crypto.randomUUID(),
        snapshot: clean,
      });
    this.install(record, clean);
    await this.refresh();
  }
  install(record, snapshot) {
    this.preview.stop();
    this.workspace = record;
    this.document = new Document(snapshot);
    this.selected = null;
    this.latestCodeSelection = "";
    this.activity = [];
    this.savedGeneration = 0;
    this.view = "editor";
    this.playing = false;
    this.viewportError = "";
    this.activeFile = this.sources[0]?.path ?? "Sources/Game.ada";
    this.status = "saved";
    this.history = false;
    this.error = "";
    this.checkpointPending = false;
    localStorage.setItem(`studio:last:${this.account.id}`, record.id);
    this.emit();
  }
  async open(record) {
    if (this.running)
      throw new Error("Остановите ассистента перед сменой проекта");
    await this.save();
    const value = await json(`/v1/workspaces/${record.id}`);
    if (!value.snapshot) throw new Error("Снимок проекта недоступен");
    this.install(value, value.snapshot);
    const draft = await recovery("load", this.account.id, record.id);
    if (
      draft &&
      JSON.stringify(draft.snapshot) !== JSON.stringify(value.snapshot)
    ) {
      if (draft.revision === value.revision) {
        this.document.edit((s) => Object.assign(s, draft.snapshot));
        this.changed();
      } else {
        await this.createSnapshot({
          ...draft.snapshot,
          title: draft.snapshot.title + " — восстановлено",
        });
        this.error = "Несохранённые изменения восстановлены отдельным проектом";
        this.emit();
      }
    }
  }
  async home() {
    if (this.running) throw new Error("Сначала остановите ассистента");
    await this.save();
    this.preview.stop();
    this.document = null;
    this.workspace = null;
    this.history = false;
    this.emit();
    await this.refresh();
  }
  changed(checkpoint = false) {
    this.checkpointPending ||= checkpoint;
    if (!this.document) return;
    this.status = "saving";
    const record = this.workspace,
      snapshot = clone(this.snapshot),
      account = this.account.id;
    this.recoveryQueue = this.recoveryQueue
      .then(() =>
        recovery("save", account, record.id, {
          revision: record.revision,
          snapshot,
        }),
      )
      .catch((e) => this.fail(e));
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.save().catch((e) => this.fail(e)), 900);
    this.emit();
  }
  async save(checkpoint = false) {
    this.checkpointPending ||= checkpoint;
    clearTimeout(this.timer);
    if (this.savePromise) {
      await this.savePromise;
      return this.save();
    }
    const doc = this.document,
      record = this.workspace;
    if (
      !doc ||
      !record ||
      (doc.generation === this.savedGeneration && !this.checkpointPending)
    )
      return;
    const snapshot = portable(doc.snapshot),
      generation = doc.generation,
      keeps = this.checkpointPending;
    this.checkpointPending = false;
    const save = async () => {
      try {
        const result = await json(
          `/v1/workspaces/${record.id}`,
          {
            operationID: crypto.randomUUID(),
            expectedRevision: record.revision,
            snapshot,
            checkpoint: keeps,
          },
          "PUT",
        );
        if (this.document !== doc) return;
        this.workspace = { ...result };
        this.savedGeneration = generation;
        if (doc.generation === generation) {
          await this.recoveryQueue;
          if (doc.generation === generation)
            await recovery("remove", this.account.id, record.id);
        }
        this.status = doc.generation === generation ? "saved" : "saving";
      } catch (e) {
        if (this.document !== doc) return;
        if (e.status === 409) {
          this.agent?.abort();
          await this.createSnapshot({
            ...clone(doc.snapshot),
            title: doc.snapshot.title + " — копия",
          });
          this.error =
            "Проект изменён в другой вкладке. Ваши правки сохранены отдельной копией.";
        } else {
          this.status = e.status === 401 ? "signedout" : "offline";
          this.checkpointPending ||= keeps;
          throw e;
        }
      } finally {
        this.emit();
      }
    };
    this.savePromise = save();
    try {
      await this.savePromise;
    } finally {
      this.savePromise = null;
    }
    if (
      this.document === doc &&
      (doc.generation !== this.savedGeneration || this.checkpointPending)
    )
      return this.save();
  }
  editScene(update) {
    this.document.scene(update);
    this.changed();
  }
  select(id) {
    this.selected = id;
    this.inspector = true;
    this.emit();
    this.editorCommand();
  }
  editorCommand(options = {}) {
    if (!this.preview.ready || this.playing) return;
    return this.preview
      .message("editor", {
        selected: this.selected,
        tool: this.tool,
        local: this.localAxes,
        snap: this.snapTransforms,
        ...options,
      })
      .catch((error) => this.fail(error));
  }
  editorEvent(type, value) {
    if (this.playing || !this.document || this.view !== "editor") return;
    if (type === "select") {
      this.selected = this.scene.entities.some((e) => e.id === value.id)
        ? value.id
        : null;
      this.inspector = true;
      this.emit();
    }
    if (
      type === "tool" &&
      ["move", "rotate", "scale", "hand"].includes(value.tool)
    ) {
      this.tool = value.tool;
      this.emit();
    }
    if (type === "error") throw new Error(value.message);
    if (type === "transform") {
      // A tool drag may span an agent/manual revision. Never overwrite that edit.
      if (
        this.renderedGeneration !== this.document.contentGeneration ||
        this.running
      ) {
        this.preview.key = "";
        return this.syncViewport();
      }
      const t = value.transform;
      if (
        ![t?.position, t?.rotation, t?.scale].every(
          (v, i) =>
            Array.isArray(v) &&
            v.length === [3, 4, 3][i] &&
            v.every(
              (n) =>
                typeof n === "number" &&
                Number.isFinite(n) &&
                Math.abs(n) < 1_000_000,
            ),
        )
      )
        throw new Error("Некорректная трансформация");
      this.editScene((scene) => {
        const entity = scene.entities.find((e) => e.id === value.id);
        if (entity) entity.components["AdaTransform.Transform"] = clone(t);
      });
    }
    if (type === "shortcut") {
      if (value.key === "z") value.shift ? this.redo() : this.undo();
      if (value.key === "s") return this.save();
      if (!this.running && this.selected && value.key === "delete")
        this.removeEntity();
      if (!this.running && this.selected && value.key === "d")
        this.duplicateEntity();
    }
  }
  duplicateEntity() {
    if (!this.selected) return;
    const selected = this.selected,
      ids = new Map([[selected, crypto.randomUUID()]]);
    this.editScene((scene) => {
      for (;;) {
        const count = ids.size;
        for (const e of scene.entities)
          if (ids.has(e.parent) && !ids.has(e.id))
            ids.set(e.id, crypto.randomUUID());
        if (count === ids.size) break;
      }
      scene.entities.push(
        ...scene.entities
          .filter((e) => ids.has(e.id))
          .map((e) => ({
            ...clone(e),
            id: ids.get(e.id),
            parent: ids.get(e.parent) ?? e.parent,
            name: e.id === selected ? e.name + " — копия" : e.name,
          })),
      );
    });
    this.select(ids.get(selected));
  }
  setField(component, field, value) {
    this.editScene((s) => {
      const entity = s.entities.find((e) => e.id === this.selected);
      if (entity) entity.components[component][field] = value;
    });
  }
  addEntity() {
    const id = crypto.randomUUID();
    const visual =
      metadata(this.snapshot).runtime.plugins.preset === "game2d"
        ? {
            "AdaSprite.Sprite": {
              tintColor: { red: 0.52, green: 0.47, blue: 0.98, alpha: 1 },
              size: { width: 80, height: 80 },
            },
          }
        : {
            "AdaScene.Mesh3DComponent": {
              mesh: "Cube",
              size: 1,
              color: { red: 0.52, green: 0.47, blue: 0.98, alpha: 1 },
              roughness: 0.65,
              metallic: 0,
            },
          };
    this.editScene((s) =>
      s.entities.push({
        id,
        name: "Новый объект",
        enabled: true,
        parent: null,
        components: {
          "AdaTransform.Transform": transform(),
          ...visual,
        },
      }),
    );
    this.select(id);
  }
  removeEntity() {
    const removed = new Set([this.selected]);
    this.editScene((s) => {
      for (;;) {
        const before = removed.size;
        for (const e of s.entities)
          if (removed.has(e.parent)) removed.add(e.id);
        if (before === removed.size) break;
      }
      s.entities = s.entities.filter((e) => !removed.has(e.id));
    });
    this.selected = null;
    this.emit();
  }
  undo() {
    this.document?.undo();
    this.changed();
  }
  redo() {
    this.document?.redo();
    this.changed();
  }
  writeCode(text) {
    this.document.write(this.activeFile, text);
    this.changed();
  }
  rename(title) {
    if (!title.trim() || title === this.snapshot.title) return;
    this.document.edit((s) => {
      s.title = title.trim();
      const meta = metadata(s);
      meta.project.displayName = s.title;
      file(s, ".ada/project.json").data = base64(
        new TextEncoder().encode(JSON.stringify(meta, null, 2)),
      );
    });
    this.changed();
  }
  async uploadAsset(input) {
    const path =
        "Assets/Imports/" +
        crypto.randomUUID() +
        "_" +
        input.name.replace(/[^a-zA-Z0-9_.-]/g, "_"),
      data = base64(new Uint8Array(await input.arrayBuffer()));
    this.document.edit((s) => s.files.push({ path, data }));
    this.changed();
    return path;
  }
  async importFile(input) {
    await this.save();
    await this.createSnapshot(importZIP(await input.arrayBuffer()));
  }
  export() {
    download(this.snapshot.title + ".zip", exportZIP(this.snapshot));
  }
  async showHistory() {
    await this.save();
    this.checkpoints = await json(
      `/v1/workspaces/${this.workspace.id}/history`,
    );
    this.history = true;
    this.emit();
  }
  async checkpoint() {
    await this.save(true);
    await this.showHistory();
  }
  async restore(revision) {
    if (this.running)
      throw new Error("Остановите ассистента перед восстановлением");
    await this.save();
    const id = this.workspace.id;
    await json(`/v1/workspaces/${id}/restore`, {
      operationID: crypto.randomUUID(),
      expectedRevision: this.workspace.revision,
      revision,
    });
    await this.recoveryQueue;
    await recovery("remove", this.account.id, id);
    const restored = await json(`/v1/workspaces/${id}`);
    this.install(restored, restored.snapshot);
  }
  async play(editMode = false) {
    if (!this.snapshot) return;
    this.playing = !editMode;
    this.view = editMode ? "editor" : "preview";
    this.emit();
    return this.syncViewport(editMode);
  }
  async syncViewport(editMode = !this.playing) {
    if (!this.snapshot) return;
    const document = this.document;
    const generation = document.contentGeneration;
    const snapshot = portable(this.snapshot);
    snapshot.messages = [];
    try {
      // Creating a project from the home composer mounts Workspace asynchronously.
      if (!this.preview.host) await new Promise(requestAnimationFrame);
      await this.preview.load(snapshot, this.config, editMode);
      if (this.document === document) {
        this.viewportError = "";
        this.renderedGeneration = generation;
        if (editMode) await this.editorCommand();
      }
    } catch (e) {
      if (e.name !== "AbortError" && this.document === document) {
        this.runtime = "error";
        this.viewportError = e.message;
        this.emit();
      }
      throw e;
    }
  }
  async stop() {
    this.playing = false;
    this.view = "editor";
    this.emit();
    return this.syncViewport(true);
  }
  async retryViewport() {
    this.preview.stop();
    this.viewportError = "";
    return this.syncViewport();
  }
  stopAgent() {
    this.agent?.abort();
  }
  append(value) {
    this.document.append(value);
    this.changed();
  }
  send(text) {
    return runAgent(this, text);
  }
  runTool(name, args) {
    return runTool(this, name, args);
  }
}
