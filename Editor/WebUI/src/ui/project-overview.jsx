import React from "react";
import { studio } from "./state.js";
import { Button, Icon, act } from "./controls.jsx";
import { t } from "../localization.js";

export function ProjectOverview() {
  const s = studio;
  const sections = [
    [
      "editor",
      "cube",
      t("Scene"),
      t(
        "{0} objects · camera, gizmos and inspector",
        s.scene?.entities.length ?? 0,
      ),
    ],
    [
      "assets",
      "image",
      t("Assets"),
      t(
        "{0} files · models, images and audio",
        s.snapshot.files.filter((f) => f.path.startsWith("Assets/")).length,
      ),
    ],
    [
      "code",
      "code",
      t("Code"),
      t("{0} AdaScript files · your game’s behavior", s.sources.length),
    ],
    [
      "assistant",
      "spark",
      t("Assistant"),
      t("Chat, project context and agent changes"),
    ],
  ];
  return (
    <section className="project-overview" aria-label={t("Project overview")}>
      <div className="overview-heading">
        <div>
          <span className="eyebrow">{t("YOUR PROJECT")}</span>
          <h1>{s.snapshot.title}</h1>
          <p>
            {t(
              "Scene, assets, code and chat are parts of one game. Switch between them on the left.",
            )}
          </p>
        </div>
        <Button className="primary" icon="play" onClick={act(() => s.play())}>
          {t("Play")}
        </Button>
      </div>
      <div className="project-storage">
        <Icon name="cloud" size={22} />
        <div>
          <strong>
            {s.status === "saved"
              ? t("Project saved in Ada Cloud")
              : s.status === "saving"
                ? t("Saving changes…")
                : t("Changes have not been saved to Cloud yet")}
          </strong>
          <p>
            {t(
              "Private project · revision {0}. Autosave works in every section.",
              s.workspace.revision,
            )}
          </p>
        </div>
        <Button icon="check" onClick={act(() => s.save())}>
          {t("Save now")}
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
          <h2>{t("Continue where you left off")}</h2>
          <p>
            {t(
              "Find your project in All projects. ZIP includes sources and assets so you can reopen it.",
            )}
          </p>
        </div>
        <Button icon="history" onClick={act(() => s.showHistory())}>
          {t("Version history")}
        </Button>
        <Button icon="download" onClick={act(() => s.export())}>
          {t("Download ZIP")}
        </Button>
      </div>
    </section>
  );
}
