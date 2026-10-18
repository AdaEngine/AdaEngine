import { t } from "../localization.js";
import React from "react";
import { decodeFences, resolve, failures } from "../a2ui.js";
import { studio } from "./state.js";
import { identity } from "../chat.js";
import { Button, act } from "./controls.jsx";
function Inline({ text }) {
  return text
    .split(/(\*\*[^*]+\*\*|`[^`]+`)/g)
    .map((part, i) =>
      part.startsWith("**") ? (
        <strong key={i}>{part.slice(2, -2)}</strong>
      ) : part.startsWith("`") ? (
        <code key={i}>{part.slice(1, -1)}</code>
      ) : (
        part
      ),
    );
}
export function Markdown({ text = "", interactive = false }) {
  const prose = interactive ? decodeFences(text, true).prose : text,
    blocks = prose.split(/(```[^\n]*\n[\s\S]*?```)/g);
  return (
    <div className="markdown">
      {blocks.map((block, i) =>
        block.startsWith("```") ? (
          <pre key={i}>
            <code>{block.replace(/^```[^\n]*\n/, "").replace(/```$/, "")}</code>
          </pre>
        ) : (
          block
            .split(/\n\s*\n/)
            .filter(Boolean)
            .map((p, j) =>
              /^#{1,4} /.test(p) ? (
                <h3 key={`${i}-${j}`}>
                  <Inline text={p.replace(/^#{1,4} /, "")} />
                </h3>
              ) : (
                <p key={`${i}-${j}`}>
                  <Inline text={p} />
                </p>
              ),
            )
        ),
      )}
    </div>
  );
}
export function A2UICard({ surface }) {
  const s = studio,
    r = surface;
  const disabled =
    s.running ||
    r.owner !== identity(s) ||
    ["receiving", "submitting", "submitted", "cancelled", "failed"].includes(
      r.status,
    );
  const edit = (path, value) =>
    s.action(() => s.editSurface(r.id, r.generation, path, value));
  const render = (id, depth = 0) => {
    if (depth > 64) return null;
    const c = r.components[id];
    if (!c) return null;
    const value = (prop) => resolve(c[prop], r.data),
      errors = failures(c, r.data),
      label = value("label");
    let control;
    switch (c.component) {
      case "Column":
      case "Row":
        return (
          <div
            key={id}
            className={"a2ui-" + c.component.toLowerCase()}
            style={{ gap: c.spacing ?? 12 }}
          >
            {c.children.map((child) => render(child, depth + 1))}
          </div>
        );
      case "Text":
        return <p key={id}>{value("text")}</p>;
      case "TextField":
        control = (
          <input
            aria-label={c.placeholder || id}
            placeholder={c.placeholder || ""}
            value={value("text") ?? ""}
            onChange={(e) => edit(c.text.path, e.target.value)}
            disabled={disabled}
          />
        );
        break;
      case "Toggle":
        control = (
          <label>
            <input
              type="checkbox"
              checked={value("value") ?? false}
              onChange={(e) => edit(c.value.path, e.target.checked)}
              disabled={disabled}
            />
            {label}
          </label>
        );
        break;
      case "ChoicePicker":
        control = (
          <label>
            {label}
            <select
              aria-label={label || id}
              value={value("value") ?? ""}
              onChange={(e) => edit(c.value.path, e.target.value)}
              disabled={disabled}
            >
              <option value="">{t("Choose…")}</option>
              {c.options.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </label>
        );
        break;
      case "Slider":
        control = (
          <label>
            {id} · {value("value") ?? c.min}
            <input
              aria-label={id}
              type="range"
              min={c.min}
              max={c.max}
              step={c.step || "any"}
              value={value("value") ?? c.min}
              onChange={(e) => edit(c.value.path, Number(e.target.value))}
              disabled={disabled}
            />
          </label>
        );
        break;
      case "Button": {
        const event = c.action.event;
        if (event.name === "editor.color.pick") {
          const context = resolve(event.context || {}, r.data),
            color = /^#[a-f\d]{6,8}$/i.test(context.value || "")
              ? context.value.slice(0, 7)
              : "#ffffff";
          control = (
            <label className="a2ui-color">
              {value("text")}
              <input
                aria-label={value("text")}
                type="color"
                value={color}
                disabled={disabled}
                onChange={(e) => edit(context.binding, e.target.value)}
              />
            </label>
          );
        } else
          control = (
            <button
              className="button primary"
              disabled={
                disabled ||
                errors.length > 0 ||
                (s.session.mode === "plan" && event.name.startsWith("editor."))
              }
              onClick={act(() => s.submitSurface(r.id, r.generation, id))}
            >
              {value("text")}
            </button>
          );
        break;
      }
      default:
        return null;
    }
    return (
      <div key={id} className="a2ui-control">
        {control}
        {errors.map((e, i) => (
          <small key={i} className="field-error">
            {e}
          </small>
        ))}
      </div>
    );
  };
  return (
    <section className="a2ui-card" aria-label={t("Interactive card {0}", r.id)}>
      <header>
        <strong>{r.id}</strong>
        <span>
          {
            {
              receiving: t("Receiving form…"),
              ready: t("Ready"),
              submitting: t("Sending…"),
              submitted: t("Sent"),
              failed: t("Error"),
              cancelled: t("Interrupted"),
            }[r.status]
          }
        </span>
      </header>
      {render("root")}
      {r.error && (
        <p className="field-error" role="status">
          {r.error}
        </p>
      )}
      {r.owner !== identity(s) && (
        <p className="muted">
          {t("Select the original agent to use this card.")}
        </p>
      )}
      <footer>
        {["failed", "cancelled"].includes(r.status) && r.components.root && (
          <Button
            disabled={s.running || r.owner !== identity(s)}
            onClick={act(() => s.restoreSurface(r.id, r.generation))}
          >
            {t("Restore card")}
          </Button>
        )}
        <Button
          icon="code"
          disabled={
            s.running ||
            r.owner !== identity(s) ||
            !["ready", "submitted"].includes(r.status)
          }
          onClick={act(() => s.exportSurface(r.id, r.generation))}
        >
          {t("Open .ui")}
        </Button>
        {r.lastApplication && (
          <Button
            icon="undo"
            disabled={disabled}
            onClick={act(() => s.undoSurface(r.id, r.generation))}
          >
            {t("Undo application")}
          </Button>
        )}
      </footer>
    </section>
  );
}
