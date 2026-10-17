import React from "react";
import { studio } from "./state.js";
import { useRef, useEffect, useState } from "react";
import { Icon, Mark, Button, act, entityIcon } from "./controls.jsx";

function Assistant() {
  const s = studio,
    [collapsed, setCollapsed] = useState(false),
    chat = useRef();
  useEffect(() => {
    if (chat.current) chat.current.scrollTop = chat.current.scrollHeight;
  }, [s.streamText, s.snapshot.messages.length, s.running]);
  const messages = s.snapshot.messages.filter(
    (m) =>
      m.role !== "tool" &&
      m.content &&
      !m.content.startsWith("Current game frame"),
  );
  return (
    <section
      className={`panel assistant-panel ${collapsed ? "collapsed" : ""}`}
    >
      <div className="panel-heading">
        <h2>
          <span className="assistant-star">
            <Mark size={18} />
          </span>
          Ассистент
        </h2>
        <span className="assistant-state">
          {s.running ? "Создаёт…" : "Рядом с вами"}
        </span>
        <Button
          icon={collapsed ? "plus" : "minus"}
          label="Свернуть ассистента"
          onClick={() => setCollapsed(!collapsed)}
        />
      </div>
      {!collapsed && (
        <>
          <div className="conversation" ref={chat}>
            {!messages.length ? (
              <div className="assistant-welcome">
                <Mark size={30} />
                <h3>Давайте создадим что-то ваше</h3>
                <p>
                  Расскажите об игре или выберите объект,
                  <br />
                  который хотите изменить.
                </p>
                <div className="suggestions">
                  {[
                    "Добавь цель игры",
                    "Улучши окружение",
                    "Что можно сделать дальше?",
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
                      "Вы"
                    ) : (
                      <>
                        <Mark size={15} /> Ada
                      </>
                    )}
                  </div>
                  <p>
                    {m.content.replace(
                      /\n\[Selected (scene )?entity\][\s\S]*/,
                      "",
                    )}
                  </p>
                </div>
              ))
            )}
            {s.running && (
              <div className="chat-message assistant">
                <div className="message-author">
                  <Mark size={15} /> Ada
                </div>
                <p>{s.streamText || "Обдумываю изменения…"}</p>
              </div>
            )}
            {s.activity.length > 0 && (
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
          {s.selected && (
            <div className="context-chip">
              <Icon name="cube" size={12} /> В контексте: {s.entity?.name}
              <button
                aria-label="Убрать выделение"
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
    editor_scene_get: "Изучаю сцену",
    editor_file_write: "Обновляю код",
    editor_scene_set: "Настраиваю объект",
    editor_build: "Проверяю в AdaPlayer",
    editor_play_start: "Запускаю игру",
    editor_play_capture: "Смотрю на результат",
  })[name] || "Работаю с проектом";
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
        aria-label="Сообщение ассистенту"
        placeholder={
          home
            ? "Опишите игру, которую мечтаете создать…"
            : "Что вы хотите создать или изменить?"
        }
        value={s.prompt}
        onChange={(e) => {
          s.prompt = e.target.value;
          s.emit();
        }}
        onKeyDown={(e) => {
          if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
            e.preventDefault();
            if (s.prompt.trim()) s.action(() => s.send(s.prompt));
          }
        }}
      />
      <div className="composer-footer">
        <Button
          type="button"
          icon="plus"
          label="Добавить ассет в контекст"
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
          <span>{s.model?.title || "Выбрать модель"}</span>
          <Icon name="down" size={11} />
        </button>
        <span className="composer-spacer" />
        {s.running ? (
          <Button
            type="button"
            icon="stop"
            label="Остановить ассистента"
            className="send"
            onClick={() => s.stopAgent()}
          />
        ) : (
          <Button
            type="submit"
            icon="arrow"
            label="Отправить сообщение"
            className="send"
            disabled={!s.prompt.trim() || !s.account}
          />
        )}
      </div>
      <input
        type="file"
        hidden
        ref={attach}
        accept=".png,.jpg,.jpeg,.wav,.ogg,.glb"
        onChange={(e) => {
          const f = e.target.files[0];
          if (f)
            s.action(async () => {
              const path = await s.uploadAsset(f);
              s.prompt += (s.prompt ? "\n" : "") + "Используй ассет " + path;
              s.emit();
            });
          e.target.value = "";
        }}
      />
    </form>
  );
}

export { Assistant, Composer };
