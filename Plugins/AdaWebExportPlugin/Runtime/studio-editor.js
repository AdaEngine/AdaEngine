import * as M from "./studio-editor-math.js";

const NS = "http://www.w3.org/2000/svg";
const colors = ["#ff6972", "#70df8a", "#70abff"];
const edges = [
  [0, 1],
  [0, 2],
  [0, 4],
  [1, 3],
  [1, 5],
  [2, 3],
  [2, 6],
  [3, 7],
  [4, 5],
  [4, 6],
  [5, 7],
  [6, 7],
];

/** DOM handles overlay the real engine canvas. All geometry comes from the live
 * AdaEngine camera/world; this module does not render a second scene. */
export class StudioEditor {
  constructor(notify) {
    this.notify = notify;
    this.tool = "move";
    this.local = false;
    this.snapping = false;
    this.selected = null;
    this.camera = null;
    this.authoredCamera = null;
    this.keys = new Set();
    this.svg = document.createElementNS(NS, "svg");
    Object.assign(this.svg.style, {
      position: "fixed",
      inset: "0",
      width: "100%",
      height: "100%",
      zIndex: "5",
      touchAction: "none",
      outline: "none",
    });
    this.svg.setAttribute("tabindex", "0");
    this.svg.setAttribute("role", "application");
    this.svg.setAttribute(
      "aria-label",
      "Сцена AdaEngine. Выбор объектов и гизмо. Правая кнопка — камера, F — фокус.",
    );
    this.svg.addEventListener("contextmenu", (e) => e.preventDefault());
    this.svg.addEventListener("pointerdown", (e) => this.down(e));
    this.svg.addEventListener("pointermove", (e) => this.move(e));
    this.svg.addEventListener("pointerup", (e) => this.up(e));
    this.svg.addEventListener("pointercancel", () => this.cancel());
    this.svg.addEventListener("lostpointercapture", () => {
      if (this.drag) this.cancel();
    });
    this.svg.addEventListener("wheel", (e) => this.wheel(e), {
      passive: false,
    });
    this.svg.addEventListener("keydown", (e) => this.key(e));
    this.svg.addEventListener("keyup", (e) => {
      this.keys.delete(e.code);
    });
    window.addEventListener("blur", () => {
      this.keys.clear();
      this.cancel();
    });
    this.svg.addEventListener("dblclick", (e) => {
      if (e.button === 0) this.focus();
    });
    new ResizeObserver(() => this.redrawSoon()).observe(
      document.documentElement,
    );
    this.enabled = false;
  }
  native(payload) {
    if (typeof globalThis.__adaStudioEditor !== "function")
      throw new Error("Обновите AdaPlayer: инструменты сцены недоступны");
    const result = JSON.parse(
      globalThis.__adaStudioEditor(JSON.stringify(payload)),
    );
    if (result.error) throw new Error(result.error);
    this.state = result;
    return result;
  }
  async load(editMode, revision) {
    this.cancel();
    this.enabled = false;
    this.svg.remove();
    this.keys.clear();
    this.revision = revision;
    if (!editMode) return;
    this.native({ type: "state" });
    this.authoredCamera = this.pose();
    if (this.camera) this.native({ type: "camera", ...this.camera });
    else this.camera = this.pose();
    this.enabled = true;
    document.body.append(this.svg);
    this.redrawSoon();
  }
  command(options) {
    if (!this.enabled)
      throw new Error("Инструменты доступны после остановки игры");
    if (options.action === "cancel") {
      this.cancel();
      return { ok: true };
    }
    if (this.drag) this.cancel();
    if ("selected" in options)
      this.selected =
        typeof options.selected === "string" ? options.selected : null;
    if (["move", "rotate", "scale", "hand"].includes(options.tool))
      this.tool = options.tool;
    if (typeof options.local === "boolean") this.local = options.local;
    if (typeof options.snap === "boolean") this.snapping = options.snap;
    if (options.action === "focus") this.focus();
    if (options.action === "reset") this.setCamera(this.authoredCamera);
    this.draw();
    return { ok: true };
  }
  pose() {
    return {
      position: this.state.camera.slice(12, 15),
      rotation: M.quaternion(this.state.camera),
      ...(this.state.zoom ? { zoom: this.state.zoom } : {}),
    };
  }
  entity() {
    return this.state?.entities.find((e) => e.id === this.selected);
  }
  geometry(entity = this.entity()) {
    const size = [innerWidth, innerHeight],
      vp = M.multiply(this.state.projection, M.inverse(this.state.camera)),
      inv = M.inverse(vp);
    if (!inv || !entity) return { size, vp, inv };
    const origin = entity.matrix.slice(12, 15),
      screen = M.project(origin, vp, size),
      unit = M.worldUnitsPerPixel(origin, vp, inv, size);
    const basis = [0, 1, 2].map((i) =>
      this.local || this.tool === "rotate" || this.tool === "scale"
        ? M.norm(M.direction(entity.matrix, M.axis(i)))
        : M.axis(i),
    );
    return { size, vp, inv, origin, screen, unit, basis };
  }
  redrawSoon() {
    if (this.scheduled) return;
    this.scheduled = true;
    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        this.scheduled = false;
        if (!this.enabled) return;
        try {
          this.native({ type: "state" });
          this.draw();
        } catch (error) {
          this.notify("error", { message: error.message });
        }
      }),
    );
  }
  node(name, attributes, parent = this.svg) {
    const node = document.createElementNS(NS, name);
    for (const [key, value] of Object.entries(attributes))
      node.setAttribute(key, value);
    parent.append(node);
    return node;
  }
  draw() {
    if (!this.enabled) return;
    // Keep the root/captured pointer alive while replacing only its visuals.
    this.svg.replaceChildren();
    const entity = this.entity();
    if (!entity) return;
    const g = this.geometry(entity);
    if (!g.screen || !g.unit || g.screen[2] < 0 || g.screen[2] > 1) return;
    const corners = M.boxCorners(entity).map((p) => M.project(p, g.vp, g.size));
    for (const [a, b] of edges)
      if (corners[a] && corners[b])
        this.node("line", {
          x1: corners[a][0],
          y1: corners[a][1],
          x2: corners[b][0],
          y2: corners[b][1],
          stroke: "#d1c7ff",
          "stroke-width": 1.2,
          "stroke-opacity": 0.85,
          "pointer-events": "none",
        });
    if (this.tool === "hand") return;
    const axes = this.state.zoom ? [0, 1] : [0, 1, 2];
    if (this.tool === "rotate") {
      for (const i of this.state.zoom ? [2] : axes) {
        const a = g.basis[(i + 1) % 3],
          b = g.basis[(i + 2) % 3],
          points = [];
        for (let n = 0; n <= 96; n++) {
          const angle = (n / 96) * Math.PI * 2,
            p = M.project(
              M.add(
                g.origin,
                M.mul(
                  M.add(M.mul(a, Math.cos(angle)), M.mul(b, Math.sin(angle))),
                  g.unit * 70,
                ),
              ),
              g.vp,
              g.size,
            );
          if (p) points.push(p.slice(0, 2).join(","));
        }
        const group = this.node("g", {
          "data-handle": i,
          role: "button",
          "aria-label": `Вращение ${"XYZ"[i]}`,
          style: "cursor:grab",
        });
        const path = {
          points: points.join(" "),
          fill: "none",
          "stroke-linejoin": "round",
        };
        this.node(
          "polyline",
          { ...path, stroke: "#080a10", "stroke-width": 5 },
          group,
        );
        this.node(
          "polyline",
          { ...path, stroke: colors[i], "stroke-width": 2.5 },
          group,
        );
        this.node(
          "polyline",
          { ...path, stroke: "transparent", "stroke-width": 13 },
          group,
        );
      }
    } else {
      for (const i of axes) {
        const end = M.project(
          M.add(g.origin, M.mul(g.basis[i], g.unit * 86)),
          g.vp,
          g.size,
        );
        if (!end) continue;
        const delta = M.norm(M.sub(end.slice(0, 2), g.screen.slice(0, 2))),
          start = M.add(g.screen.slice(0, 2), M.mul(delta, 13));
        const group = this.node("g", {
          "data-handle": i,
          role: "button",
          "aria-label": `${this.tool === "scale" ? "Масштаб" : "Перемещение"} ${"XYZ"[i]}`,
          style: "cursor:grab",
        });
        const line = { x1: start[0], y1: start[1], x2: end[0], y2: end[1] };
        this.node(
          "line",
          { ...line, stroke: "#080a10", "stroke-width": 6 },
          group,
        );
        this.node(
          "line",
          { ...line, stroke: colors[i], "stroke-width": 3 },
          group,
        );
        this.node(
          "line",
          { ...line, stroke: "transparent", "stroke-width": 16 },
          group,
        );
        if (this.tool === "scale")
          this.node(
            "rect",
            {
              x: end[0] - 5,
              y: end[1] - 5,
              width: 10,
              height: 10,
              fill: colors[i],
              stroke: "#080a10",
            },
            group,
          );
        else {
          const normal = [-delta[1], delta[0]],
            base = M.sub(end.slice(0, 2), M.mul(delta, 12));
          this.node(
            "polygon",
            {
              points: [
                end.slice(0, 2),
                M.add(base, M.mul(normal, 5)),
                M.sub(base, M.mul(normal, 5)),
              ]
                .map((p) => p.join(","))
                .join(" "),
              fill: colors[i],
            },
            group,
          );
        }
        const label = this.node(
          "text",
          {
            x: end[0] + 9,
            y: end[1] - 7,
            fill: colors[i],
            "font-family": "system-ui",
            "font-size": 11,
            "font-weight": 700,
            "pointer-events": "none",
          },
          group,
        );
        label.textContent = "XYZ"[i];
      }
      this.node("rect", {
        x: g.screen[0] - 6,
        y: g.screen[1] - 6,
        width: 12,
        height: 12,
        rx: 2,
        fill: "#e2d9ff",
        stroke: "#171321",
        "stroke-width": 2,
        "data-handle": "center",
        role: "button",
        "aria-label":
          this.tool === "scale"
            ? "Равномерный масштаб"
            : "Перемещение в плоскости камеры",
        style: "cursor:move",
      });
    }
  }
  down(event) {
    if (!this.enabled || this.drag) return;
    event.preventDefault();
    this.svg.focus();
    this.svg.setPointerCapture(event.pointerId);
    const p = [event.clientX, event.clientY],
      handle = event.target
        .closest("[data-handle]")
        ?.getAttribute("data-handle");
    const g = this.geometry();
    if (event.button === 0 && !event.altKey && handle != null) {
      const entity = this.entity();
      if (!entity || !g.inv) return;
      const index = handle === "center" ? null : Number(handle),
        a = index === null ? null : g.basis[index],
        r = M.ray(p, g.inv, g.size);
      const normal =
        index === null ? M.norm(this.state.camera.slice(8, 11)) : a;
      const hit = M.planePoint(r, g.origin, normal);
      this.drag = {
        kind: "gizmo",
        pointer: event.pointerId,
        p,
        g,
        index,
        a,
        normal,
        entity: structuredClone(entity),
        start: this.transform(entity),
        last: this.transform(entity),
        parameter: a ? M.axisParameter(r, g.origin, a) : null,
        plane: hit,
        angleVector: hit ? M.norm(M.sub(hit, g.origin)) : null,
        angle: 0,
      };
    } else if (
      event.button === 2 ||
      event.altKey ||
      event.button === 1 ||
      this.tool === "hand"
    ) {
      this.drag = {
        kind: "camera",
        pointer: event.pointerId,
        p,
        lastP: p,
        pose: this.pose(),
        pan:
          event.button === 1 ||
          event.shiftKey ||
          !!this.state.zoom ||
          this.tool === "hand",
        orbit: event.altKey && event.button === 0,
      };
      this.flyTime = performance.now();
      this.fly();
    } else if (event.button === 0)
      this.drag = { kind: "pick", pointer: event.pointerId, p };
  }
  transform(e) {
    return {
      position: [...e.position],
      rotation: [...e.rotation],
      scale: [...e.scale],
    };
  }
  move(event) {
    const drag = this.drag;
    if (!drag) return;
    const p = [event.clientX, event.clientY];
    if (drag.kind === "camera") {
      const delta = M.sub(p, drag.lastP);
      drag.lastP = p;
      if (drag.pan) {
        const pose = this.pose(),
          entity = this.entity(),
          center =
            entity?.matrix.slice(12, 15) ??
            M.add(pose.position, M.mul(this.state.camera.slice(8, 11), 10));
        const g = this.geometry(),
          unit = M.worldUnitsPerPixel(center, g.vp, g.inv, g.size) || 0.01;
        const offset = M.add(
          M.mul(this.state.camera.slice(0, 3), -delta[0] * unit),
          M.mul(this.state.camera.slice(4, 7), delta[1] * unit),
        );
        this.setCamera({ ...pose, position: M.add(pose.position, offset) });
      } else this.look(delta, drag.orbit);
      return;
    }
    if (drag.kind !== "gizmo") return;
    const { g, index, a, start } = drag,
      r = M.ray(p, g.inv, g.size),
      snapping = this.snapping || event.ctrlKey || event.metaKey;
    let result = structuredClone(start);
    if (this.tool === "move") {
      let delta;
      if (index === null) {
        const hit = M.planePoint(r, g.origin, drag.normal);
        if (!hit || !drag.plane) return;
        delta = M.sub(hit, drag.plane);
      } else {
        const parameter = M.axisParameter(r, g.origin, a);
        if (parameter == null || drag.parameter == null) return;
        delta = M.mul(a, parameter - drag.parameter);
      }
      result = M.translateLocal(start, delta, drag.entity.parent);
      if (snapping)
        result.position = result.position.map((v) =>
          M.snap(v, this.state.zoom ? 10 : 0.5),
        );
    } else if (this.tool === "scale") {
      let amount;
      if (index === null) amount = (drag.p[1] - p[1]) / 90;
      else {
        const end = M.project(
          M.add(g.origin, M.mul(a, g.unit * 86)),
          g.vp,
          g.size,
        );
        amount =
          M.dot(
            M.sub(p, drag.p),
            M.norm(M.sub(end.slice(0, 2), g.screen.slice(0, 2))),
          ) / 90;
      }
      const factor = Math.exp(M.clamp(amount, -5, 5));
      result.scale = start.scale.map((v, i) =>
        index === null || i === index
          ? Math.max(0.01, snapping ? M.snap(v * factor, 0.1) : v * factor)
          : v,
      );
    } else {
      const hit = M.planePoint(r, g.origin, a);
      if (!hit || !drag.angleVector) return;
      const vector = M.norm(M.sub(hit, g.origin));
      drag.angle += Math.atan2(
        M.dot(a, M.cross(drag.angleVector, vector)),
        M.dot(drag.angleVector, vector),
      );
      drag.angleVector = vector;
      const angle = snapping ? M.snap(drag.angle, Math.PI / 12) : drag.angle;
      result = M.rotateLocal(start, M.axis(index), angle);
    }
    if (
      Object.values(result)
        .flat()
        .some((n) => !Number.isFinite(n) || Math.abs(n) > 999999)
    )
      return;
    try {
      this.native({ type: "transform", id: drag.entity.id, transform: result });
      drag.last = result;
      this.draw();
    } catch (error) {
      this.cancel();
      this.notify("error", { message: error.message });
    }
  }
  up(event) {
    const drag = this.drag;
    if (!drag) return;
    this.drag = null;
    this.keys.clear();
    if (this.svg.hasPointerCapture(event.pointerId))
      this.svg.releasePointerCapture(event.pointerId);
    if (
      drag.kind === "pick" &&
      M.length(M.sub([event.clientX, event.clientY], drag.p)) < 5
    )
      this.pick(drag.p);
    if (
      drag.kind === "gizmo" &&
      JSON.stringify(drag.last) !== JSON.stringify(drag.start)
    )
      this.notify("transform", {
        id: drag.entity.id,
        transform: drag.last,
        revision: this.revision,
      });
    this.draw();
  }
  cancel() {
    const drag = this.drag;
    this.drag = null;
    this.keys.clear();
    if (drag?.kind === "gizmo" && this.enabled) {
      try {
        this.native({
          type: "transform",
          id: drag.entity.id,
          transform: drag.start,
        });
      } catch {}
    }
    if (drag && this.svg.hasPointerCapture(drag.pointer))
      this.svg.releasePointerCapture(drag.pointer);
    if (this.enabled) this.draw();
  }
  pick(p) {
    const g = this.geometry(),
      r = M.ray(p, g.inv, g.size);
    const hits = this.state.entities
      .filter((e) => e.visible && e.pickable)
      .flatMap((e) => {
        const t = M.intersectBox(r, e.matrix, e.min, e.max);
        return t === null ? [] : [{ e, t }];
      })
      .sort((a, b) =>
        this.state.zoom && a.e.sprite && b.e.sprite
          ? b.e.matrix[14] - a.e.matrix[14] || b.e.id.localeCompare(a.e.id)
          : a.t - b.t,
      );
    this.selected = hits[0]?.e.id ?? null;
    this.notify("select", { id: this.selected });
    this.draw();
  }
  setCamera(pose) {
    if (!pose) return;
    this.native({ type: "camera", ...pose });
    this.camera = this.pose();
    this.draw();
  }
  look(delta, orbit = false) {
    const pose = this.pose(),
      yaw = M.quatAxis([0, 1, 0], -delta[0] * 0.004),
      pitch = M.quatAxis([1, 0, 0], -delta[1] * 0.004);
    let rotation = M.norm(M.quatMul(M.quatMul(yaw, pose.rotation), pitch));
    // Avoid flipping through the poles while retaining a level horizon.
    if (Math.abs(M.rotate(rotation, [0, 0, 1])[1]) > 0.995)
      rotation = M.norm(M.quatMul(yaw, pose.rotation));
    let position = pose.position;
    if (orbit) {
      const center = this.entity()?.matrix.slice(12, 15) ?? [0, 0, 0],
        distance = Math.max(0.1, M.length(M.sub(position, center)));
      position = M.sub(center, M.mul(M.rotate(rotation, [0, 0, 1]), distance));
    }
    this.setCamera({ ...pose, position, rotation });
  }
  wheel(event) {
    if (!this.enabled || this.drag?.kind === "gizmo") return;
    event.preventDefault();
    const pose = this.pose(),
      amount = M.clamp(event.deltaY, -200, 200);
    if (pose.zoom)
      this.setCamera({
        ...pose,
        zoom: M.clamp(pose.zoom * Math.exp(-amount * 0.002), 0.1, 10000),
      });
    else {
      const center = this.entity()?.matrix.slice(12, 15) ?? [0, 0, 0],
        distance = Math.max(1, M.length(M.sub(pose.position, center)));
      this.setCamera({
        ...pose,
        position: M.add(
          pose.position,
          M.mul(this.state.camera.slice(8, 11), -amount * distance * 0.0015),
        ),
      });
    }
  }
  focus() {
    const entity = this.entity();
    if (!entity) return;
    const corners = M.boxCorners(entity),
      center = M.mul(corners.reduce(M.add, [0, 0, 0]), 1 / 8),
      radius = Math.max(0.5, ...corners.map((p) => M.length(M.sub(p, center))));
    const pose = this.pose();
    if (pose.zoom) {
      const size = M.sub(entity.max, entity.min),
        world = M.length(M.direction(entity.matrix, size));
      this.setCamera({
        ...pose,
        position: [center[0], center[1], pose.position[2]],
        zoom: M.clamp(
          Math.min(innerWidth, innerHeight) / (Math.max(1, world) * 2.4),
          0.1,
          10000,
        ),
      });
    } else {
      const aspect = innerWidth / innerHeight,
        fov = Math.atan(1 / Math.abs(this.state.projection[5])),
        fit =
          (radius /
            Math.sin(Math.min(fov, Math.atan(Math.tan(fov) * aspect)))) *
          1.25;
      this.setCamera({
        ...pose,
        position: M.sub(
          center,
          M.mul(this.state.camera.slice(8, 11), Math.max(1, fit)),
        ),
      });
    }
  }
  key(event) {
    if (!this.enabled) return;
    if (event.key === "Escape") {
      event.preventDefault();
      this.cancel();
      return;
    }
    if (
      (event.ctrlKey || event.metaKey) &&
      ["z", "s", "d"].includes(event.key.toLowerCase())
    ) {
      event.preventDefault();
      this.cancel();
      this.notify("shortcut", {
        key: event.key.toLowerCase(),
        shift: event.shiftKey,
      });
      return;
    }
    if (this.drag?.kind === "camera") {
      this.keys.add(event.code);
      event.preventDefault();
      return;
    }
    if (this.drag) return;
    const tool = { KeyW: "move", KeyE: "rotate", KeyR: "scale", KeyQ: "hand" }[
      event.code
    ];
    if (tool) {
      event.preventDefault();
      this.tool = tool;
      this.notify("tool", { tool });
      this.draw();
    }
    if (event.code === "KeyF") {
      event.preventDefault();
      this.focus();
    }
    if (event.code === "Delete" || event.code === "Backspace") {
      event.preventDefault();
      this.notify("shortcut", { key: "delete" });
    }
  }
  fly() {
    if (this.drag?.kind !== "camera") return;
    const now = performance.now(),
      dt = Math.min(0.05, (now - this.flyTime) / 1000);
    this.flyTime = now;
    if (!this.drag.pan && !this.drag.orbit && this.keys.size) {
      const offset = [
        +this.keys.has("KeyD") - +this.keys.has("KeyA"),
        +this.keys.has("KeyE") - +this.keys.has("KeyQ"),
        +this.keys.has("KeyW") - +this.keys.has("KeyS"),
      ];
      if (M.length(offset)) {
        const pose = this.pose(),
          speed =
            this.keys.has("ShiftLeft") || this.keys.has("ShiftRight") ? 15 : 4;
        this.setCamera({
          ...pose,
          position: M.add(
            pose.position,
            M.mul(M.rotate(pose.rotation, M.norm(offset)), dt * speed),
          ),
        });
      }
    }
    requestAnimationFrame(() => this.fly());
  }
}
