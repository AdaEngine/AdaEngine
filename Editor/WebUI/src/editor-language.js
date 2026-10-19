import { EditorState } from "@codemirror/state";
import { EditorView } from "@codemirror/view";
import {
  closeSearchPanel,
  openSearchPanel,
  searchPanelOpen,
} from "@codemirror/search";
import { t } from "./localization.js";

export function editorLanguageExtensions() {
  return [
    EditorState.phrases.of({
      "Selection deleted": t("Selection deleted"),
      Find: t("Find"),
      Replace: t("Replace"),
      next: t("Next"),
      previous: t("Previous"),
      all: t("All"),
      "match case": t("Match case"),
      regexp: t("Regular expression"),
      "by word": t("Whole words"),
      replace: t("Replace"),
      "replace all": t("Replace all"),
      close: t("Close search"),
      "Go to line": t("Go to line"),
      go: t("Go"),
      "current match": t("Current match"),
      "on line": t("On line"),
      "replaced match on line $": t("Replaced match on line {0}", "$"),
      "replaced $ matches": t("Replaced {0} matches", "$"),
    }),
    EditorView.contentAttributes.of({
      "aria-label": t("Source code"),
      spellcheck: "false",
    }),
  ];
}

export function refreshEditorLanguage(editor, compartment) {
  const panel = editor.dom.querySelector(".cm-search");
  const focused = editor.dom.ownerDocument.activeElement;
  const searchName = panel?.contains(focused)
    ? focused.getAttribute("name")
    : null;
  const selection =
    searchName && "selectionStart" in focused
      ? [focused.selectionStart, focused.selectionEnd]
      : null;
  const open = searchPanelOpen(editor.state);
  // The library builds its search labels only when the panel is created.
  if (open) closeSearchPanel(editor);
  editor.dispatch({
    effects: compartment.reconfigure(editorLanguageExtensions()),
  });
  if (open) {
    openSearchPanel(editor);
    const next = searchName
      ? editor.dom.querySelector(`.cm-search [name="${searchName}"]`)
      : focused;
    if (next?.isConnected) {
      next.focus();
      if (selection && typeof next.setSelectionRange === "function")
        next.setSelectionRange(...selection);
    }
  }
}
