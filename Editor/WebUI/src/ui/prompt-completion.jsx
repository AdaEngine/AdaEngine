import { useEffect, useId, useRef, useState } from "react";
import { currentLanguage } from "../localization.js";
import { promptCompletion } from "../prompt-completion.js";

export function usePromptCompletion(input, text, updateDraft, enabled) {
  const id = useId(),
    mirror = useRef();
  const [caret, setCaret] = useState(null),
    [focused, setFocused] = useState(false);
  const [composing, setComposing] = useState(false),
    [dismissed, setDismissed] = useState(null);
  const [candidate, setCandidate] = useState(null);
  const language = currentLanguage();
  const suffix =
    enabled &&
    focused &&
    !composing &&
    dismissed !== text &&
    caret?.start === text.length &&
    caret?.end === text.length &&
    candidate?.text === text
      ? candidate.suffix
      : "";
  useEffect(() => {
    setCandidate(null);
    if (!enabled || !focused || composing || dismissed === text || !caret)
      return;
    const timer = setTimeout(
      () =>
        setCandidate({
          text,
          suffix: promptCompletion(text, caret.start, caret.end, language),
        }),
      300,
    );
    return () => clearTimeout(timer);
  }, [
    text,
    caret?.start,
    caret?.end,
    enabled,
    focused,
    composing,
    dismissed,
    language,
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
