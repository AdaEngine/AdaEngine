import { t } from "../localization.js";
import React from "react";
import { studio } from "./state.js";
import { useRef, useEffect, useState } from "react";
import { sessionMessages } from "../chat.js";
import { Markdown, A2UICard } from "./chat-content.jsx";
import {
  ConversationToolbar,
  SkillPicker,
  PermissionRequest,
} from "./agent-sessions.jsx";
import { Icon, Mark, Button, act, entityIcon } from "./controls.jsx";

function Assistant() {
  const s = studio,
    [collapsed, setCollapsed] = useState(false),
    chat = useRef();
  useEffect(() => {
    if (chat.current) chat.current.scrollTop = chat.current.scrollHeight;
  }, [s.streamText, s.snapshot.messages.length, s.running, s.session.id]);
  const messages = sessionMessages(s.snapshot, s.session.id).filter(
    (m) =>
      m.role !== "tool" &&
      m.kind !== "tool-images" &&
      (m.content || m.toolCalls?.length),
  );
  const activeTurn = s.running && s.runningSessionID === s.session.id;
  const events = s.chat.events.filter((e) => e.sessionID === s.session.id);
  return (
    <section
      className={`panel assistant-panel ${collapsed ? "collapsed" : ""}`}
    >
      <div className="panel-heading">
        <h2>
          <span className="assistant-star">
            <Mark size={18} />
          </span>
          {t("Assistant")}
        </h2>
        <span className="assistant-state">
          {s.running ? t("Creating…") : t("Here to help")}
        </span>
        <Button
          icon={collapsed ? "plus" : "minus"}
          label={t("Collapse assistant")}
          onClick={() => setCollapsed(!collapsed)}
        />
      </div>
      {!collapsed && (
        <>
          <ConversationToolbar />
          <div className="conversation" ref={chat}>
            {s.session.plan?.length > 0 && (
              <ol className="agent-plan">
                {s.session.plan.map((step, i) => (
                  <li key={i} className={step.status}>
                    <span>
                      {step.status === "done"
                        ? "✓"
                        : step.status === "running"
                          ? "◌"
                          : "○"}
                    </span>
                    {step.title}
                  </li>
                ))}
              </ol>
            )}
            {!messages.length ? (
              <div className="assistant-welcome">
                <Mark size={30} />
                <h3>{t("Let’s create something of your own")}</h3>
                <p>
                  {t(
                    "Describe your game or select the object you want to change.",
                  )}
                </p>
                <div className="suggestions">
                  {[
                    t("Add a game objective"),
                    t("Improve the environment"),
                    t("What can we do next?"),
                  ].map((t) => (
                    <button
                      key={t}
                      onClick={() => {
                        s.prompt = t;
                        s.emit();
                      }}
                    >
                      <Icon name="plus" size={11} />
                      {t}
                    </button>
                  ))}
                </div>
              </div>
            ) : (
              messages.map((m) => (
                <div className={`chat-message ${m.role}`} key={m.id}>
                  <div className="message-author">
                    {m.role === "user" ? (
                      t("You")
                    ) : (
                      <>
                        <Mark size={15} /> Ada
                      </>
                    )}
                  </div>
                  <Markdown
                    interactive={m.role === "assistant"}
                    text={
                      m.displayContent ||
                      m.content.replace(
                        /\n\[Selected (scene )?entity\][\s\S]*/,
                        "",
                      )
                    }
                  />
                  {s.chat.surfaces
                    .filter(
                      (r) =>
                        r.messageID === m.id && r.sessionID === s.session.id,
                    )
                    .map((r) => (
                      <A2UICard key={r.generation} surface={r} />
                    ))}
                  {events
                    .filter((e) => e.messageID === m.id && e.type === "tool")
                    .map((e) => (
                      <details className="tool-event" key={e.id}>
                        <summary>
                          {e.status === "done" ? "✓" : "!"} {toolLabel(e.name)}
                        </summary>
                        <pre>{e.summary}</pre>
                      </details>
                    ))}
                </div>
              ))
            )}
            {activeTurn && (
              <div className="chat-message assistant">
                <div className="message-author">
                  <Mark size={15} /> Ada
                </div>
                <Markdown
                  interactive
                  text={s.streamText || t("Thinking about the changes…")}
                />
                {s.chat.surfaces
                  .filter(
                    (r) =>
                      r.messageID === s.streamMessageID &&
                      r.sessionID === s.session.id,
                  )
                  .map((r) => (
                    <A2UICard key={r.generation} surface={r} />
                  ))}
              </div>
            )}
            {activeTurn && s.activity.length > 0 && (
              <div className="tool-activity">
                {s.activity.slice(-3).map((a, i) => (
                  <span key={i}>
                    <Icon
                      name={
                        a.status === "done"
                          ? "check"
                          : a.status === "running"
                            ? "rotate"
                            : "close"
                      }
                      size={12}
                    />
                    {toolLabel(a.name)}
                  </span>
                ))}
              </div>
            )}
          </div>
          <PermissionRequest />
          {s.session.usage && (
            <div className="agent-usage">
              {t(
                "Last run: {0} input · {1} output tokens",
                s.session.usage.inputTokens,
                s.session.usage.outputTokens,
              )}
            </div>
          )}
          {events
            .filter((e) => e.type === "run-error" || e.type === "a2ui-error")
            .slice(-1)
            .map((e) => (
              <p key={e.id} className="field-error" role="status">
                {e.message}
              </p>
            ))}
          {s.selected && (
            <div className="context-chip">
              <Icon name="cube" size={12} />{" "}
              {t("In context: {0}", s.entity?.name)}
              <button
                aria-label={t("Clear selection")}
                onClick={() => {
                  s.selected = null;
                  s.emit();
                }}
              >
                ×
              </button>
            </div>
          )}
          <Composer />
        </>
      )}
    </section>
  );
}
const toolLabel = (name) =>
  ({
    editor_skills_read: t("Reading a skill"),
    editor_skills_list: t("Finding relevant skills"),
    editor_sprite_generate: t("Creating a sprite"),
    editor_audio_generate: t("Synthesizing audio"),
    editor_model_generate: t("Creating a 3D model"),
    editor_voxel_generate: t("Creating a voxel model"),
    editor_audio_inspect: t("Measuring audio"),
    editor_model_inspect: t("Inspecting a 3D model"),
    editor_image_read: t("Inspecting an image"),
    editor_docs_search: t("Searching documentation"),
    editor_docs_read: t("Reading documentation"),
    editor_api_describe: t("Inspecting the API"),
    editor_project_context: t("Inspecting the project"),
    editor_scene_apply: t("Applying scene changes"),
    editor_file_patch: t("Patching code"),
    editor_plan_update: t("Updating the plan"),
    editor_examples_list: t("Finding examples"),
    editor_examples_read: t("Reading an example"),
    editor_scene_get: t("Inspecting the scene"),
    editor_file_write: t("Updating code"),
    editor_scene_set: t("Editing an object"),
    editor_build: t("Validating in AdaPlayer"),
    editor_play_start: t("Starting the game"),
    editor_play_capture: t("Inspecting the result"),
  })[name] || t("Working on the project");
function Composer({ home = false }) {
  const s = studio,
    attach = useRef();
  return (
    <form
      className={`composer ${home ? "home-composer" : ""}`}
      onSubmit={(e) => {
        e.preventDefault();
        s.action(() => s.send(s.prompt));
      }}
    >
      <textarea
        aria-label={t("Message the assistant")}
        placeholder={
          home
            ? t("Describe the game you dream of creating…")
            : t("What would you like to create or change?")
        }
        value={s.prompt}
        onChange={(e) => {
          s.prompt = e.target.value;
          if (s.document)
            s.updateChat((c) => {
              c.sessions.find((c) => c.id === s.session.id).draft =
                e.target.value;
            });
          else s.emit();
        }}
        onPaste={(e) => {
          const files = Array.from(e.clipboardData.files);
          if (files.length && s.document) {
            e.preventDefault();
            s.action(async () => {
              for (const f of files.slice(0, 4)) await s.attachFile(f);
            });
          }
        }}
        onKeyDown={(e) => {
          if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
            e.preventDefault();
            if (s.prompt.trim()) s.action(() => s.send(s.prompt));
          }
        }}
      />
      {!home && <SkillPicker />}
      {!home && (s.session.attachments || []).length > 0 && (
        <div className="attachment-chips">
          {s.session.attachments.map((path) => (
            <button
              type="button"
              key={path}
              onClick={() =>
                s.updateChat((c) => {
                  const session = c.sessions.find((c) => c.id === s.session.id);
                  session.attachments = session.attachments.filter(
                    (p) => p !== path,
                  );
                })
              }
            >
              {path.split("/").at(-1)} ×
            </button>
          ))}
        </div>
      )}
      <div className="composer-footer">
        <Button
          type="button"
          icon="plus"
          label={t("Attach a file")}
          onClick={() => attach.current.click()}
          disabled={!s.document}
        />
        <button
          type="button"
          className="model-picker"
          onClick={() => {
            s.settings = true;
            s.emit();
          }}
        >
          <Icon name="spark" size={12} />
          <span>{s.model?.title || t("Choose a model")}</span>
          <Icon name="down" size={11} />
        </button>
        <span className="composer-spacer" />
        {s.running ? (
          <Button
            type="button"
            icon="stop"
            label={t("Stop the assistant")}
            className="send"
            onClick={() => s.stopAgent()}
          />
        ) : (
          <Button
            type="submit"
            icon="arrow"
            label={t("Send message")}
            className="send"
            disabled={!s.prompt.trim() || !s.account}
          />
        )}
      </div>
      <input
        type="file"
        hidden
        ref={attach}
        accept=".png,.jpg,.jpeg,.wav,.ogg,.glb,.md,.txt,.ada"
        onChange={(e) => {
          const f = e.target.files[0];
          if (f)
            s.action(async () => {
              await s.attachFile(f);
            });
          e.target.value = "";
        }}
      />
    </form>
  );
}

export { Assistant, Composer };
