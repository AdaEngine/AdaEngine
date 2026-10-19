import React, { useEffect, useSyncExternalStore } from "react";
import { createRoot } from "react-dom/client";
import { studio } from "./ui/state.js";
import { Icon, Mark, Button, act } from "./ui/controls.jsx";
import { Games, LibraryRail } from "./ui/playground.jsx";
import { Home } from "./ui/home.jsx";
import { Workspace } from "./ui/workspace.jsx";
import { Settings, History, LeaveProject } from "./ui/dialogs.jsx";
import { AnnotationLayer } from "./ui/annotations.jsx";
import { t, languagePreference, resolveLanguage } from "./localization.js";
import { installNavigation } from "./navigation.js";
import { CloudPanel } from "./ui/cloud-panel.jsx";
import "./style.css";
import "./playground.css";
function App() {
  useSyncExternalStore(studio.subscribe, studio.getVersion);
  const s = studio;
  const library = !s.document || s.projectBrowser;
  useEffect(() => {
    document.title = library
      ? "Ada Playground"
      : `${s.snapshot.title} — Ada Studio`;
    document.documentElement.lang = resolveLanguage(
      languagePreference(),
      navigator.languages,
    );
  });
  useEffect(() => {
    const refreshLanguage = (event) => {
      if (
        event.type !== "storage" ||
        event.key === "AdaEditor.language" ||
        event.key === null
      )
        studio.emit();
    };
    window.addEventListener("languagechange", refreshLanguage);
    window.addEventListener("storage", refreshLanguage);
    return () => {
      window.removeEventListener("languagechange", refreshLanguage);
      window.removeEventListener("storage", refreshLanguage);
    };
  }, []);
  useEffect(() => {
    const navigation = installNavigation(studio);
    void navigation.start();
    return () => navigation.stop();
  }, []);
  return (
    <div
      className={`app playground-app ${library ? "library-mode" : ""} ${s.annotationMode ? "annotating" : ""}`}
    >
      <aside className="rail">
        <button
          className="brand"
          aria-label={t("Ada Playground home")}
          onClick={act(() => s.browseLibrary("games"))}
        >
          <Mark />
        </button>
        {library ? (
          <LibraryRail />
        ) : (
          <>
            <nav className="rail-group" aria-label={t("Project sections")}>
              {[
                ["overview", "home", t("Project overview")],
                ["editor", "cube", t("Scene")],
                ["assets", "image", t("Assets")],
                ["code", "code", t("Code")],
                ["assistant", "spark", t("Assistant")],
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
                label={t("Agent settings")}
                onClick={() => {
                  s.settings = true;
                  s.emit();
                }}
              />
              <div className="avatar" title={s.account?.name || "Ada Cloud"}>
                {s.account?.name?.slice(0, 1) || "A"}
              </div>
            </div>
          </>
        )}
      </aside>
      <div className="main">
        <header className="topbar">
          {library ? (
            <div className="library-wordmark">
              <strong>Ada Playground</strong>
              <span>{t("Create. Share. Play.")}</span>
            </div>
          ) : (
            <>
              <div className="breadcrumbs">
                <button
                  className="projects-link"
                  disabled={s.leaving}
                  onClick={act(() => s.browseProjects())}
                >
                  <Icon name="folder" size={14} /> {t("My projects")}
                </button>
                <Icon name="chevron" size={12} />
                {s.document ? (
                  <input
                    aria-label={t("Project title")}
                    key={s.workspace.id}
                    defaultValue={s.snapshot.title}
                    onBlur={(e) => s.action(() => s.rename(e.target.value))}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") e.target.blur();
                    }}
                  />
                ) : (
                  <span>{t("Your workspace")}</span>
                )}
                {s.document && !library && (
                  <span
                    className={`save-state ${s.status}`}
                    title={
                      s.status === "saved"
                        ? t("All changes saved")
                        : s.status === "offline"
                          ? t(
                              "The cloud is unavailable. You can save a local copy before leaving.",
                            )
                          : t("Saving")
                    }
                  >
                    <i />
                    {s.status === "saved"
                      ? t("Saved")
                      : s.status === "signedout"
                        ? t("Sign in to save")
                        : s.status === "offline"
                          ? t("Offline")
                          : t("Saving…")}
                  </span>
                )}
              </div>
              {s.document && !s.projectBrowser && (
                <span className="workspace-section-name">
                  {
                    {
                      overview: t("Project overview"),
                      editor: t("Scene"),
                      assets: t("Assets"),
                      code: t("Code"),
                      assistant: t("Assistant"),
                      preview: t("Game"),
                    }[s.view]
                  }
                </span>
              )}
            </>
          )}
          <div className="header-actions">
            {s.document && !library && (
              <>
                {!s.projectBrowser && (
                  <Button
                    icon="annotate"
                    active={s.annotationMode}
                    data-annotation-ui
                    onClick={() => s.toggleAnnotations()}
                  >
                    {t("Annotate")}
                  </Button>
                )}
                <Button
                  className="primary"
                  icon={s.playing ? "stop" : "play"}
                  onClick={act(() => (s.playing ? s.stop() : s.play()))}
                >
                  {s.playing ? t("Stop") : t("Run")}
                </Button>
                <Button
                  icon="history"
                  label={t("Version history")}
                  onClick={act(() => s.showHistory())}
                />
                <Button
                  icon="download"
                  label={t("Download project")}
                  onClick={act(() => s.export())}
                />
              </>
            )}
            <Button
              icon="settings"
              label={t("Settings")}
              onClick={() => {
                s.settings = true;
                s.emit();
              }}
            />
          </div>
        </header>
        {s.document && <Workspace hidden={s.projectBrowser} />}
        {library &&
          (s.libraryView === "games" ? (
            <Games selectedId={s.route?.id} />
          ) : ["account", "publications", "legal"].includes(s.libraryView) ? (
            <CloudPanel route={s.route || { href: location.pathname }} />
          ) : (
            <Home section={s.libraryView} />
          ))}
      </div>
      {s.settings && <Settings />}
      {s.history && <History />}
      {s.leavePrompt && <LeaveProject />}
      <AnnotationLayer />
      {s.error && (
        <div className="toast" role="alert">
          <span>{s.error}</span>
          <Button
            icon="close"
            label={t("Dismiss message")}
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
