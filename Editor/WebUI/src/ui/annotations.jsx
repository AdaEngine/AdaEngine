import React, { useEffect, useRef } from "react";
import { studio } from "./state.js";
import { Button, Icon, act } from "./controls.jsx";
import { t } from "../localization.js";
import { annotationNumber } from "../annotations.js";
const anchorFor = (event) => {
  const box = event.currentTarget.getBoundingClientRect();
  return { x: box.left, y: box.top };
};

/** Project targets only: settings, credentials and editor chrome are never captured. */
export function AnnotationLayer() {
  const s = studio,
    input = useRef(),
    draft = s.annotationDraft;
  useEffect(() => {
    const target = (event) =>
      event.target.closest?.(
        "[data-annotation-component], [data-annotation-entity]",
      );
    const down = (event) => {
      if (
        !s.annotationMode ||
        s.annotationDraft ||
        event.button !== 0 ||
        event.target.closest?.("[data-annotation-ui]")
      )
        return;
      const element = target(event);
      if (!element) return;
      event.preventDefault();
      event.stopPropagation();
      s.action(() => {
        const anchor = { x: event.clientX, y: event.clientY };
        if (element.dataset.annotationEntity)
          s.annotateEntity(element.dataset.annotationEntity, anchor);
        else
          s.annotateUI(
            element.dataset.annotationSurface,
            element.dataset.annotationGeneration,
            element.dataset.annotationComponent,
            anchor,
          );
      });
    };
    const click = (event) => {
      if (
        s.annotationMode &&
        target(event) &&
        !event.target.closest?.("[data-annotation-ui]")
      ) {
        event.preventDefault();
        event.stopPropagation();
        if (event.detail === 0 && !s.annotationDraft) {
          const element = target(event),
            box = element.getBoundingClientRect();
          s.action(() => {
            const anchor = {
              x: box.left + box.width / 2,
              y: box.top + box.height / 2,
            };
            if (element.dataset.annotationEntity)
              s.annotateEntity(element.dataset.annotationEntity, anchor);
            else
              s.annotateUI(
                element.dataset.annotationSurface,
                element.dataset.annotationGeneration,
                element.dataset.annotationComponent,
                anchor,
              );
          });
        }
      }
    };
    const key = (event) => {
      if (s.annotationMode && event.key === "Escape") {
        event.preventDefault();
        event.stopPropagation();
        s.cancelAnnotation();
      }
    };
    const resize = () => {
      if (s.annotationMode) s.emit();
    };
    document.addEventListener("pointerdown", down, true);
    document.addEventListener("click", click, true);
    window.addEventListener("keydown", key, true);
    window.addEventListener("resize", resize);
    return () => {
      document.removeEventListener("pointerdown", down, true);
      document.removeEventListener("click", click, true);
      window.removeEventListener("keydown", key, true);
      window.removeEventListener("resize", resize);
    };
  }, []);
  useEffect(() => {
    input.current?.focus();
  }, [draft]);
  if (!s.annotationMode || !s.document || s.projectBrowser) return null;
  if (!draft)
    return (
      <aside className="annotation-hint" role="status" data-annotation-ui>
        <Icon name="annotate" />
        <span>
          {t("Select an object, a form element or a point in the game")}
          {(s.session.annotations || []).length > 0 && (
            <small>
              {t("Ready to send together: {0}", s.session.annotations.length)}
            </small>
          )}
        </span>
        <Button
          icon="close"
          label={t("Cancel annotation")}
          onClick={() => s.cancelAnnotation()}
        />
      </aside>
    );
  const left = Math.max(12, Math.min(draft.anchor.x + 12, innerWidth - 352)),
    top = Math.max(12, Math.min(draft.anchor.y + 12, innerHeight - 420));
  return (
    <form
      className="annotation-popover panel"
      style={{ left, top, maxHeight: Math.max(100, innerHeight - top - 12) }}
      role="dialog"
      aria-label={t("Annotate element")}
      data-annotation-ui
      onSubmit={(event) => {
        event.preventDefault();
        s.action(() => s.addAnnotation());
      }}
    >
      <header>
        <Icon name="annotate" size={16} />
        <strong>{t("Annotation #{0}", draft.number)}</strong>
        <Button
          type="button"
          icon="close"
          label={t("Cancel annotation")}
          onClick={() => s.cancelAnnotation()}
        />
      </header>
      <p className="annotation-target-label">{draft.target.label}</p>
      {draft.sceneTarget && (
        <label className="annotation-kind">
          {t("Annotation target")}
          <select
            aria-label={t("Annotation target")}
            value={draft.target.kind === "entity" ? "entity" : "preview"}
            onChange={(event) => {
              draft.target =
                event.target.value === "entity"
                  ? draft.sceneTarget
                  : {
                      kind: "preview",
                      label: t("Game UI element"),
                      point: draft.sceneTarget.point,
                    };
              s.emit();
            }}
          >
            <option value="entity">{t("Scene object")}</option>
            <option value="preview">{t("Game UI element")}</option>
          </select>
        </label>
      )}
      {draft.image && (
        <img src={draft.image} alt={t("Selected point in the game")} />
      )}
      <textarea
        ref={input}
        aria-label={t("What should change?")}
        placeholder={t("For example: make this button larger…")}
        value={draft.note}
        maxLength={4000}
        onChange={(event) => {
          draft.note = event.target.value;
          s.emit();
        }}
        onKeyDown={(event) => {
          if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
            event.preventDefault();
            s.action(() => s.addAnnotation());
          }
        }}
      />
      {draft.busy && (
        <p className="muted" role="status">
          {t("Capturing element context…")}
        </p>
      )}
      {draft.error && (
        <p className="field-error" role="alert">
          {draft.error}
        </p>
      )}
      {draft.image && !s.model?.vision && (
        <p className="muted">
          {t(
            "This model receives text context only. Choose a vision model to include the image.",
          )}
        </p>
      )}
      <footer>
        <span>{t("Review it in the composer before sending")}</span>
        <Button
          type="submit"
          className="primary"
          disabled={draft.busy || !!draft.error || !draft.note.trim()}
        >
          {draft.editingID ? t("Save annotation") : t("Add to composer")}
        </Button>
      </footer>
    </form>
  );
}

export function AnnotationViewport() {
  const s = studio;
  if (!s.annotationMode) return null;
  return (
    <div
      className="annotation-viewport"
      role="application"
      aria-label={t("Select a point to annotate")}
      onPointerDown={(event) => {
        if (event.target.closest?.("[data-annotation-ui]")) return;
        event.preventDefault();
        event.stopPropagation();
        if (event.button !== 0 || s.annotationDraft) return;
        const box = event.currentTarget.getBoundingClientRect();
        s.action(() =>
          s.annotatePreview(
            {
              x: (event.clientX - box.left) / box.width,
              y: (event.clientY - box.top) / box.height,
            },
            { x: event.clientX, y: event.clientY },
          ),
        );
      }}
      onClick={(event) => {
        event.preventDefault();
        event.stopPropagation();
      }}
    >
      {(s.session.annotations || [])
        .filter(
          (r) =>
            r.batchID === s.annotationBatchID &&
            r.target.point &&
            r.id !== s.annotationDraft?.editingID,
        )
        .map((item) => (
          <button
            key={item.id}
            type="button"
            className="annotation-pin"
            data-annotation-ui
            aria-label={t(
              "Edit annotation #{0}: {1}",
              annotationNumber(s.session.annotations, item),
              item.target.label,
            )}
            style={{
              left: item.target.point.x * 100 + "%",
              top: item.target.point.y * 100 + "%",
            }}
            onClick={(event) => {
              event.stopPropagation();
              s.editAnnotation(item.id, anchorFor(event));
            }}
          >
            {annotationNumber(s.session.annotations, item)}
          </button>
        ))}
      {s.annotationDraft?.target.point && (
        <span
          className="annotation-pin"
          style={{
            left: s.annotationDraft.target.point.x * 100 + "%",
            top: s.annotationDraft.target.point.y * 100 + "%",
          }}
        >
          {s.annotationDraft.number}
        </span>
      )}
    </div>
  );
}

export function AnnotationChips() {
  const s = studio;
  return (
    <div className="annotation-chips">
      {(s.session.annotations || []).map((item) => (
        <div className="annotation-chip" key={item.id}>
          {item.image && (
            <img src={item.image} alt={t("Selected point in the game")} />
          )}
          <button
            type="button"
            className="annotation-edit"
            data-annotation-ui
            aria-label={t(
              "Edit annotation #{0}: {1}",
              annotationNumber(s.session.annotations, item),
              item.target.label,
            )}
            title={item.note}
            onClick={(event) => s.editAnnotation(item.id, anchorFor(event))}
          >
            <b>#{annotationNumber(s.session.annotations, item)}</b>{" "}
            {item.target.label}
          </button>
          <Button
            type="button"
            icon="close"
            label={t("Remove annotation: {0}", item.target.label)}
            onClick={act(() => s.removeAnnotation(item.id))}
          />
        </div>
      ))}
      {(s.session.annotations || []).length > 1 && (
        <small>
          {t("Ready to send together: {0}", s.session.annotations.length)}
        </small>
      )}
    </div>
  );
}
