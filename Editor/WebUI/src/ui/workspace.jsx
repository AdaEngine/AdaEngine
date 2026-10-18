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

function Workspace({ hidden = false }) {
  const s = studio,
    host = useRef(),
    [mobile, setMobile] = useState(false),
    [help, setHelp] = useState(false);
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
  return (
    <main
      hidden={hidden}
      className={`workspace section-${s.view} ${s.viewportExpanded && viewport ? "viewport-expanded" : ""}`}
    >
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
                  ? "Не удалось обновить сцену"
                  : "Загружаем сцену в AdaEngine"}
              </h3>
              <p>
                {s.runtime === "error" ? (
                  s.viewportError
                ) : (
                  <>
                    Сцену и игру рисует AdaEngine.
                    <br />
                    Редактор уже готов к работе.
                  </>
                )}
              </p>
              {s.runtime === "error" && (
                <button
                  className="button"
                  onClick={act(() => s.retryViewport())}
                >
                  Повторить загрузку
                </button>
              )}
            </div>
          )}
        </div>
      </div>
      {!viewport && <div className="section-cover" aria-hidden="true" />}
      {!s.viewportExpanded && viewport && s.panel === "objects" && <Objects />}
      {((!s.viewportExpanded && s.assistant && s.view === "editor") ||
        s.view === "assistant") && <Assistant />}
      {!s.viewportExpanded &&
        s.inspector &&
        s.selected &&
        s.view === "editor" && <Inspector />}
      {(s.view === "assets" || (s.assetPanel && s.view === "editor")) && (
        <Assets />
      )}
      {s.view === "overview" && <ProjectOverview />}
      <Code key={s.workspace.id} hidden={s.view !== "code"} />
      {viewport && (
        <div className="stage-badge">
          <span className={s.runtime === "ready" ? "live-dot" : "muted-dot"} />
          {"AdaEngine · " +
            (s.runtime === "loading"
              ? "Обновление сцены…"
              : s.runtime === "error"
                ? "Ошибка сцены"
                : s.playing
                  ? "Игра запущена"
                  : "Редактор сцены")}
        </div>
      )}
      {viewport && (
        <>
          <div className="viewport-controls">
            <Button
              icon="monitor"
              label="Настольный вид"
              active={!mobile}
              onClick={() => setMobile(false)}
            />
            <Button
              icon="phone"
              label="Мобильный вид"
              active={mobile}
              onClick={() => setMobile(true)}
            />
          </div>
          <div className="viewport-toolbar">
            <Button
              icon={s.viewportExpanded ? "close" : "focus"}
              label={
                s.viewportExpanded
                  ? "Вернуться к панелям (Esc)"
                  : "Развернуть сцену"
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
                  ["hand", "camera", "Камера / панорама (Q)"],
                  ["move", "move", "Перемещение (W)"],
                  ["rotate", "rotate", "Вращение (E)"],
                  ["scale", "scale", "Масштаб (R)"],
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
                  label="Локальные оси перемещения"
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
                  label="Привязка: 0.5 / 10 в 2D, 15°, масштаб 0.1 (Ctrl)"
                  active={s.snapTransforms}
                  onClick={() => {
                    s.snapTransforms = !s.snapTransforms;
                    s.emit();
                    s.editorCommand();
                  }}
                />
                <Button
                  icon="focus"
                  label="Фокус на объекте (F)"
                  disabled={!s.selected}
                  onClick={() => s.editorCommand({ action: "focus" })}
                />
                <Button
                  icon="reset"
                  label="Вернуться к камере игры"
                  onClick={() => s.editorCommand({ action: "reset" })}
                />
                <span className="divider" />
              </>
            )}
            <Button
              icon="undo"
              label="Отменить правку"
              disabled={!s.document.undoStack.length}
              onClick={() => s.undo()}
            />
            <Button
              icon="redo"
              label="Повторить правку"
              disabled={!s.document.redoStack.length}
              onClick={() => s.redo()}
            />
            <span className="divider" />
            <Button
              icon="image"
              label="Ассеты проекта"
              active={s.assetPanel}
              onClick={() => {
                s.assetPanel = !s.assetPanel;
                s.emit();
              }}
            />
            <Button
              icon="help"
              label="Управление сценой"
              active={help}
              onClick={() => setHelp(!help)}
            />
          </div>
          {help && (
            <aside className="viewport-help panel">
              <div className="panel-heading">
                <h2>Управление сценой</h2>
                <Button
                  icon="close"
                  label="Закрыть подсказки"
                  onClick={() => setHelp(false)}
                />
              </div>
              <dl>
                <dt>Выбор</dt>
                <dd>Щелчок по объекту</dd>
                <dt>Гизмо</dt>
                <dd>W · перемещение, E · вращение, R · масштаб</dd>
                <dt>Свободная камера</dt>
                <dd>ПКМ + мышь, WASD / QE, Shift быстрее</dd>
                <dt>Облететь объект</dt>
                <dd>Alt + левая кнопка</dd>
                <dt>Панорама</dt>
                <dd>Средняя кнопка или Q + перетаскивание</dd>
                <dt>Приближение</dt>
                <dd>Колесо мыши</dd>
                <dt>Фокус</dt>
                <dd>F или двойной щелчок</dd>
                <dt>Привязка</dt>
                <dd>Ctrl при перетаскивании гизмо</dd>
                <dt>Отменить жест</dt>
                <dd>Esc</dd>
                <dt>Копия / удалить</dt>
                <dd>Ctrl D / Delete</dd>
                <dt>Код</dt>
                <dd>Ctrl F · поиск, Tab · отступ, Ctrl Z · undo</dd>
              </dl>
            </aside>
          )}
        </>
      )}
      {viewport && (
        <div className="viewport-caption">
          {s.view === "preview"
            ? "Играет ваша текущая версия"
            : "ПКМ + WASD — камера · Колесо — масштаб · F — фокус"}
          <kbd>{s.view === "preview" ? "WebGPU" : "W / E / R — гизмо"}</kbd>
        </div>
      )}
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
        <h2>Объекты сцены</h2>
        <Button
          icon={collapsed ? "plus" : "minus"}
          label={collapsed ? "Развернуть объекты" : "Свернуть объекты"}
          onClick={() => setCollapsed(!collapsed)}
        />
      </div>
      {!collapsed && (
        <>
          <div className="object-search">
            <div>
              <Icon name="search" size={15} />
              <input
                aria-label="Поиск объектов"
                placeholder="Найти в сцене"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <Button
              icon="plus"
              label="Добавить объект"
              onClick={act(() => s.addEntity())}
            />
          </div>
          <div className="tree-heading">
            <Icon name="down" size={11} /> Объекты{" "}
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
            <Icon name="cloud" size={13} /> Изменения сохраняются автоматически
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
