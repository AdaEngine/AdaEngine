import { attachmentAccept, attachmentEntries } from "../attachments.js";
import { AttachmentChips } from "./attachment-chips.jsx";
import { AICredits } from "./ai-credits.jsx";
import { usePromptCompletion } from "./prompt-completion.jsx";
import { CreationPicker } from "./creation-picker.jsx";
import { creationOptions } from "../creation.js";
import { t } from "../localization.js";
import React from "react";
import { studio } from "./state.js";
import { useRef, useEffect, useState } from "react";
import { sessionMessages } from "../chat.js";
import { Markdown, A2UICard } from "./chat-content.jsx";
import { AnnotationChips } from "./annotations.jsx";
import { SkillCommands, useSkillCommands } from "./skill-commands.jsx";
import { ConversationToolbar, PermissionRequest } from "./agent-sessions.jsx";
import { Icon, Mark, Button, act, entityIcon } from "./controls.jsx";

function Assistant({ collapsed, onToggle }) {
  const s = studio,
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
        <h2>{t("Assistant")}</h2>
        <span className="assistant-state">
          {s.running ? t("Creating…") : t("Here to help")}
        </span>
        <Button
          icon={collapsed ? "plus" : "minus"}
          label={collapsed ? t("Expand assistant") : t("Collapse assistant")}
          onClick={onToggle}
        />
      </div>
      {!collapsed && (
        <>
          <ConversationToolbar />
          {s.billingMode === "ada" && <AICredits />}
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
                  {m.attachments?.length > 0 && (
                    <AttachmentChips items={m.attachments} />
                  )}
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
    attach = useRef(),
    input = useRef();
  const updateDraft = (value) => {
    s.prompt = value;
    if (s.document)
      s.updateChat((c) => {
        c.sessions.find((session) => session.id === s.session.id).draft = value;
      });
    else s.emit();
  };
  const [dragging, setDragging] = useState(false);
  const attachments = attachmentEntries(s, home);
  const blocked = s.attachmentBusy || s.admitting || s.running;
  const canSend = !!s.prompt.trim() || attachments.length > 0;
  const addFiles = (files) => s.action(() => s.attachFiles(files));
  const commands = useSkillCommands(input, updateDraft);
  const completion = usePromptCompletion(
    input,
    s.prompt,
    updateDraft,
    home && !commands.open && !s.running && !s.admitting,
  );
  const creation = creationOptions(s.creation);
  const send = () => {
    if (!blocked && canSend)
      return s.action(() => s.send(s.prompt, home ? { creation } : undefined));
  };
  const working =
    s.running && !!s.document && s.runningSessionID === s.session.id;
  useEffect(() => {
    if (s.composerFocus) input.current?.focus();
  }, [s.composerFocus]);
  return (
    <form
      className={`composer ${home ? "home-composer" : ""} ${working ? "composer-working" : ""} ${dragging ? "composer-dragging" : ""}`}
      aria-busy={working || s.attachmentBusy || undefined}
      onDragOver={(event) => {
        if (Array.from(event.dataTransfer.types).includes("Files")) {
          event.preventDefault();
          event.dataTransfer.dropEffect = blocked ? "none" : "copy";
          if (!blocked) setDragging(true);
        }
      }}
      onDragLeave={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget))
          setDragging(false);
      }}
      onDrop={(event) => {
        if (event.dataTransfer.files.length) {
          event.preventDefault();
          setDragging(false);
          if (!blocked) addFiles(Array.from(event.dataTransfer.files));
        }
      }}
      onSubmit={(e) => {
        e.preventDefault();
        send();
      }}
    >
      {dragging && (
        <div className="attachment-drop-hint">{t("Drop files to attach")}</div>
      )}
      <SkillCommands menu={commands} />
      <div className="composer-input">
        {completion.suffix && (
          <div
            className="completion-mirror"
            ref={completion.mirror}
            aria-hidden="true"
          >
            <span className="completion-prefix">{s.prompt}</span>
            <span>{completion.suffix}</span>
          </div>
        )}
        <textarea
          ref={input}
          role="combobox"
          aria-autocomplete={completion.suffix ? "both" : "list"}
          aria-describedby={completion.suffix ? completion.id : undefined}
          aria-expanded={commands.open}
          aria-controls={commands.open ? commands.id : undefined}
          aria-activedescendant={
            commands.open &&
            commands.results.length &&
            commands.phase === "ready"
              ? `${commands.id}-${commands.selected}`
              : undefined
          }
          onFocus={(event) => {
            commands.onFocus(event);
            completion.onFocus(event);
          }}
          onBlur={() => {
            commands.onBlur();
            completion.onBlur();
          }}
          onSelect={(event) => {
            commands.onSelect(event);
            completion.onSelect(event);
          }}
          onScroll={completion.onScroll}
          onCompositionStart={completion.onCompositionStart}
          onCompositionEnd={completion.onCompositionEnd}
          aria-label={t("Message the assistant")}
          placeholder={
            home
              ? t("Describe the game you dream of creating…")
              : t("What would you like to create or change?")
          }
          value={s.prompt}
          onChange={(e) => {
            updateDraft(e.target.value);
            commands.onInput(e);
            completion.onInput(e);
          }}
          onPaste={(e) => {
            const files = Array.from(e.clipboardData.files);
            if (files.length) {
              e.preventDefault();
              if (!blocked) addFiles(files);
            }
          }}
          onKeyDown={(e) => {
            if (commands.onKeyDown(e) || completion.onKeyDown(e)) return;
            if (
              e.key === "Enter" &&
              !e.shiftKey &&
              !e.nativeEvent.isComposing &&
              e.keyCode !== 229
            ) {
              e.preventDefault();
              if (canSend) send();
            }
          }}
        />
      </div>
      {!home && <AnnotationChips />}
      <AttachmentChips
        items={attachments}
        disabled={blocked}
        onRemove={(id) => s.removeAttachment(id, home)}
      />
      {s.attachmentBusy && (
        <div className="attachment-status" role="status">
          {t("Preparing files…")}
        </div>
      )}
      <div className="composer-footer">
        <Button
          type="button"
          icon="plus"
          label={t("Attach a file")}
          onClick={() => attach.current.click()}
          disabled={blocked}
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
        {home && (
          <div className="creation-options">
            <CreationPicker
              label={t("Game dimension")}
              value={creation.dimension}
              disabled={s.admitting || s.running}
              options={[
                {
                  value: 3,
                  label: t("3D"),
                  icon: "cube",
                  description: t("Depth, light and space"),
                },
                {
                  value: 2,
                  label: t("2D"),
                  icon: "image",
                  description: t("Sprites and flat worlds"),
                },
              ]}
              onChange={(dimension) => {
                s.creation = { ...creation, dimension };
                s.emit();
              }}
            />
            <CreationPicker
              label={t("Player mode")}
              value={creation.players}
              disabled={s.admitting || s.running}
              options={[
                {
                  value: "single",
                  label: t("Single-player"),
                  icon: "user",
                  description: t("An adventure of your own"),
                },
                {
                  value: "multiplayer",
                  label: t("Multiplayer"),
                  icon: "users",
                  description: t("Play together with others"),
                },
              ]}
              onChange={(players) => {
                s.creation = { ...creation, players };
                s.emit();
              }}
            />
          </div>
        )}
        {completion.suffix && (
          <button
            type="button"
            className="completion-accept"
            id={completion.id}
            aria-label={t("Complete suggestion: {0}", completion.suffix)}
            onPointerDown={(event) => event.preventDefault()}
            onMouseDown={(event) => event.preventDefault()}
            onClick={completion.accept}
          >
            <kbd>Tab</kbd>
            {t("Accept suggestion")}
          </button>
        )}
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
            disabled={!canSend || !s.account || blocked}
          />
        )}
      </div>
      <input
        type="file"
        hidden
        ref={attach}
        accept={attachmentAccept}
        multiple
        disabled={blocked}
        onChange={(e) => {
          const files = Array.from(e.target.files || []);
          if (files.length) addFiles(files);
          e.target.value = "";
        }}
      />
    </form>
  );
}

export { Assistant, Composer };
