import { t } from "../localization.js";
import React, { useEffect, useRef } from "react";
import { studio } from "./state.js";

/** Capture editor gestures in the Studio document, including drags that cross
 * the iframe/panels. Only bounded input is forwarded to the isolated Player. */
export function ViewportInput() {
  const host = useRef(),
    pending = useRef(null),
    frame = useRef(null);
  const send = (value) => {
    if (!studio.preview.ready) return;
    studio.preview
      .message("editor-input", {
        ...value,
        revision: studio.preview.editorRevision,
      })
      .catch((error) => studio.fail(error));
  };
  const position = (event) => {
    const box = host.current.getBoundingClientRect();
    return {
      x: event.clientX - box.left,
      y: event.clientY - box.top,
      width: box.width,
      height: box.height,
    };
  };
  const flush = () => {
    if (frame.current !== null) cancelAnimationFrame(frame.current);
    frame.current = null;
    if (pending.current) {
      send(pending.current);
      pending.current = null;
    }
  };
  const pointer = (event, phase) => {
    event.preventDefault();
    event.stopPropagation();
    const element = event.currentTarget;
    if (phase === "down") {
      element.focus();
      element.setPointerCapture(event.pointerId);
    }
    const value = {
      phase,
      ...position(event),
      button: event.button,
      pointerId: event.pointerId,
      altKey: event.altKey,
      shiftKey: event.shiftKey,
      ctrlKey: event.ctrlKey,
      metaKey: event.metaKey,
    };
    if (phase === "move") {
      pending.current = value;
      if (frame.current === null) frame.current = requestAnimationFrame(flush);
    } else {
      flush();
      send(value);
      if (phase === "up" && element.hasPointerCapture(event.pointerId))
        element.releasePointerCapture(event.pointerId);
    }
  };
  const cancel = () => {
    pending.current = null;
    if (frame.current !== null) cancelAnimationFrame(frame.current);
    frame.current = null;
    send({ phase: "cancel" });
  };
  useEffect(() => {
    const element = host.current;
    const wheel = (event) => {
      event.preventDefault();
      send({
        phase: "wheel",
        deltaY: Math.max(-200, Math.min(200, event.deltaY)),
      });
    };
    element.addEventListener("wheel", wheel, { passive: false });
    return () => {
      element.removeEventListener("wheel", wheel);
      cancel();
    };
  }, []);
  const key = (event, phase) => {
    if (event.key === "Tab") return;
    event.preventDefault();
    event.stopPropagation();
    send({
      phase,
      key: event.key,
      code: event.code,
      shiftKey: event.shiftKey,
      ctrlKey: event.ctrlKey,
      metaKey: event.metaKey,
      altKey: event.altKey,
    });
  };
  return (
    <div
      ref={host}
      className="viewport-input"
      tabIndex={0}
      role="application"
      aria-label={t("AdaEngine scene controls")}
      onPointerDown={(e) => pointer(e, "down")}
      onPointerMove={(e) => pointer(e, "move")}
      onPointerUp={(e) => pointer(e, "up")}
      onPointerCancel={cancel}
      onLostPointerCapture={cancel}
      onBlur={cancel}
      onContextMenu={(e) => e.preventDefault()}
      onKeyDown={(e) => key(e, "keyDown")}
      onKeyUp={(e) => key(e, "keyUp")}
    />
  );
}
