import React, { useEffect, useSyncExternalStore } from "react";
import { createRoot } from "react-dom/client";
import { studio } from "./ui/state.js";
import { Icon, Mark, Button, act } from "./ui/controls.jsx";
import { Home } from "./ui/home.jsx";
import { Workspace } from "./ui/workspace.jsx";
import { Settings, History, LeaveProject } from "./ui/dialogs.jsx";
import "./style.css";
function App() {
  useSyncExternalStore(studio.subscribe, studio.getVersion);
  const s = studio;
  useEffect(() => {
    studio.start();
  }, []);
  return (
    <div className="app">
      <aside className="rail">
        <button
          className="brand"
          aria-label="Ada Studio — обзор проекта"
          onClick={act(() => s.home())}
        >
          <Mark />
        </button>
        <nav className="rail-group" aria-label="Разделы проекта">
          {[
            ["overview", "home", "Обзор проекта"],
            ["editor", "cube", "Сцена"],
            ["assets", "image", "Ассеты"],
            ["code", "code", "Код"],
            ["assistant", "spark", "Ассистент"],
          ].map(([view, icon, label]) => (
            <Button
              key={view}
              icon={icon}
              label={label}
              disabled={!s.document}
              active={!!s.document && !s.projectBrowser && s.view === view}
              onClick={act(() =>
                view === "editor" ? s.stop() : s.navigate(view),
              )}
            />
          ))}
        </nav>
        <div className="rail-bottom">
          <Button
            icon="settings"
            label="Настройки агента"
            onClick={() => {
              s.settings = true;
              s.emit();
            }}
          />
          <div className="avatar" title={s.account?.name || "Ada Cloud"}>
            {s.account?.name?.slice(0, 1) || "A"}
          </div>
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          <div className="breadcrumbs">
            <button
              className="projects-link"
              disabled={s.leaving}
              onClick={act(() => s.browseProjects())}
            >
              <Icon name="folder" size={14} /> Все проекты
            </button>
            <Icon name="chevron" size={12} />
            {s.document ? (
              <input
                aria-label="Название проекта"
                key={s.workspace.id}
                defaultValue={s.snapshot.title}
                onBlur={(e) => s.action(() => s.rename(e.target.value))}
                onKeyDown={(e) => {
                  if (e.key === "Enter") e.target.blur();
                }}
              />
            ) : (
              <span>Ваше пространство</span>
            )}
            {s.document && (
              <span
                className={`save-state ${s.status}`}
                title={
                  s.status === "saved"
                    ? "Все изменения сохранены"
                    : s.status === "offline"
                      ? "Облако недоступно. Перед выходом можно сохранить локальную копию."
                      : "Сохранение"
                }
              >
                <i />
                {s.status === "saved"
                  ? "Сохранено"
                  : s.status === "signedout"
                    ? "Войдите для сохранения"
                    : s.status === "offline"
                      ? "Нет соединения"
                      : "Сохраняется"}
              </span>
            )}
          </div>
          {s.document && !s.projectBrowser && (
            <span className="workspace-section-name">
              {
                {
                  overview: "Обзор проекта",
                  editor: "Сцена",
                  assets: "Ассеты",
                  code: "Код",
                  assistant: "Ассистент",
                  preview: "Игра",
                }[s.view]
              }
            </span>
          )}
          <div className="header-actions">
            {s.document && (
              <>
                <Button
                  className="primary"
                  icon={s.playing ? "stop" : "play"}
                  onClick={act(() => (s.playing ? s.stop() : s.play()))}
                >
                  {s.playing ? "Остановить" : "Запустить"}
                </Button>
                <Button
                  icon="history"
                  label="История версий"
                  onClick={act(() => s.showHistory())}
                />
                <Button
                  icon="download"
                  label="Скачать проект"
                  onClick={act(() => s.export())}
                />
              </>
            )}
            <Button
              icon="settings"
              label="Настройки"
              onClick={() => {
                s.settings = true;
                s.emit();
              }}
            />
          </div>
        </header>
        {s.document && <Workspace hidden={s.projectBrowser} />}
        {(!s.document || s.projectBrowser) && <Home />}
      </div>
      {s.settings && <Settings />}
      {s.history && <History />}
      {s.leavePrompt && <LeaveProject />}
      {s.error && (
        <div className="toast" role="alert">
          <span>{s.error}</span>
          <Button
            icon="close"
            label="Закрыть сообщение"
            onClick={() => {
              s.error = "";
              s.emit();
            }}
          />
        </div>
      )}
    </div>
  );
}
createRoot(document.getElementById("root")).render(<App />);
