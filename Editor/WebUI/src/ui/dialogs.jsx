import React from "react";
import { studio } from "./state.js";
import { useEffect } from "react";
import { Icon, Mark, Button, act, entityIcon } from "./controls.jsx";
import { t, languagePreference, setLanguage } from "../localization.js";

function Modal({ title, onClose, children }) {
  useEffect(() => {
    const listener = (e) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", listener);
    return () => window.removeEventListener("keydown", listener);
  }, []);
  return (
    <div
      className="modal-backdrop"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <section
        className="modal panel"
        role="dialog"
        aria-modal="true"
        aria-label={title}
      >
        <div className="panel-heading">
          <h2>{title}</h2>
          <Button icon="close" label="Закрыть окно" onClick={onClose} />
        </div>
        {children}
      </section>
    </div>
  );
}
function Settings() {
  const s = studio;
  return (
    <Modal
      title="Ваш ассистент"
      onClose={() => {
        s.settings = false;
        s.emit();
      }}
    >
      <div className="modal-body">
        <label className="field-label">
          {t("Assistant language")}
          <select
            aria-label={t("Assistant language")}
            value={languagePreference()}
            onChange={(e) => {
              setLanguage(e.target.value);
              s.emit();
            }}
          >
            <option value="system">{t("System language")}</option>
            <option value="en">English</option>
            <option value="ru">Русский</option>
          </select>
        </label>
        <p className="muted">Выберите, кто поможет вам создать игру.</p>
        <div className="segmented">
          <button
            disabled={s.running}
            className={s.billingMode === "ada" ? "active" : ""}
            onClick={() => {
              s.billingMode = "ada";
              s.emit();
            }}
          >
            Ada AI
          </button>
          <button
            disabled={s.running}
            className={s.billingMode === "byok" ? "active" : ""}
            onClick={() => {
              s.billingMode = "byok";
              s.emit();
            }}
          >
            Свой API-ключ
          </button>
        </div>
        <label className="field-label">
          Провайдер
          <select
            disabled={s.running}
            value={s.providerID}
            onChange={(e) => {
              s.providerID = e.target.value;
              s.modelID = s.models.find((m) => m.tools)?.id || "";
              s.emit();
            }}
          >
            {s.providers.map((p) => (
              <option key={p.id} value={p.id}>
                {p.title}
              </option>
            ))}
          </select>
        </label>
        <label className="field-label">
          Модель
          <select
            disabled={s.running}
            value={s.modelID}
            onChange={(e) => {
              s.modelID = e.target.value;
              s.emit();
            }}
          >
            {s.models.map((m) => (
              <option key={m.id} value={m.id} disabled={!m.tools}>
                {m.title}
                {!m.tools ? " — без инструментов" : ""}
              </option>
            ))}
          </select>
        </label>
        {s.billingMode === "byok" && (
          <>
            <label className="field-label">
              API-ключ
              <input
                type="password"
                disabled={s.running}
                autoComplete="off"
                value={s.apiKey}
                onChange={(e) => {
                  s.apiKey = e.target.value;
                  s.emit();
                }}
                placeholder="Ключ выбранного провайдера"
              />
            </label>
            <p className="fine-print">
              Ключ хранится только в памяти этой вкладки и не входит в проект.
            </p>
          </>
        )}
        <button
          className="button primary wide"
          onClick={() => {
            s.settings = false;
            s.emit();
          }}
        >
          Продолжить
        </button>
      </div>
    </Modal>
  );
}
function History() {
  const s = studio;
  return (
    <Modal
      title="История вашего мира"
      onClose={() => {
        s.history = false;
        s.emit();
      }}
    >
      <div className="modal-body">
        <p className="muted">
          Вернитесь к любой контрольной версии. Восстановление создаёт новую
          версию.
        </p>
        <button
          className="button primary wide"
          onClick={act(() => s.checkpoint())}
        >
          <Icon name="plus" size={16} />
          Сохранить контрольную версию
        </button>
        <div className="history-list">
          {s.checkpoints.map((c) => (
            <button key={c.revision} onClick={act(() => s.restore(c.revision))}>
              <Icon name="history" />
              <span>
                <strong>Версия {c.revision}</strong>
                <small>
                  {new Date(c.updatedAt * 1000).toLocaleString("ru-RU")}
                </small>
              </span>
              <Icon name="undo" size={15} />
            </button>
          ))}
        </div>
      </div>
    </Modal>
  );
}

function LeaveProject() {
  const s = studio;
  const stay = () => {
    if (s.leaving) return;
    s.leavePrompt = "";
    s.emit();
  };
  return (
    <Modal title="Не удалось сохранить проект в облаке" onClose={stay}>
      <div className="modal-body">
        <p>
          Ваш проект «{s.snapshot.title}» остаётся открыт. Можно повторить
          сохранение или сохранить изменения в этом браузере перед переходом к
          списку проектов.
        </p>
        <p className="muted">
          Локальная копия доступна только на этом устройстве. При следующем
          открытии проекта Studio восстановит её. ZIP можно скачать для
          отдельной резервной копии.
        </p>
        <p role="status">{s.leavePrompt}</p>
        <div className="leave-actions">
          <Button autoFocus disabled={s.leaving} onClick={stay}>
            Остаться в проекте
          </Button>
          <Button
            disabled={s.leaving}
            onClick={act(() => s.export())}
            icon="download"
          >
            Скачать ZIP
          </Button>
          <Button disabled={s.leaving} onClick={act(() => s.browseProjects())}>
            Повторить сохранение
          </Button>
          <Button
            disabled={s.leaving}
            className="primary"
            onClick={act(() => s.browseProjects(true))}
          >
            Сохранить локально и выйти
          </Button>
        </div>
      </div>
    </Modal>
  );
}

export { Settings, History, LeaveProject };
