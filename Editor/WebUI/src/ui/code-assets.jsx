import React from "react";
import { studio } from "./state.js";
import { useRef } from "react";
import { Icon, Mark, Button, act, entityIcon } from "./controls.jsx";
import { decode, bytes } from "../platform.js";
import { file } from "../documents.js";
import { SourceEditor } from "./source-editor.jsx";

function Code({ hidden = false }) {
  const s = studio,
    text = decode(file(s.snapshot, s.activeFile)?.data || ""),
    lines = text.split("\n").length;
  return (
    <section className="code-panel panel" hidden={hidden}>
      <div className="file-tabs">
        {s.sources.map((f) => (
          <button
            className={s.activeFile === f.path ? "active" : ""}
            key={f.path}
            onClick={() => {
              s.activeFile = f.path;
              s.emit();
            }}
          >
            <Icon name="code" size={14} />
            {f.path.split("/").at(-1)}
          </button>
        ))}
        <span />
        <Button
          icon="play"
          label="Проверить в AdaPlayer"
          onClick={act(() => s.play(true))}
        />
      </div>
      <div className="code-body">
        <SourceEditor text={text} path={s.activeFile} />
      </div>
      <div className="code-status">
        <span>AdaScript</span>
        <span>{s.activeFile}</span>
        <span>UTF-8 · {lines} строк</span>
      </div>
    </section>
  );
}
function Assets() {
  const s = studio,
    input = useRef();
  return (
    <section className="panel assets-panel">
      <div className="panel-heading">
        <h2>
          <Icon name="folder" size={15} />
          Ассеты проекта
        </h2>
        <span />
        <Button
          icon="upload"
          label="Загрузить ассет"
          onClick={() => input.current.click()}
        />
        <Button
          icon="close"
          label="Закрыть ассеты"
          onClick={() => {
            s.view === "assets" ? s.navigate("editor") : (s.assetPanel = false);
            s.emit();
          }}
        />
      </div>
      <div className="asset-grid">
        {s.snapshot.files
          .filter((f) => f.path.startsWith("Assets/"))
          .map((f) => (
            <button
              key={f.path}
              onClick={() => {
                s.prompt += (s.prompt ? "\n" : "") + "Используй " + f.path;
                s.assistant = true;
                s.navigate("assistant");
              }}
            >
              {/\.(png|jpe?g)$/i.test(f.path) ? (
                <img
                  src={`data:image/${f.path.endsWith(".png") ? "png" : "jpeg"};base64,${f.data}`}
                  alt=""
                />
              ) : (
                <Icon
                  name={f.path.endsWith(".glb") ? "cube" : "file"}
                  size={26}
                />
              )}
              <span title={f.path}>{f.path.split("/").at(-1)}</span>
              <small>{(bytes(f.data).length / 1024).toFixed(1)} КБ</small>
            </button>
          ))}
      </div>
      <input
        ref={input}
        hidden
        type="file"
        accept=".png,.jpg,.jpeg,.wav,.ogg,.glb"
        onChange={(e) => {
          if (e.target.files[0])
            s.action(() => s.uploadAsset(e.target.files[0]));
          e.target.value = "";
        }}
      />
    </section>
  );
}

export { Code, Assets };
