import React, { useEffect, useRef, useState } from "react";
import { t } from "../localization.js";
import { RuntimeLogBuffer } from "../runtime-logs.js";
import { studio } from "./state.js";
import { Button } from "./controls.jsx";

export function RuntimeConsole({ onClose, active = true }) {
  const buffer = useRef(new RuntimeLogBuffer()),
    output = useRef(),
    follow = useRef(true),
    [lines, setLines] = useState([]),
    [unavailable, setUnavailable] = useState(false);
  useEffect(() => {
    if (!active) return;
    let mounted = true,
      reading = false;
    const refresh = async () => {
      if (reading || !studio.preview.frame) return;
      reading = true;
      const source = studio.preview.frame;
      try {
        const snapshot = await studio.preview.message("logs");
        if (!mounted || source !== studio.preview.frame) return;
        setUnavailable(false);
        if (buffer.current.update(snapshot, source))
          setLines(buffer.current.lines);
      } catch (error) {
        if (mounted && error.name !== "AbortError") setUnavailable(true);
      } finally {
        reading = false;
      }
    };
    refresh();
    const timer = setInterval(refresh, 750);
    return () => {
      mounted = false;
      clearInterval(timer);
    };
  }, [active]);
  useEffect(() => {
    if (follow.current && output.current)
      output.current.scrollTop = output.current.scrollHeight;
  }, [lines]);
  return (
    <section
      className="runtime-console panel"
      aria-label={t("Runtime console")}
    >
      <div className="panel-heading">
        <h2>{t("Console")}</h2>
        <Button
          icon="trash"
          label={t("Clear console")}
          onClick={() => {
            buffer.current.clear();
            setLines([]);
          }}
        />
        <Button icon="close" label={t("Hide console")} onClick={onClose} />
      </div>
      <div
        className="console-output"
        ref={output}
        tabIndex={0}
        aria-label={t("AdaPlayer logs")}
        onScroll={() => {
          const node = output.current;
          follow.current =
            node.scrollHeight - node.scrollTop - node.clientHeight < 24;
        }}
      >
        {studio.viewportError && (
          <pre className="console-diagnostic">{studio.viewportError}</pre>
        )}
        {unavailable && (
          <p className="console-diagnostic">
            {t("Waiting for AdaPlayer logs…")}
          </p>
        )}
        {!lines.length && !studio.viewportError && !unavailable && (
          <p className="console-empty">
            {t("No logs yet. Run the game to see output.")}
          </p>
        )}
        {lines.map((line) => (
          <pre key={line.id}>{line.text}</pre>
        ))}
      </div>
    </section>
  );
}
