import React, { useEffect, useId, useRef, useState } from "react";
import { skills } from "../knowledge.js";
import { t } from "../localization.js";
import { skillPresentation } from "../skill-presentation.js";
import {
  commandMatches,
  completeSlash,
  slashQuery,
} from "../slash-commands.js";
import { Icon } from "./controls.jsx";
import { studio } from "./state.js";

export function useSkillCommands(
  input,
  updateDraft,
  { home = false, text = studio.prompt } = {},
) {
  const id = useId(),
    [token, setToken] = useState(null),
    [focused, setFocused] = useState(false),
    [dismissed, setDismissed] = useState(null),
    [catalog, setCatalog] = useState([]),
    [phase, setPhase] = useState("loading"),
    [active, setActive] = useState(0);
  const owner =
    !home && studio.document
      ? `${studio.workspace.id}:${studio.session.id}`
      : "home";
  const signature = token ? `${text}:${token.start}:${token.end}` : null;
  const open = focused && !!token && signature !== dismissed;
  const results = commandMatches(
    catalog.map(skillPresentation),
    token?.query || "",
  );
  const selected = Math.min(active, Math.max(0, results.length - 1));
  useEffect(() => {
    setToken(null);
    setDismissed(null);
  }, [owner]);
  useEffect(() => {
    if (!open) return;
    let current = true;
    setPhase("loading");
    skills(home ? {} : studio)
      .then((value) => {
        if (current) {
          setCatalog(value);
          setPhase("ready");
        }
      })
      .catch(() => {
        if (current) setPhase("error");
      });
    return () => {
      current = false;
    };
  }, [open, home ? null : studio.document]);
  const inspect = (event) => {
    const next = slashQuery(
      event.currentTarget.value,
      event.currentTarget.selectionStart,
      event.currentTarget.selectionEnd,
    );
    setToken(next);
    setActive(0);
  };
  const choose = (skill) => {
    // Resolve the caret again so a stale menu cannot replace another draft/token.
    const node = input.current;
    const current = slashQuery(text, node.selectionStart, node.selectionEnd);
    if (!current) return;
    const completion = completeSlash(text, current, skill.id);
    updateDraft(completion.text);
    setToken(null);
    requestAnimationFrame(() => {
      node.focus();
      node.setSelectionRange(completion.caret, completion.caret);
    });
  };
  const onKeyDown = (event) => {
    if (!open || event.nativeEvent.isComposing || event.keyCode === 229)
      return false;
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      setDismissed(signature);
      return true;
    }
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      event.stopPropagation();
      if (results.length)
        setActive(
          (selected + (event.key === "ArrowDown" ? 1 : results.length - 1)) %
            results.length,
        );
      return true;
    }
    if (!event.shiftKey && (event.key === "Enter" || event.key === "Tab")) {
      if (event.key === "Tab" && (!results.length || phase !== "ready"))
        return false;
      event.preventDefault();
      event.stopPropagation();
      if (phase === "ready" && results[selected]) choose(results[selected]);
      return true;
    }
    return false;
  };
  return {
    open,
    id,
    selected,
    results,
    phase,
    query: token?.query || "",
    choose,
    onKeyDown,
    onSelect: inspect,
    onFocus: (event) => {
      setFocused(true);
      inspect(event);
    },
    onBlur: () => setFocused(false),
    onInput: (event) => {
      setDismissed(null);
      inspect(event);
    },
  };
}

export function SkillCommands({ menu }) {
  const active = useRef();
  useEffect(() => {
    active.current?.scrollIntoView({ block: "nearest" });
  }, [menu.selected, menu.query]);
  if (!menu.open) return null;
  return (
    <section className="slash-menu panel" aria-label={t("Commands")}>
      <header>
        <span>{t("Commands")}</span>
        <code>/{menu.query}</code>
      </header>
      <div
        className="slash-options"
        role="listbox"
        id={menu.id}
        aria-label={t("Agent skills")}
      >
        {menu.phase !== "ready" ? (
          <p className="slash-empty">
            {menu.phase === "error"
              ? t("Commands are unavailable. Try typing / again.")
              : t("Loading commands…")}
          </p>
        ) : !menu.results.length ? (
          <p className="slash-empty">{t("No matching commands")}</p>
        ) : (
          menu.results.map((skill, index) => (
            <button
              type="button"
              tabIndex={-1}
              role="option"
              id={`${menu.id}-${index}`}
              key={skill.id}
              aria-selected={index === menu.selected}
              ref={index === menu.selected ? active : null}
              className={`slash-option ${index === menu.selected ? "active" : ""}`}
              onPointerDown={(event) => event.preventDefault()}
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => menu.choose(skill)}
            >
              <span className="slash-option-icon">
                <Icon name={skill.project ? "folder" : "spark"} size={15} />
              </span>
              <span className="slash-option-content">
                <strong>/{skill.id}</strong>
                <small>{skill.description}</small>
              </span>
              {index === menu.selected && (
                <span className="slash-enter" aria-hidden="true">
                  ↵
                </span>
              )}
            </button>
          ))
        )}
      </div>
      <footer>{t("↑↓ Navigate · Enter Select · Esc Close")}</footer>
    </section>
  );
}
