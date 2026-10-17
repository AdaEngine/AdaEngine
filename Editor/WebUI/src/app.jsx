import React, { useEffect, useSyncExternalStore } from "react";
import { createRoot } from "react-dom/client";
import { studio } from "./ui/state.js";
import { Icon, Mark, Button, act } from "./ui/controls.jsx";
import { Home } from "./ui/home.jsx";
import { Workspace } from "./ui/workspace.jsx";
import { Settings, History } from "./ui/dialogs.jsx";
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
          aria-label="Ada Studio — проекты"
          onClick={act(() => s.home())}
        >
          <Mark />
        </button>
        <div className="rail-group">
          <Button
            icon="home"
            label="Мои проекты"
            onClick={act(() => s.home())}
          />
          <Button
            icon="cube"
            label="Объекты сцены"
            active={!!s.document && s.panel === "objects"}
            onClick={() => {
              s.panel = s.panel === "objects" ? "" : "objects";
              s.emit();
            }}
          />
          <Button
            icon="image"
            label="Ассеты"
            active={s.assetPanel}
            onClick={() => {
              s.assetPanel = !s.assetPanel;
              s.emit();
            }}
          />
          <Button
            icon="code"
            label="Код"
            active={s.view === "code"}
            onClick={() => {
              s.view = s.view === "code" ? "editor" : "code";
              s.emit();
            }}
          />
          <Button
            icon="spark"
            label="Ассистент"
            active={s.assistant}
            onClick={() => {
              s.assistant = !s.assistant;
              s.emit();
            }}
          />
        </div>
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
            <button onClick={act(() => s.home())}>Studio</button>
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
                      ? "Нет соединения. Изменения сохранены на этом устройстве."
                      : "Сохранение"
                }
              >
                <i />
                {s.status === "saved"
                  ? "Сохранено"
                  : s.status === "offline"
                    ? "Нет соединения"
                    : "Сохраняется"}
              </span>
            )}
          </div>
          {s.document && (
            <nav className="mode-tabs" aria-label="Режим редактора">
              <Button
                icon="cube"
                active={s.view === "editor"}
                onClick={act(() => s.stop())}
              >
                Редактор
              </Button>
              <Button
                icon="code"
                active={s.view === "code"}
                onClick={() => {
                  s.view = "code";
                  s.emit();
                }}
              >
                Код
              </Button>
              <Button
                icon="play"
                active={s.view === "preview"}
                onClick={act(() => s.play())}
              >
                Игра
              </Button>
            </nav>
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
        {s.document ? <Workspace /> : <Home />}
      </div>
      {s.settings && <Settings />}
      {s.history && <History />}
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
