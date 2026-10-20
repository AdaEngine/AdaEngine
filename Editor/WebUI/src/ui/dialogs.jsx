import { AICredits } from "./ai-credits.jsx";
import React from "react";
import { studio } from "./state.js";
import { useEffect } from "react";
import { Icon, Mark, Button, act, entityIcon } from "./controls.jsx";
import {
  t,
  languagePreference,
  setLanguage,
  currentLanguage,
} from "../localization.js";
import { providersForMode, setBillingMode } from "../provider-settings.js";

function Modal({ title, onClose, children }) {
  useEffect(() => {
    const listener = (e) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", listener);
    return () => window.removeEventListener("keydown", listener);
  }, []);
  return (
    <div
      className="modal-backdrop"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <section
        className="modal panel"
        role="dialog"
        aria-modal="true"
        aria-label={title}
      >
        <div className="panel-heading">
          <h2>{title}</h2>
          <Button icon="close" label={t("Close window")} onClick={onClose} />
        </div>
        {children}
      </section>
    </div>
  );
}
function Settings() {
  const s = studio;
  return (
    <Modal
      title={t("Your assistant")}
      onClose={() => {
        s.settings = false;
        s.emit();
      }}
    >
      <div className="modal-body">
        <label className="field-label">
          {t("Interface language")}
          <select
            aria-label={t("Interface language")}
            value={languagePreference()}
            onChange={(e) => {
              setLanguage(e.target.value);
              s.emit();
            }}
          >
            <option value="system">{t("System language")}</option>
            <option value="en">English</option>
            <option value="ru">Русский</option>
          </select>
        </label>
        <p className="muted">
          {t("Choose who will help you create your game.")}
        </p>
        {!s.account && s.status !== "loading" && (
          <p className="fine-print" role="status">
            {t("Sign in to Ada Cloud to create and save projects.")}
          </p>
        )}
        {s.development && !s.development.codexEnabled && (
          <p className="fine-print">
            {t(
              "Local Codex is disabled. Start the development server once with --codex to enable and remember it.",
            )}
          </p>
        )}
        <div className="segmented">
          <button
            disabled={s.running || s.admitting}
            className={s.billingMode === "ada" ? "active" : ""}
            onClick={() => {
              setBillingMode(s, "ada");
            }}
          >
            Ada AI
          </button>
          <button
            disabled={s.running || s.admitting}
            className={s.billingMode === "byok" ? "active" : ""}
            onClick={() => {
              setBillingMode(s, "byok");
            }}
          >
            {t("Your API key")}
          </button>
          {s.providers.some((p) => p.transport === "codex") && (
            <button
              disabled={s.running || s.admitting}
              className={s.billingMode === "codex" ? "active" : ""}
              onClick={() => setBillingMode(s, "codex")}
            >
              {t("Local Codex")}
            </button>
          )}
        </div>
        {s.billingMode === "ada" && <AICredits details />}
        {s.billingMode === "codex" && (
          <p className="fine-print">
            {t(
              "Uses the Codex CLI sign-in on this computer. No API key is needed.",
            )}
          </p>
        )}
        <label className="field-label">
          {t("Provider")}
          <select
            disabled={s.running || s.admitting || !providersForMode(s).length}
            value={s.providerID}
            onChange={(e) => {
              s.providerID = e.target.value;
              s.modelID = s.models.find((m) => m.tools)?.id || "";
              s.emit();
            }}
          >
            {!providersForMode(s).length && (
              <option value="">
                {s.status === "loading"
                  ? t("Loading providers…")
                  : t("No providers available")}
              </option>
            )}
            {providersForMode(s).map((p) => (
              <option key={p.id} value={p.id}>
                {p.title}
              </option>
            ))}
          </select>
        </label>
        <label className="field-label">
          {t("Model")}
          <select
            disabled={s.running || s.admitting || !s.models.length}
            value={s.modelID}
            onChange={(e) => {
              s.modelID = e.target.value;
              s.emit();
            }}
          >
            {!s.models.length && (
              <option value="">{t("No models available")}</option>
            )}
            {s.models.map((m) => (
              <option key={m.id} value={m.id} disabled={!m.tools}>
                {m.tools ? m.title : t("{0} — no tools", m.title)}
              </option>
            ))}
          </select>
        </label>
        {s.billingMode === "byok" && (
          <>
            <label className="field-label">
              {t("API key")}
              <input
                type="password"
                disabled={s.running || s.admitting}
                autoComplete="off"
                value={s.apiKey}
                onChange={(e) => {
                  s.apiKey = e.target.value;
                  s.emit();
                }}
                placeholder={t("Selected provider API key")}
              />
            </label>
            <p className="fine-print">
              {t(
                "The key stays in this tab’s memory and is not included in the project.",
              )}
            </p>
          </>
        )}
        <button
          className="button primary wide"
          onClick={() => {
            s.settings = false;
            s.emit();
          }}
        >
          {t("Continue")}
        </button>
      </div>
    </Modal>
  );
}
function History() {
  const s = studio;
  return (
    <Modal
      title={t("Your world’s history")}
      onClose={() => {
        s.history = false;
        s.emit();
      }}
    >
      <div className="modal-body">
        <p className="muted">
          {t("Return to any checkpoint. Restoring creates a new version.")}
        </p>
        <button
          className="button primary wide"
          onClick={act(() => s.checkpoint())}
        >
          <Icon name="plus" size={16} />
          {t("Save checkpoint")}
        </button>
        <div className="history-list">
          {s.checkpoints.map((c) => (
            <button key={c.revision} onClick={act(() => s.restore(c.revision))}>
              <Icon name="history" />
              <span>
                <strong>{t("Version {0}", c.revision)}</strong>
                <small>
                  {new Date(c.updatedAt * 1000).toLocaleString(
                    currentLanguage(),
                  )}
                </small>
              </span>
              <Icon name="undo" size={15} />
            </button>
          ))}
        </div>
      </div>
    </Modal>
  );
}

function LeaveProject() {
  const s = studio;
  const stay = () => {
    if (s.leaving) return;
    s.leavePrompt = "";
    s.emit();
  };
  return (
    <Modal title={t("Could not save the project to Cloud")} onClose={stay}>
      <div className="modal-body">
        <p>
          {t(
            "Your project “{0}” stays open. Retry saving or save a local copy before returning to Playground.",
            s.snapshot.title,
          )}
        </p>
        <p className="muted">
          {t(
            "The local copy is available only on this device. Studio will restore it the next time you open the project. Download a ZIP for a separate backup.",
          )}
        </p>
        <p role="status">{s.leavePrompt}</p>
        <div className="leave-actions">
          <Button autoFocus disabled={s.leaving} onClick={stay}>
            {t("Stay in project")}
          </Button>
          <Button
            disabled={s.leaving}
            onClick={act(() => s.export())}
            icon="download"
          >
            {t("Download ZIP")}
          </Button>
          <Button disabled={s.leaving} onClick={act(() => s.browseProjects())}>
            {t("Retry saving")}
          </Button>
          <Button
            disabled={s.leaving}
            className="primary"
            onClick={act(() => s.browseProjects(true))}
          >
            {t("Save locally and leave")}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

export { Settings, History, LeaveProject };
