import React from "react";
import { studio } from "./state.js";
import { Button, Icon, act } from "./controls.jsx";

export function ProjectOverview() {
  const s = studio;
  const sections = [
    [
      "editor",
      "cube",
      "Сцена",
      `Объектов: ${s.scene?.entities.length ?? 0} · камера, гизмо и инспектор`,
    ],
    [
      "assets",
      "image",
      "Ассеты",
      `Файлов: ${s.snapshot.files.filter((f) => f.path.startsWith("Assets/")).length} · модели, изображения и звук`,
    ],
    [
      "code",
      "code",
      "Код",
      `Файлов AdaScript: ${s.sources.length} · поведение вашей игры`,
    ],
    [
      "assistant",
      "spark",
      "Ассистент",
      "Чат, контекст проекта и изменения агента",
    ],
  ];
  return (
    <section className="project-overview" aria-label="Обзор проекта">
      <div className="overview-heading">
        <div>
          <span className="eyebrow">ВАШ ПРОЕКТ</span>
          <h1>{s.snapshot.title}</h1>
          <p>
            Сцена, ассеты, код и чат — части одной игры. Переключайтесь между
            ними слева.
          </p>
        </div>
        <Button className="primary" icon="play" onClick={act(() => s.play())}>
          Играть
        </Button>
      </div>
      <div className="project-storage">
        <Icon name="cloud" size={22} />
        <div>
          <strong>
            {s.status === "saved"
              ? "Проект сохранён в Ada Cloud"
              : s.status === "saving"
                ? "Сохраняем изменения…"
                : "Изменения ещё не сохранены в облаке"}
          </strong>
          <p>
            Приватный проект · ревизия {s.workspace.revision}. Автосохранение
            работает во всех разделах.
          </p>
        </div>
        <Button icon="check" onClick={act(() => s.save())}>
          Сохранить сейчас
        </Button>
      </div>
      <div className="project-sections">
        {sections.map(([view, icon, title, description]) => (
          <button key={view} onClick={() => s.navigate(view)}>
            <Icon name={icon} size={25} />
            <h2>{title}</h2>
            <p>{description}</p>
            <Icon name="chevron" size={16} />
          </button>
        ))}
      </div>
      <div className="overview-bottom">
        <div>
          <h2>Продолжайте с того же места</h2>
          <p>
            Проект доступен в списке «Все проекты». ZIP содержит исходники и
            ассеты для повторного открытия.
          </p>
        </div>
        <Button icon="history" onClick={act(() => s.showHistory())}>
          История версий
        </Button>
        <Button icon="download" onClick={act(() => s.export())}>
          Скачать ZIP
        </Button>
      </div>
    </section>
  );
}
