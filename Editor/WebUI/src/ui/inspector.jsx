import React from "react";
import { studio } from "./state.js";
import { useState, useEffect } from "react";
import { Icon, Mark, Button, act, entityIcon } from "./controls.jsx";

function Inspector() {
  const s = studio,
    e = s.entity;
  if (!e) return null;
  return (
    <section className="panel inspector-panel">
      <div className="panel-heading">
        <h2>
          <Icon name={entityIcon(e)} size={15} />
          {e.name}
        </h2>
        <Button
          icon="close"
          label="Скрыть инспектор"
          onClick={() => {
            s.inspector = false;
            s.emit();
          }}
        />
      </div>
      <div className="inspector-content">
        <div className="object-actions">
          <Button
            icon="focus"
            label="Фокус на выбранном объекте"
            onClick={() => s.editorCommand({ action: "focus" })}
          >
            Фокус
          </Button>
          <Button
            icon="plus"
            label="Дублировать объект"
            onClick={act(() => s.duplicateEntity())}
          >
            Копия
          </Button>
        </div>
        <label className="field-label">
          Название
          <input
            value={e.name}
            onChange={(event) =>
              s.action(() =>
                s.editScene((value) => {
                  value.entities.find((x) => x.id === e.id).name =
                    event.target.value;
                }),
              )
            }
          />
        </label>
        {Object.entries(e.components).map(([component, fields]) => (
          <div className="component" key={component}>
            <h3>
              <Icon
                name={component.includes("Transform") ? "move" : entityIcon(e)}
                size={13}
              />
              {component.split(".").at(-1) === "Transform"
                ? "Трансформация"
                : component.split(".").at(-1)}
            </h3>
            {Object.entries(fields).map(([name, value]) => (
              <Property
                key={name}
                name={name}
                value={value}
                onChange={(v) => s.action(() => s.setField(component, name, v))}
              />
            ))}
          </div>
        ))}
        <button
          className="text-button danger"
          onClick={act(() => s.removeEntity())}
        >
          <Icon name="trash" size={14} /> Удалить объект
        </button>
        <small className="inspector-hint">
          Выделенный объект передаётся ассистенту как контекст.
        </small>
      </div>
    </section>
  );
}
const fieldLabels = {
  position: "Позиция",
  rotation: "Вращение",
  scale: "Масштаб",
  color: "Цвет",
  mesh: "Форма",
  size: "Размер",
  metallic: "Металличность",
  roughness: "Шероховатость",
  intensity: "Яркость",
  isActive: "Включена",
  projection: "Проекция",
  renderOrder: "Порядок",
  castShadows: "Отбрасывает тени",
  receiveShadows: "Принимает тени",
  source: "Файл",
  volume: "Громкость",
  loops: "Повтор",
  autoplay: "Автозапуск",
};
function Property({ name, value, onChange }) {
  const [draft, setDraft] = useState(JSON.stringify(value));
  useEffect(
    () => setDraft(typeof value === "string" ? value : JSON.stringify(value)),
    [JSON.stringify(value)],
  );
  if (Array.isArray(value) && value.every((n) => typeof n === "number"))
    return (
      <label className="field-label">
        {fieldLabels[name] || name}
        <div className="vector-input">
          {value.map((n, i) => (
            <div key={i}>
              <span className={"axis-" + i}>{["X", "Y", "Z", "W"][i]}</span>
              <input
                aria-label={`${fieldLabels[name] || name} ${["X", "Y", "Z", "W"][i]}`}
                type="number"
                step="0.1"
                value={Number(n.toFixed(4))}
                onChange={(e) => {
                  const next = [...value];
                  next[i] = Number(e.target.value);
                  onChange(next);
                }}
              />
            </div>
          ))}
        </div>
      </label>
    );
  if (value && typeof value === "object" && "red" in value) {
    const hex =
      "#" +
      ["red", "green", "blue"]
        .map((c) =>
          Math.round(Math.max(0, Math.min(1, value[c])) * 255)
            .toString(16)
            .padStart(2, "0"),
        )
        .join("");
    return (
      <label className="field-label color-field">
        {fieldLabels[name] || name}
        <span>
          <input
            type="color"
            aria-label={fieldLabels[name] || name}
            value={hex}
            onChange={(e) => {
              const v = e.target.value;
              onChange({
                ...value,
                red: parseInt(v.slice(1, 3), 16) / 255,
                green: parseInt(v.slice(3, 5), 16) / 255,
                blue: parseInt(v.slice(5, 7), 16) / 255,
              });
            }}
          />
          {hex.toUpperCase()}
        </span>
      </label>
    );
  }
  if (typeof value === "boolean")
    return (
      <label className="check-field">
        {fieldLabels[name] || name}
        <input
          type="checkbox"
          checked={value}
          onChange={(e) => onChange(e.target.checked)}
        />
      </label>
    );
  return (
    <label className="field-label">
      {fieldLabels[name] || name}
      <input
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={() => {
          try {
            onChange(typeof value === "string" ? draft : JSON.parse(draft));
          } catch {
            setDraft(JSON.stringify(value));
          }
        }}
        onKeyDown={(e) => {
          if (e.key === "Enter") e.target.blur();
        }}
      />
    </label>
  );
}

export { Inspector };
