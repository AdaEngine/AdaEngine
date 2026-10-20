import { useEffect, useId, useRef, useState } from "react";
import { currentLanguage } from "../localization.js";
import {
  promptCompletion,
  completionEligible,
  completionLanguage,
  requestPromptCompletion,
} from "../prompt-completion.js";

export function usePromptCompletion(
  input,
  text,
  updateDraft,
  enabled,
  assistant = {},
) {
  const id = useId(),
    mirror = useRef();
  const [caret, setCaret] = useState(null),
    [focused, setFocused] = useState(false);
  const [composing, setComposing] = useState(false),
    [dismissed, setDismissed] = useState(null);
  const [candidate, setCandidate] = useState(null);
  const language = currentLanguage();
  const {
    providerID,
    model,
    billingMode,
    accountID,
    dimension = 3,
    players = "single",
    remote = false,
  } = assistant;
  const stamp = JSON.stringify([
    text,
    providerID,
    model,
    billingMode,
    accountID,
    dimension,
    players,
    language,
  ]);
  const cache = useRef(new Map());
  const [phase, setPhase] = useState("idle"),
    [retry, setRetry] = useState(0);
  const suffix =
    enabled &&
    focused &&
    !composing &&
    dismissed !== text &&
    caret?.start === text.length &&
    caret?.end === text.length &&
    candidate?.stamp === stamp
      ? candidate.suffix
      : "";
  useEffect(() => {
    setCandidate(null);
    setPhase("idle");
    if (
      !enabled ||
      !focused ||
      composing ||
      dismissed === text ||
      !caret ||
      !completionEligible(text, caret.start, caret.end)
    )
      return;
    let live = true;
    const controller = new AbortController();
    let deadline;
    const timer = setTimeout(
      async () => {
        const local = promptCompletion(text, caret.start, caret.end, language);
        if (local) {
          setCandidate({ stamp, suffix: local });
          return;
        }
        if (!remote || text.trim().length < 8) return;
        if (cache.current.has(stamp)) {
          setCandidate({ stamp, suffix: cache.current.get(stamp) });
          return;
        }
        setPhase("loading");
        deadline = setTimeout(() => controller.abort(), 22000);
        try {
          const suffix = await requestPromptCompletion(
            {
              providerID,
              model,
              billingMode,
              text,
              language: completionLanguage(text, language),
              dimension,
              players,
            },
            controller.signal,
          );
          if (
            live &&
            input.current?.value === text &&
            input.current.selectionStart === text.length &&
            input.current.selectionEnd === text.length
          ) {
            cache.current.set(stamp, suffix);
            if (cache.current.size > 32)
              cache.current.delete(cache.current.keys().next().value);
            setCandidate({ stamp, suffix });
            setPhase("idle");
          }
        } catch {
          if (live) setPhase("unavailable");
        } finally {
          clearTimeout(deadline);
        }
      },
      remote ? 700 : 300,
    );
    return () => {
      live = false;
      clearTimeout(timer);
      clearTimeout(deadline);
      controller.abort();
    };
  }, [
    stamp,
    caret?.start,
    caret?.end,
    enabled,
    focused,
    composing,
    dismissed,
    retry,
    remote,
  ]);
  useEffect(() => {
    if (mirror.current && input.current) {
      mirror.current.scrollTop = input.current.scrollTop;
      mirror.current.scrollLeft = input.current.scrollLeft;
    }
  }, [suffix]);
  const inspect = (event) =>
    setCaret({
      start: event.currentTarget.selectionStart,
      end: event.currentTarget.selectionEnd,
    });
  const accept = () => {
    const node = input.current;
    if (
      !suffix ||
      node.selectionStart !== text.length ||
      node.selectionEnd !== text.length ||
      node.value !== text
    )
      return false;
    const value = text + suffix;
    updateDraft(value);
    setCandidate(null);
    node.focus();
    requestAnimationFrame(() =>
      node.setSelectionRange(value.length, value.length),
    );
    return true;
  };
  return {
    id,
    mirror,
    suffix,
    phase: focused && enabled ? phase : "idle",
    focused,
    retry: () => {
      cache.current.delete(stamp);
      setRetry((value) => value + 1);
      input.current?.focus();
    },
    accept,
    onFocus: (event) => {
      setFocused(true);
      inspect(event);
    },
    onBlur: () => setFocused(false),
    onSelect: inspect,
    onInput: (event) => {
      inspect(event);
      setDismissed(null);
    },
    onScroll: (event) => {
      if (mirror.current) {
        mirror.current.scrollTop = event.currentTarget.scrollTop;
        mirror.current.scrollLeft = event.currentTarget.scrollLeft;
      }
    },
    onCompositionStart: () => setComposing(true),
    onCompositionEnd: (event) => {
      setComposing(false);
      inspect(event);
    },
    onKeyDown: (event) => {
      if (
        !suffix ||
        event.nativeEvent.isComposing ||
        event.shiftKey ||
        event.ctrlKey ||
        event.metaKey ||
        event.altKey
      )
        return false;
      if (event.key === "Escape") {
        event.preventDefault();
        setDismissed(text);
        return true;
      }
      if (event.key === "Tab" && accept()) {
        event.preventDefault();
        return true;
      }
      return false;
    },
  };
}
