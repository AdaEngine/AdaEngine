import { t, currentLanguage } from "../localization.js";
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
        {s.codeFiles.map((f) => (
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
          label={t("Validate in AdaPlayer")}
          onClick={act(() => s.play(true))}
        />
      </div>
      <div className="code-body">
        <SourceEditor text={text} path={s.activeFile} />
      </div>
      <div className="code-status">
        <span>
          {s.activeFile.endsWith(".ada") ? "AdaScript" : t("Project text")}
        </span>
        <span>{s.activeFile}</span>
        <span>{t("UTF-8 · {0} lines", lines)}</span>
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
          {t("Project assets")}
        </h2>
        <span />
        <Button
          icon="upload"
          label={t("Upload asset")}
          onClick={() => input.current.click()}
        />
        <Button
          icon="close"
          label={t("Close assets")}
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
                s.prompt += (s.prompt ? "\n" : "") + t("Use {0}", f.path);
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
              <small>
                {t(
                  "{0} KB",
                  (bytes(f.data).length / 1024).toLocaleString(
                    currentLanguage(),
                    { minimumFractionDigits: 1, maximumFractionDigits: 1 },
                  ),
                )}
              </small>
            </button>
          ))}
      </div>
      <input
        ref={input}
        hidden
        type="file"
        accept=".png,.jpg,.jpeg,.wav,.ogg,.glb,.vox"
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
