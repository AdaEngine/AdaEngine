import { t } from "../localization.js";
import React from "react";
import { studio } from "./state.js";
import { Button, Icon, act } from "./controls.jsx";
export function ConversationToolbar() {
  const s = studio;
  return (
    <div className="conversation-toolbar">
      <div className="conversation-tabs" aria-label={t("Agent conversations")}>
        {s.chat.sessions.map((session) => (
          <button
            key={session.id}
            className={session.id === s.session.id ? "active" : ""}
            onClick={() => s.switchSession(session.id)}
          >
            {session.title}
            {s.runningSessionID === session.id && <span className="live-dot" />}
          </button>
        ))}
        <Button
          icon="plus"
          label={t("New conversation")}
          onClick={act(() => s.newSession())}
        />
      </div>
      <details className="conversation-preferences">
        <summary
          title={t("Conversation settings")}
          aria-label={t("Conversation settings")}
        >
          <Icon name="settings" size={16} />
        </summary>
        <div className="agent-mode-controls panel">
          <label>
            {t("Agent mode")}
            <select
              aria-label={t("Agent mode")}
              value={s.session.mode}
              disabled={s.runningSessionID === s.session.id}
              onChange={(e) =>
                s.updateChat((c) => {
                  c.sessions.find((c) => c.id === s.session.id).mode =
                    e.target.value;
                })
              }
            >
              <option value="build">{t("Edit project")}</option>
              <option value="plan">{t("Discuss and plan")}</option>
            </select>
          </label>
          <label>
            {t("Tool permissions")}
            <select
              aria-label={t("Tool permissions")}
              value={s.session.permission}
              disabled={s.runningSessionID === s.session.id}
              onChange={(e) =>
                s.updateChat((c) => {
                  c.sessions.find((c) => c.id === s.session.id).permission =
                    e.target.value;
                })
              }
            >
              <option value="auto">{t("Apply changes")}</option>
              <option value="ask">{t("Ask before changes")}</option>
            </select>
          </label>
        </div>
      </details>
    </div>
  );
}
export function PermissionRequest() {
  const s = studio,
    r = s.permissionRequest;
  if (!r) return null;
  return (
    <section className="tool-permission" role="status">
      <strong>{t("The agent wants to change the project")}</strong>
      <code>{r.name}</code>
      <pre>{JSON.stringify(r.args, null, 2).slice(0, 1600)}</pre>
      <div>
        <Button onClick={() => r.decide(false)}>{t("Deny")}</Button>
        <Button onClick={() => r.decide("once")}>{t("Allow once")}</Button>
        <Button onClick={() => r.decide("session")}>
          {t("Allow in this conversation")}
        </Button>
      </div>
    </section>
  );
}
