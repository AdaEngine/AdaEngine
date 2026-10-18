import { t } from "../localization.js";
import React, { useEffect, useState } from "react";
import { studio } from "./state.js";
import { skills } from "../knowledge.js";
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
      <div className="agent-mode-controls">
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
      </div>
    </div>
  );
}
export function SkillPicker() {
  const s = studio,
    [catalog, setCatalog] = useState([]),
    [open, setOpen] = useState(false),
    [query, setQuery] = useState("");
  useEffect(() => {
    let active = true;
    skills(s)
      .then((value) => {
        if (active) setCatalog(value);
      })
      .catch((e) => s.fail(e));
    return () => {
      active = false;
    };
  }, [s.document]);
  const selected = s.session.skills || [];
  return (
    <div className="skill-picker">
      <button
        type="button"
        className="text-button"
        onClick={() => setOpen(!open)}
      >
        <Icon name="spark" size={13} /> {t("Skills")}
        {selected.length ? " · " + selected.length : ""}
      </button>
      {selected.map((id) => (
        <span className="skill-chip" key={id}>
          /{id}
        </span>
      ))}
      {open && (
        <section className="skill-menu panel" aria-label={t("Agent skills")}>
          <div className="panel-heading">
            <h2>{t("Studio skills")}</h2>
            <Button
              type="button"
              icon="close"
              label={t("Close skills")}
              onClick={() => setOpen(false)}
            />
          </div>
          <input
            aria-label={t("Search skills")}
            placeholder={t("Find a workflow…")}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <div>
            {catalog
              .filter((c) =>
                (c.id + " " + c.description)
                  .toLowerCase()
                  .includes(query.toLowerCase()),
              )
              .map((skill) => (
                <label key={skill.id}>
                  <input
                    type="checkbox"
                    checked={selected.includes(skill.id)}
                    disabled={s.runningSessionID === s.session.id}
                    onChange={(e) =>
                      s.updateChat((c) => {
                        const session = c.sessions.find(
                          (c) => c.id === s.session.id,
                        );
                        session.skills = e.target.checked
                          ? [...session.skills, skill.id]
                          : session.skills.filter((id) => id !== skill.id);
                      })
                    }
                  />
                  <span>
                    <strong>/{skill.id}</strong>
                    <small>{skill.description}</small>
                  </span>
                </label>
              ))}
          </div>
        </section>
      )}
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
