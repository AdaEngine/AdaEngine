import { t, LocalizedError } from "./localization.js";

const cancelled = () =>
  new DOMException(t("Scene update cancelled"), "AbortError");

/** One AdaEngine instance per open project; snapshots replace its scene, not its renderer. */
export class Preview {
  frame = null;
  host = null;
  epoch = 0;
  sequence = 0;
  pending = new Map();
  ready = false;
  hasFrame = false;
  queue = Promise.resolve();
  key = "";
  requestedKey = "";
  loading = null;
  cancelMount = null;
  editorRevision = null;

  constructor(changed) {
    this.changed = changed;
    window.addEventListener("message", (event) => {
      if (
        event.source !== this.frame?.contentWindow ||
        event.origin !== this.origin ||
        event.data?.protocol !== "ada-studio-preview-v1"
      )
        return;
      if (event.data.event === "startup-error") {
        const error = event.data.message
          ? new Error(String(event.data.message).slice(0, 2000))
          : new LocalizedError("Player startup failed");
        for (const entry of this.pending.values()) entry.reject(error);
        this.pending.clear();
        this.ready = false;
        this.startupError = error;
        this.changed("error");
        return;
      }
      if (event.data.event === "editor") {
        if (this.ready && event.data.revision === this.editorRevision)
          this.onEditorEvent?.(event.data.type, event.data.value);
        return;
      }
      const entry = this.pending.get(event.data.id);
      if (!entry) return;
      this.pending.delete(event.data.id);
      event.data.error
        ? entry.reject(new Error(event.data.error))
        : entry.resolve(event.data.value);
    });
  }

  stop() {
    ++this.epoch;
    ++this.sequence;
    this.cancelMount?.();
    this.cancelMount = null;
    this.frame?.remove();
    this.frame = null;
    this.ready = false;
    this.editorRevision = null;
    this.hasFrame = false;
    this.key = "";
    this.requestedKey = "";
    this.loading = null;
    this.startupError = null;
    for (const entry of this.pending.values()) entry.reject(cancelled());
    this.pending.clear();
    this.queue = Promise.resolve();
    this.changed("idle");
  }

  load(snapshot, config, editMode = false) {
    const key = JSON.stringify({ files: snapshot.files, editMode });
    if (this.loading && this.requestedKey === key) return this.loading;
    const epoch = this.epoch,
      sequence = ++this.sequence;
    this.requestedKey = key;
    const active = () => {
      if (epoch !== this.epoch || sequence !== this.sequence) throw cancelled();
    };
    const work = async () => {
      active();
      if (this.startupError) throw this.startupError;
      if (this.ready && this.key === key) return;
      this.ready = false;
      this.changed("loading");
      if (!this.frame) await this.mount(config);
      active();
      if (this.startupError) throw this.startupError;
      const revision = crypto.randomUUID();
      await this.message("load", {
        formatVersion: 1,
        title: snapshot.title,
        files: snapshot.files,
        editMode,
        revision,
      });
      if (epoch !== this.epoch) throw cancelled();
      this.hasFrame = true;
      this.key = key;
      this.editorRevision = revision;
      active();
      this.ready = true;
      this.changed("ready");
    };
    const result = this.queue.catch(() => {}).then(work);
    this.queue = result;
    this.loading = result;
    const clear = () => {
      if (this.loading === result) this.loading = null;
    };
    result.then(clear, clear);
    return result;
  }

  async mount(config) {
    if (!navigator.gpu)
      throw new LocalizedError(
        "A WebGPU browser is required for the scene. Panels and code remain available.",
      );
    if (!this.host)
      throw new LocalizedError("The scene viewport is not ready yet.");
    const url = new URL(config.previewURL);
    const local = (host) => ["localhost", "127.0.0.1", "[::1]"].includes(host);
    const loopback =
      location.protocol === "http:" &&
      url.protocol === "http:" &&
      local(location.hostname) &&
      local(url.hostname);
    if (
      (url.protocol !== "https:" && !loopback) ||
      url.hostname === location.hostname ||
      url.username ||
      url.password
    )
      throw new LocalizedError("The scene requires a separate secure host.");
    this.origin = url.origin;
    url.hash = new URLSearchParams({ studioParent: location.origin });
    const frame = document.createElement("iframe");
    this.frame = frame;
    frame.title = t("AdaEngine — scene and game preview");
    frame.setAttribute(
      "sandbox",
      "allow-scripts allow-same-origin allow-pointer-lock",
    );
    frame.allow = "autoplay; fullscreen";
    frame.referrerPolicy = "no-referrer";
    const mounted = new Promise((resolve, reject) => {
      const timer = setTimeout(
        () => reject(new LocalizedError("AdaPlayer did not respond")),
        30000,
      );
      this.cancelMount = () => {
        clearTimeout(timer);
        reject(cancelled());
      };
      frame.onload = () => {
        clearTimeout(timer);
        resolve();
      };
      frame.onerror = () => {
        clearTimeout(timer);
        reject(new LocalizedError("Could not open AdaPlayer"));
      };
    });
    frame.src = url;
    this.host.append(frame);
    await mounted;
    this.cancelMount = null;
  }

  message(type, payload) {
    if (!this.frame) throw new LocalizedError("The scene has not loaded yet.");
    const id = crypto.randomUUID();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(
        () => {
          this.pending.delete(id);
          reject(new LocalizedError("AdaPlayer is not responding"));
        },
        type === "load" ? 120000 : 30000,
      );
      this.pending.set(id, {
        resolve: (value) => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: (error) => {
          clearTimeout(timer);
          reject(error);
        },
      });
      this.frame.contentWindow.postMessage(
        { protocol: "ada-studio-preview-v1", id, type, payload },
        this.origin,
      );
    });
  }
}
