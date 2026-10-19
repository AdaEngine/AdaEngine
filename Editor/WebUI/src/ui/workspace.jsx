import React from "react";
import { studio } from "./state.js";
import { useRef, useEffect, useState } from "react";
import { Icon, Mark, Button, act, entityIcon } from "./controls.jsx";
import { Assistant } from "./assistant.jsx";
import { Inspector } from "./inspector.jsx";
import { Code, Assets } from "./code-assets.jsx";
import { ProjectOverview } from "./project-overview.jsx";
import { ViewportInput } from "./viewport-input.jsx";
import { AnnotationViewport } from "./annotations.jsx";
import { RuntimeConsole } from "./runtime-console.jsx";
import { t } from "../localization.js";

function Workspace({ hidden = false }) {
  const s = studio,
    host = useRef(),
    [mobile, setMobile] = useState(false),
    [help, setHelp] = useState(false),
    [assistantCollapsed, setAssistantCollapsed] = useState(false),
    [consoleOpen, setConsoleOpen] = useState(false);
  const viewport = ["editor", "preview"].includes(s.view);
  useEffect(() => {
    s.preview.host = host.current;
    return () => {
      s.preview.stop();
      s.preview.host = null;
    };
  }, []);
  useEffect(() => {
    if (!viewport || hidden) return;
    const timer = setTimeout(
      () =>
        s.syncViewport().catch((error) => {
          // Diagnostics belong to the viewport; newer revisions supersede queued loads.
          if (error.name !== "AbortError") s.emit();
        }),
      s.document.contentGeneration ? 250 : 0,
    );
    return () => clearTimeout(timer);
  }, [s.document, s.document.contentGeneration, s.view, s.playing, hidden]);
  useEffect(() => {
    if (s.composerFocus) setAssistantCollapsed(false);
  }, [s.composerFocus]);
  const showAssistant =
    (!s.viewportExpanded && s.assistant && s.view === "editor") ||
    s.view === "assistant";
  const showObjects = !s.viewportExpanded && viewport && s.panel === "objects";
  const showInspector =
    !s.viewportExpanded && s.inspector && s.selected && s.view === "editor";
  return (
    <main
      hidden={hidden}
      className={`workspace section-${s.view} ${showAssistant ? "has-assistant" : ""} ${assistantCollapsed ? "assistant-collapsed" : ""} ${showObjects || showInspector ? "has-scene-sidebar" : ""} ${s.viewportExpanded && viewport ? "viewport-expanded" : ""}`}
    >
      <div className="scene-center" hidden={!viewport}>
        <div className="scene-viewport">
          <div
            aria-hidden={!viewport}
            style={{ pointerEvents: viewport ? "auto" : "none" }}
            className={`stage ${mobile ? "mobile-preview" : ""}`}
          >
            <div className="stage-surface">
              <div ref={host} className="player-host visible" />
              {!hidden && viewport && <AnnotationViewport />}
              {!hidden &&
                s.view === "editor" &&
                s.runtime === "ready" &&
                !s.playing && <ViewportInput />}
              {viewport && (s.runtime === "error" || !s.preview.hasFrame) && (
                <div className="runtime-loading">
                  {s.runtime !== "error" && <span className="spinner" />}
                  <h3>
                    {s.runtime === "error"
                      ? t("Could not update the scene")
                      : t("Starting AdaEngine…")}
                  </h3>
                  <p>
                    {s.runtime === "error"
                      ? s.viewportError
                      : t(
                          "AdaEngine renders the scene and game. The editor is ready to use.",
                        )}
                  </p>
                  {s.runtime === "error" && (
                    <button
                      className="button"
                      onClick={act(() => s.retryViewport())}
                    >
                      {t("Retry loading")}
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>
          {viewport && (
            <div className="stage-badge">
              <span
                className={s.runtime === "ready" ? "live-dot" : "muted-dot"}
              />
              {s.runtime === "loading"
                ? t("AdaEngine · Updating scene…")
                : s.runtime === "error"
                  ? t("AdaEngine · Scene error")
                  : s.runtime === "idle"
                    ? t("AdaEngine · Starting…")
                    : s.playing
                      ? t("AdaEngine · Game running")
                      : t("AdaEngine · Scene editor")}
            </div>
          )}
          {viewport && (
            <>
              <div className="viewport-controls">
                <Button
                  icon="monitor"
                  label={t("Desktop view")}
                  active={!mobile}
                  onClick={() => setMobile(false)}
                />
                <Button
                  icon="phone"
                  label={t("Mobile view")}
                  active={mobile}
                  onClick={() => setMobile(true)}
                />
              </div>
              <div className="viewport-toolbar">
                <Button
                  icon="terminal"
                  label={consoleOpen ? t("Hide console") : t("Show console")}
                  active={consoleOpen}
                  onClick={() => setConsoleOpen(!consoleOpen)}
                >
                  {t("Console")}
                </Button>
                <Button
                  icon={s.viewportExpanded ? "close" : "focus"}
                  label={
                    s.viewportExpanded
                      ? t("Return to panels (Esc)")
                      : t("Expand scene")
                  }
                  active={s.viewportExpanded}
                  onClick={() => {
                    setMobile(false);
                    s.viewportExpanded = !s.viewportExpanded;
                    s.emit();
                  }}
                />
                {!s.playing && (
                  <>
                    {[
                      ["hand", "camera", t("Camera / pan (Q)")],
                      ["move", "move", t("Move (W)")],
                      ["rotate", "rotate", t("Rotate (E)")],
                      ["scale", "scale", t("Scale (R)")],
                    ].map(([tool, icon, label]) => (
                      <Button
                        key={tool}
                        icon={icon}
                        label={label}
                        active={s.tool === tool}
                        onClick={() => {
                          s.tool = tool;
                          s.emit();
                          s.editorCommand();
                        }}
                      />
                    ))}
                    <span className="divider" />
                    <Button
                      icon="cube"
                      label={t("Local movement axes")}
                      active={s.localAxes}
                      disabled={s.tool !== "move"}
                      onClick={() => {
                        s.localAxes = !s.localAxes;
                        s.emit();
                        s.editorCommand();
                      }}
                    />
                    <Button
                      icon="snap"
                      label={t("Snap: 0.5 / 10 in 2D, 15°, scale 0.1 (Ctrl)")}
                      active={s.snapTransforms}
                      onClick={() => {
                        s.snapTransforms = !s.snapTransforms;
                        s.emit();
                        s.editorCommand();
                      }}
                    />
                    <Button
                      icon="focus"
                      label={t("Focus selection (F)")}
                      disabled={!s.selected}
                      onClick={() => s.editorCommand({ action: "focus" })}
                    />
                    <Button
                      icon="reset"
                      label={t("Reset to game camera")}
                      onClick={() => s.editorCommand({ action: "reset" })}
                    />
                    <span className="divider" />
                  </>
                )}
                <Button
                  icon="undo"
                  label={t("Undo edit")}
                  disabled={!s.document.undoStack.length}
                  onClick={() => s.undo()}
                />
                <Button
                  icon="redo"
                  label={t("Redo edit")}
                  disabled={!s.document.redoStack.length}
                  onClick={() => s.redo()}
                />
                <span className="divider" />
                <Button
                  icon="image"
                  label={t("Project assets")}
                  active={s.assetPanel}
                  onClick={() => {
                    s.assetPanel = !s.assetPanel;
                    s.emit();
                  }}
                />
                <Button
                  icon="help"
                  label={t("Scene controls")}
                  active={help}
                  onClick={() => setHelp(!help)}
                />
              </div>
              {help && (
                <aside className="viewport-help panel">
                  <div className="panel-heading">
                    <h2>{t("Scene controls")}</h2>
                    <Button
                      icon="close"
                      label={t("Close scene help")}
                      onClick={() => setHelp(false)}
                    />
                  </div>
                  <dl>
                    <dt>{t("Selection")}</dt>
                    <dd>{t("Click an object")}</dd>
                    <dt>{t("Gizmos")}</dt>
                    <dd>{t("W · move, E · rotate, R · scale")}</dd>
                    <dt>{t("Free camera")}</dt>
                    <dd>
                      {t("Right mouse + drag, WASD / QE, Shift for speed")}
                    </dd>
                    <dt>{t("Orbit selection")}</dt>
                    <dd>{t("Alt + left drag")}</dd>
                    <dt>{t("Pan")}</dt>
                    <dd>{t("Middle drag or Q + drag")}</dd>
                    <dt>{t("Zoom")}</dt>
                    <dd>{t("Mouse wheel")}</dd>
                    <dt>{t("Focus")}</dt>
                    <dd>{t("F or double-click")}</dd>
                    <dt>{t("Snapping")}</dt>
                    <dd>{t("Ctrl while dragging a gizmo")}</dd>
                    <dt>{t("Cancel gesture")}</dt>
                    <dd>Esc</dd>
                    <dt>{t("Duplicate / delete")}</dt>
                    <dd>Ctrl D / Delete</dd>
                    <dt>{t("Code")}</dt>
                    <dd>{t("Ctrl F · search, Tab · indent, Ctrl Z · undo")}</dd>
                  </dl>
                </aside>
              )}
            </>
          )}
          {viewport && (
            <div className="viewport-caption">
              {s.view === "preview"
                ? t("Playing your current version")
                : t("Right mouse + WASD — camera · Wheel — zoom · F — focus")}
              <kbd>
                {s.view === "preview" ? "WebGPU" : t("W / E / R — gizmos")}
              </kbd>
            </div>
          )}
          {s.assetPanel && s.view === "editor" && <Assets />}
        </div>
        {consoleOpen && (
          <RuntimeConsole
            key={s.workspace.id}
            active={!hidden && viewport}
            onClose={() => setConsoleOpen(false)}
          />
        )}
      </div>
      {!viewport && <div className="section-cover" aria-hidden="true" />}
      {(showObjects || showInspector) && (
        <aside
          className={`scene-sidebar ${showInspector ? "has-inspector" : ""}`}
          aria-label={t("Scene panels")}
        >
          {showObjects && <Objects />}
          {showInspector && <Inspector />}
        </aside>
      )}
      {showAssistant && (
        <Assistant
          collapsed={assistantCollapsed}
          onToggle={() => setAssistantCollapsed(!assistantCollapsed)}
        />
      )}
      {s.view === "assets" && <Assets />}
      {s.view === "overview" && <ProjectOverview />}
      <Code key={s.workspace.id} hidden={s.view !== "code"} />
    </main>
  );
}
function Objects() {
  const s = studio,
    [search, setSearch] = useState(""),
    [collapsed, setCollapsed] = useState(false);
  const entities = (s.scene?.entities ?? []).filter((e) =>
    e.name.toLowerCase().includes(search.toLowerCase()),
  );
  return (
    <section className={`panel objects-panel ${collapsed ? "collapsed" : ""}`}>
      <div className="panel-heading">
        <h2>{t("Scene objects")}</h2>
        <Button
          icon={collapsed ? "plus" : "minus"}
          label={collapsed ? t("Expand objects") : t("Collapse objects")}
          onClick={() => setCollapsed(!collapsed)}
        />
      </div>
      {!collapsed && (
        <>
          <div className="object-search">
            <div>
              <Icon name="search" size={15} />
              <input
                aria-label={t("Search objects")}
                placeholder={t("Find in scene")}
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <Button
              icon="plus"
              label={t("Add object")}
              onClick={act(() => s.addEntity())}
            />
          </div>
          <div className="tree-heading">
            <Icon name="down" size={11} /> {t("Objects")}{" "}
            <span>{entities.length}</span>
          </div>
          <div className="entity-list">
            {entities.map((e) => (
              <button
                key={e.id}
                data-annotation-entity={e.id}
                className={`entity-row ${s.selected === e.id ? "selected" : ""}`}
                onClick={() => s.select(e.id)}
                onDoubleClick={() =>
                  s.editorCommand({ action: "focus", selected: e.id })
                }
                style={{
                  paddingLeft:
                    10 + Math.min(6, hierarchyDepth(e, s.scene.entities)) * 12,
                }}
              >
                <Icon name={entityIcon(e)} size={15} />
                <span>{e.name}</span>
                {s.selected === e.id && <span className="selection-dot" />}
              </button>
            ))}
          </div>
          <div className="panel-footnote">
            <Icon name="cloud" size={13} />{" "}
            {t("Changes are saved automatically")}
          </div>
        </>
      )}
    </section>
  );
}

function hierarchyDepth(entity, entities) {
  let depth = 0,
    parent = entity.parent;
  const visited = new Set([entity.id]);
  while (parent && !visited.has(parent)) {
    visited.add(parent);
    depth++;
    parent = entities.find((e) => e.id === parent)?.parent;
  }
  return depth;
}

export { Workspace };
