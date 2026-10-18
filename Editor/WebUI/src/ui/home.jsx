import React from "react";
import { studio } from "./state.js";
import { useRef } from "react";
import { Icon, Mark, Button, act, entityIcon } from "./controls.jsx";
import { Composer } from "./assistant.jsx";

function Home() {
  const s = studio,
    input = useRef();
  return (
    <main className="home">
      <div className="home-top">
        <span className="eyebrow">ADA STUDIO</span>
        <span className="home-version">Ваши идеи. Ваши миры.</span>
      </div>
      {s.document && (
        <section className="resume-project">
          <div>
            <span className="eyebrow">ОТКРЫТЫЙ ПРОЕКТ</span>
            <h2>{s.snapshot.title}</h2>
            <p>Вернитесь к работе: сцена, код и история изменений на месте.</p>
          </div>
          <Button
            className="primary"
            icon="chevron"
            onClick={() => s.navigate(s.view)}
          >
            Продолжить работу
          </Button>
        </section>
      )}
      {!s.document && (
        <section className="home-hero">
          <div className="hero-orbit" aria-hidden="true">
            <i />
            <i />
            <i />
            <Mark />
          </div>
          <span className="eyebrow">МЕСТО, ГДЕ НАЧИНАЮТСЯ ИГРЫ</span>
          <h1>
            Что создадим
            <br />
            <em>сегодня?</em>
          </h1>
          <p>
            Начните с идеи. Остальное создавайте
            <br />
            вместе с вашим ассистентом.
          </p>
          <Composer home />
        </section>
      )}
      {s.status === "signedout" ? (
        <button
          className="button primary"
          onClick={() => {
            location.href = "/cloud";
          }}
        >
          Войти в Ada Cloud
        </button>
      ) : (
        <>
          <div className="section-heading">
            <h2>Начать с чистого листа</h2>
            <button
              className="text-button"
              onClick={() => input.current.click()}
            >
              <Icon name="upload" size={15} /> Загрузить проект
            </button>
          </div>
          <div className="template-grid">
            <button
              className="template-card landscape"
              onClick={act(() => s.create(3))}
            >
              <div className="template-art">
                <div className="hill h1" />
                <div className="hill h2" />
                <div className="hill h3" />
                <div className="little-tree t1" />
                <div className="little-tree t2" />
                <div className="little-tree t3" />
                <div className="temple">
                  <i />
                  <i />
                  <i />
                </div>
              </div>
              <div>
                <span>
                  <Icon name="cube" />
                  3D-мир
                </span>
                <small>Свет, пространство и новые приключения</small>
                <Icon name="plus" />
              </div>
            </button>
            <button
              className="template-card twod"
              onClick={act(() => s.create(2))}
            >
              <div className="template-art">
                <div className="platform p1" />
                <div className="platform p2" />
                <div className="platform p3" />
                <div className="pixel-player" />
                <i className="star s1">✦</i>
                <i className="star s2">✦</i>
                <i className="star s3">✦</i>
              </div>
              <div>
                <span>
                  <Icon name="image" />
                  2D-игра
                </span>
                <small>Простая идея может стать большой игрой</small>
                <Icon name="plus" />
              </div>
            </button>
          </div>
          <div className="section-heading">
            <h2>
              Недавние проекты <span>{s.projects.length || ""}</span>
            </h2>
            <button className="text-button" onClick={act(() => s.refresh())}>
              Обновить
            </button>
          </div>
          {s.projects.length ? (
            <div className="project-list">
              {s.projects.map((p, i) => (
                <button key={p.id} onClick={act(() => s.open(p))}>
                  <div className={`project-icon shade-${i % 3}`}>
                    <Icon name="cube" size={24} />
                  </div>
                  <div>
                    <strong>
                      {p.title}
                      {p.id === s.workspace?.id ? " · открыт" : ""}
                    </strong>
                    <small>
                      {new Date(p.updatedAt * 1000).toLocaleDateString(
                        "ru-RU",
                        { day: "numeric", month: "long" },
                      )}{" "}
                      · Версия {p.revision}
                    </small>
                  </div>
                  <Icon name="chevron" />
                </button>
              ))}
            </div>
          ) : (
            <div className="empty-projects">
              <Icon name="folder" />
              <p>Здесь появятся ваши миры</p>
              <span>Создайте первый проект или загрузите свой.</span>
            </div>
          )}
        </>
      )}
      <input
        ref={input}
        type="file"
        accept=".zip"
        hidden
        onChange={(e) => {
          if (e.target.files[0])
            s.action(() => s.importFile(e.target.files[0]));
          e.target.value = "";
        }}
      />
      <footer className="home-footer">
        <span>
          <i /> Всё, что вы создаёте, принадлежит вам
        </span>
        <span>Рабочие проекты сохраняются приватно</span>
      </footer>
    </main>
  );
}

export { Home };
