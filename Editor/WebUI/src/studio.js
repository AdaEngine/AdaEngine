import { runAgent, runTool } from "./agent.js";
import {
  chatState,
  editChat,
  newSession,
  switchSession,
  identity,
} from "./chat.js";
import {
  receiveUI,
  finishUI,
  editSurface,
  submitSurface,
  undoSurface,
  exportSurface,
} from "./chat-ui-controller.js";
import { writeTools } from "./agent-tools.js";
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
  projectBrowser = false;
  leavePrompt = "";
  leaving = false;
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
  runningSessionID = null;
  permissionRequest = null;
  allowedTools = new Set();
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
  viewportExpanded = false;
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
    window.addEventListener("beforeunload", (e) => {
      if (
        this.running ||
        (this.document && this.document.generation !== this.savedGeneration)
      ) {
        e.preventDefault();
        e.returnValue = "";
      }
    });
    window.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && this.viewportExpanded) {
        this.viewportExpanded = false;
        this.emit();
      }
      if (
        this.document &&
        !this.projectBrowser &&
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
        !this.projectBrowser &&
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
  get chat() {
    return chatState(this.snapshot);
  }
  get session() {
    return (
      this.chat.sessions.find((s) => s.id === this.chat.activeSessionID) ||
      this.chat.sessions[0]
    );
  }
  updateChat(update) {
    editChat(this, update);
  }
  newSession() {
    newSession(this);
  }
  switchSession(id) {
    switchSession(this, id);
  }
  receiveUI(text, messageID, sessionID, final = false) {
    return receiveUI(this, text, messageID, sessionID, final);
  }
  finishUI(sessionID, status) {
    finishUI(this, sessionID, status);
  }
  editSurface(...args) {
    return editSurface(this, ...args);
  }
  async submitSurface(...args) {
    try {
      return await submitSurface(this, ...args);
    } catch (e) {
      this.updateChat((c) => {
        const card = c.surfaces.find((r) => r.generation === args[1]);
        if (card) card.error = e.message;
      });
      throw e;
    }
  }
  undoSurface(...args) {
    return undoSurface(this, ...args);
  }
  exportSurface(...args) {
    return exportSurface(this, ...args);
  }
  restoreSurface(id, generation) {
    const card = this.chat.surfaces.find(
      (r) =>
        r.id === id &&
        r.generation === generation &&
        r.sessionID === this.session.id &&
        r.owner === identity(this),
    );
    if (
      this.running ||
      !card?.components.root ||
      !["failed", "cancelled"].includes(card.status)
    )
      throw new Error("Карточка недоступна");
    this.updateChat((c) => {
      const r = c.surfaces.find((r) => r.generation === generation);
      r.status = "ready";
      r.error = "";
    });
  }
  requestTool(name, args, signal) {
    const session =
      this.chat.sessions.find((s) => s.id === this.runningSessionID) ||
      this.session;
    if (!writeTools.has(name)) return Promise.resolve();
    if (session.mode === "plan")
      return Promise.reject(
        new Error("Режим обсуждения не разрешает правки проекта"),
      );
    if (
      session.permission !== "ask" ||
      this.allowedTools.has(session.id + ":" + name)
    )
      return Promise.resolve();
    return new Promise((resolve, reject) => {
      const done = (choice) => {
        signal.removeEventListener("abort", cancel);
        this.permissionRequest = null;
        if (choice === "session")
          this.allowedTools.add(session.id + ":" + name);
        this.emit();
        choice
          ? resolve()
          : reject(new Error("Пользователь отклонил инструмент"));
      };
      const cancel = () => done(false);
      this.permissionRequest = {
        name,
        args,
        sessionID: session.id,
        decide: done,
      };
      signal.addEventListener("abort", cancel, { once: true });
      if (signal.aborted) cancel();
      else this.emit();
    });
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
  get codeFiles() {
    return (
      this.snapshot?.files
        .filter((f) => /\.(ada|md|txt|ui|json|ascn)$/.test(f.path))
        .sort((a, b) => a.path.localeCompare(b.path)) || []
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
    if (this.running)
      throw new Error("Остановите ассистента перед сменой проекта");
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
    this.allowedTools.clear();
    this.prompt = this.session.draft || "";
    if (
      this.chat.surfaces.some((s) =>
        ["receiving", "submitting"].includes(s.status),
      )
    ) {
      this.document.chat((c) => {
        for (const surface of c.surfaces)
          if (["receiving", "submitting"].includes(surface.status))
            surface.status = "cancelled";
      });
    }
    this.selected = null;
    this.latestCodeSelection = "";
    this.activity = [];
    this.savedGeneration = 0;
    this.view = "editor";
    this.projectBrowser = false;
    this.leavePrompt = "";
    this.assetPanel = false;
    this.viewportExpanded = false;
    this.playing = false;
    this.viewportError = "";
    this.activeFile = this.sources[0]?.path ?? "Sources/Game.ada";
    this.status = "saved";
    this.history = false;
    this.error = "";
    this.checkpointPending = false;
    localStorage.setItem(`studio:last:${this.account.id}`, record.id);
    this.emit();
    if (this.document.generation) this.changed();
  }
  async open(record) {
    if (record.id === this.workspace?.id) {
      this.projectBrowser = false;
      this.emit();
      return;
    }
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
  home() {
    this.navigate("overview");
  }
  navigate(view) {
    if (!this.document) return;
    this.projectBrowser = false;
    this.view = view;
    if (view === "editor") this.playing = false;
    this.assetPanel = false;
    this.viewportExpanded = false;
    this.emit();
  }
  async browseProjects(local = false) {
    if (this.leaving) return;
    if (this.running)
      throw new Error("Остановите ассистента перед выходом к проектам");
    this.leaving = true;
    this.emit();
    try {
      if (local && this.document) {
        // Confirm the durable write, including any queued edits, before leaving.
        await this.recoveryQueue;
        await recovery("save", this.account.id, this.workspace.id, {
          revision: this.workspace.revision,
          snapshot: portable(this.snapshot),
        });
      } else {
        await this.save();
      }
      this.projectBrowser = true;
      this.leavePrompt = "";
      this.history = false;
      // Retain the document, undo, selection and Player for the Continue action.
      await this.refresh().catch((e) => this.fail(e));
    } catch (e) {
      this.leavePrompt = e.message;
    } finally {
      this.leaving = false;
      this.emit();
    }
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
        if (entity)
          entity.components["AdaTransform.Transform"] = {
            ...entity.components["AdaTransform.Transform"],
            ...clone(t),
          };
      });
    }
    if (type === "shortcut") {
      if (value.key === "escape") {
        this.viewportExpanded = false;
        this.emit();
      }
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
    if (!this.entity) this.selected = null;
    this.changed();
  }
  redo() {
    this.document?.redo();
    if (!this.entity) this.selected = null;
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
    const document = this.document;
    const path =
        "Assets/Imports/" +
        crypto.randomUUID() +
        "_" +
        input.name.replace(/[^a-zA-Z0-9_.-]/g, "_"),
      data = base64(new Uint8Array(await input.arrayBuffer()));
    if (this.document !== document) throw new Error("Открыт другой проект");
    document.edit((s) => s.files.push({ path, data }));
    this.changed();
    return path;
  }
  async attachFile(input) {
    const sessionID = this.session.id,
      document = this.document;
    if (this.session.attachments.length >= 4)
      throw new Error("Можно приложить до четырёх файлов");
    let path;
    if (/\.(md|txt|ada)$/i.test(input.name)) {
      if (input.size > 100_000)
        throw new Error("Текстовое вложение превышает 100 КБ");
      path =
        "Docs/Attachments/" +
        crypto.randomUUID() +
        "_" +
        input.name.replace(/[^a-zA-Z0-9_.-]/g, "_").replace(/\.ada$/i, ".txt");
      const text = await input.text();
      if (this.document !== document) throw new Error("Открыт другой проект");
      document.write(path, text);
      this.changed();
    } else path = await this.uploadAsset(input);
    if (this.document !== document) throw new Error("Открыт другой проект");
    this.updateChat((c) => {
      const session = c.sessions.find((c) => c.id === sessionID);
      session.attachments.push(path);
    });
    return path;
  }
  async importFile(input) {
    if (this.running)
      throw new Error("Остановите ассистента перед сменой проекта");
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
    this.navigate(editMode ? "editor" : "preview");
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
    this.navigate("editor");
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
  send(text, options) {
    return runAgent(this, text, options);
  }
  runTool(name, args) {
    return runTool(this, name, args);
  }
}
