import React, { useEffect, useRef } from "react";
import { EditorState } from "@codemirror/state";
import {
  EditorView,
  lineNumbers,
  highlightActiveLine,
  highlightActiveLineGutter,
  drawSelection,
  keymap,
} from "@codemirror/view";
import { defaultKeymap, indentWithTab } from "@codemirror/commands";
import { searchKeymap, highlightSelectionMatches } from "@codemirror/search";
import {
  bracketMatching,
  indentOnInput,
  indentUnit,
  syntaxHighlighting,
  HighlightStyle,
} from "@codemirror/language";
import { tags } from "@lezer/highlight";
import { adaScript } from "../adascript.js";
import { studio } from "./state.js";

const colors = HighlightStyle.define([
  { tag: tags.keyword, color: "#c8a0ff" },
  { tag: tags.string, color: "#a5d6a7" },
  { tag: tags.number, color: "#e8bb85" },
  { tag: tags.comment, color: "#7d8a9a", fontStyle: "italic" },
  { tag: tags.meta, color: "#f0cc8d" },
  { tag: tags.typeName, color: "#82cecf" },
  { tag: tags.definition(tags.variableName), color: "#8fc8ff" },
  { tag: tags.bool, color: "#edacb9" },
]);

export function SourceEditor({ text, path }) {
  const host = useRef(),
    view = useRef(),
    applying = useRef(false);
  useEffect(() => {
    const editor = new EditorView({
      parent: host.current,
      state: EditorState.create({
        doc: text,
        extensions: [
          lineNumbers(),
          highlightActiveLine(),
          highlightActiveLineGutter(),
          drawSelection(),
          bracketMatching(),
          indentOnInput(),
          indentUnit.of("  "),
          highlightSelectionMatches(),
          adaScript,
          syntaxHighlighting(colors),
          keymap.of([
            {
              key: "Mod-z",
              run: () => {
                studio.undo();
                return true;
              },
            },
            {
              key: "Mod-Shift-z",
              run: () => {
                studio.redo();
                return true;
              },
            },
            {
              key: "Mod-y",
              run: () => {
                studio.redo();
                return true;
              },
            },
            ...searchKeymap,
            indentWithTab,
            ...defaultKeymap,
          ]),
          EditorView.contentAttributes.of({
            "aria-label": "Исходный код",
            spellcheck: "false",
          }),
          EditorView.theme(
            {
              "&": { height: "100%", background: "#101319", color: "#d6dce5" },
              ".cm-scroller": {
                overflow: "auto",
                fontFamily: "'Cascadia Code', Consolas, monospace",
                fontSize: "13px",
                lineHeight: "1.8",
              },
              ".cm-content": { padding: "20px 0" },
              ".cm-line": { padding: "0 24px 0 16px" },
              ".cm-gutters": {
                background: "#101319",
                color: "#626d7d",
                border: "none",
                padding: "0 8px 0 12px",
              },
              ".cm-activeLine, .cm-activeLineGutter": {
                background: "#ffffff05",
              },
              ".cm-cursor": { borderLeftColor: "#bcb3ff" },
              "&.cm-focused .cm-selectionBackground, .cm-selectionBackground": {
                background: "#554d875c",
              },
              ".cm-panels": { background: "#1a1f27", color: "#d6dce5" },
              ".cm-searchMatch": { background: "#b2925144" },
            },
            { dark: true },
          ),
          EditorView.updateListener.of((update) => {
            const selection = update.state.selection.main;
            studio.latestCodeSelection = update.state.sliceDoc(
              selection.from,
              selection.to,
            );
            if (update.docChanged && !applying.current)
              studio.action(() =>
                studio.writeCode(update.state.doc.toString()),
              );
          }),
        ],
      }),
    });
    view.current = editor;
    return () => {
      view.current = null;
      editor.destroy();
    };
  }, [path]);
  useEffect(() => {
    const editor = view.current;
    if (editor && editor.state.doc.toString() !== text) {
      applying.current = true;
      try {
        editor.dispatch({
          changes: { from: 0, to: editor.state.doc.length, insert: text },
        });
      } finally {
        applying.current = false;
      }
    }
  }, [text]);
  return <div ref={host} className="source-editor" />;
}
