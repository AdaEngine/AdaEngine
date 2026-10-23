import React from "react";
import { studio } from "./state.js";
import { useRef, useState } from "react";
import { Icon, Button, act } from "./controls.jsx";
import { t, languagePreference, resolveLanguage } from "../localization.js";
import { Composer } from "./assistant.jsx";
import "../library-home.css";
import {
  LibraryAction,
  LibraryFeatures,
  LibraryHero,
} from "./library-welcome.jsx";

function Home({ section = "create" }) {
  const s = studio,
    input = useRef();
  const [retrying, setRetrying] = useState(false);
  const pending = retrying || s.status === "loading";
  const signedIn = !!s.account && s.status !== "signedout";
  const unavailable = !pending && s.status === "offline" && !s.projects.length;
  const unavailableDescription =
    s.config.enabled === false
      ? t("Browser Studio is not enabled on this server.")
      : t(
          "We could not load your workspace. Check your connection and try again.",
        );
  const canCreate =
    signedIn && s.config.enabled === true && !pending && !unavailable;
  const explore = act(() => s.browseLibrary("games"));
  const create = act(() => s.browseLibrary("create"));
  const retry = async () => {
    setRetrying(true);
    try {
      await s.start();
    } finally {
      setRetrying(false);
    }
  };
  const signIn = (
    <LibraryAction
      href={`/account?continue=${encodeURIComponent(section === "create" ? "/create" : "/projects")}`}
    >
      {t("Sign in to Ada Cloud")}
    </LibraryAction>
  );
  const upload = () => input.current.click();
  return (
    <main className={`home library-home ${section}`}>
      <div className="library-home-content">
        {section === "projects" && signedIn && (
          <LibraryAction secondary href="/publications">
            {t("Publishing")}
          </LibraryAction>
        )}
        {s.document && (
          <section className="resume-project">
            <div>
              <span className="eyebrow">{t("OPEN PROJECT")}</span>
              <h2>{s.snapshot.title}</h2>
              <p>
                {t(
                  "Your scene, code and edit history are right where you left them.",
                )}
              </p>
            </div>
            <Button
              className="primary"
              icon="chevron"
              onClick={() => s.navigate(s.view)}
            >
              {t("Continue working")}
            </Button>
          </section>
        )}
        {section === "create" && (
          <>
            <LibraryHero
              eyebrow={t("WHERE GAMES BEGIN")}
              title={t("What will you create today?")}
              description={t(
                "Start with an idea. Build the rest together with your assistant.",
              )}
            >
              {pending ? (
                <p className="library-state-note" role="status">
                  {t("Loading your workspace…")}
                </p>
              ) : !signedIn && !unavailable ? (
                <>
                  <div className="library-actions">
                    {signIn}
                    <LibraryAction secondary onClick={explore} icon="play">
                      {t("Explore games")}
                    </LibraryAction>
                  </div>
                  <p className="library-state-note">
                    {t("Sign in to create and save your own worlds.")}
                  </p>
                </>
              ) : unavailable ? (
                <div className="library-actions">
                  <LibraryAction onClick={retry}>
                    {t("Try again")}
                  </LibraryAction>
                  <LibraryAction secondary onClick={explore}>
                    {t("Explore games")}
                  </LibraryAction>
                </div>
              ) : null}
            </LibraryHero>
            {unavailable && (
              <p className="library-availability" role="status">
                {s.config.enabled === false
                  ? t("Browser Studio is not enabled on this server.")
                  : t(
                      "We could not load your workspace. Check your connection and try again.",
                    )}
              </p>
            )}
            {canCreate && !pending && (
              <div className="library-create-composer">
                <Composer home />
              </div>
            )}
            {!signedIn && !pending && !unavailable && <LibraryFeatures />}
          </>
        )}
        {section === "projects" &&
          (pending || !signedIn || !s.projects.length) && (
            <>
              <LibraryHero
                projects
                eyebrow={t("My projects")}
                title={
                  pending
                    ? t("Your workspace is on its way")
                    : unavailable
                      ? t("Let’s get you back to your worlds")
                      : signedIn
                        ? t("Your first world starts here")
                        : t("A home for your worlds")
                }
                description={
                  pending
                    ? t("Loading your projects…")
                    : unavailable
                      ? unavailableDescription
                      : signedIn
                        ? t(
                            "Start a new 2D or 3D game, or bring a project you have already started.",
                          )
                        : t(
                            "Sign in to keep your projects together, save your progress and continue creating whenever inspiration strikes.",
                          )
                }
              >
                {pending ? (
                  <p className="library-state-note" role="status">
                    {t("Loading your workspace…")}
                  </p>
                ) : unavailable ? (
                  <div className="library-actions">
                    <LibraryAction onClick={retry}>
                      {t("Try again")}
                    </LibraryAction>
                    <LibraryAction secondary onClick={explore} icon="play">
                      {t("Explore games")}
                    </LibraryAction>
                  </div>
                ) : !signedIn ? (
                  <>
                    <div className="library-actions">
                      {signIn}
                      <LibraryAction secondary onClick={explore} icon="play">
                        {t("Explore games")}
                      </LibraryAction>
                    </div>
                    <p className="library-state-note">
                      <Icon name="cloud" size={14} />
                      {t("Your working projects are private")}
                    </p>
                  </>
                ) : (
                  <div className="library-actions">
                    <LibraryAction
                      onClick={create}
                      disabled={!canCreate}
                      icon="plus"
                    >
                      {t("Create your first world")}
                    </LibraryAction>
                    <LibraryAction
                      secondary
                      onClick={upload}
                      disabled={!canCreate}
                      icon="upload"
                    >
                      {t("Upload project")}
                    </LibraryAction>
                  </div>
                )}
              </LibraryHero>
              {!pending && !unavailable && <LibraryFeatures />}
            </>
          )}
        {signedIn && !pending && !unavailable && (
          <>
            {section === "create" && (
              <>
                {!s.config.enabled && (
                  <p className="library-availability" role="status">
                    {s.status === "loading"
                      ? t("Loading Studio…")
                      : t("Browser Studio is not enabled on this server.")}
                  </p>
                )}
                <div className="section-heading">
                  <h2>{t("Start from scratch")}</h2>
                  <button
                    className="text-button"
                    disabled={!s.config.enabled}
                    onClick={() => input.current.click()}
                  >
                    <Icon name="upload" size={15} /> {t("Upload project")}
                  </button>
                </div>
                <div className="template-grid">
                  <button
                    className="template-card landscape"
                    disabled={!s.config.enabled}
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
                        {t("3D world")}
                      </span>
                      <small>{t("Light, space and new adventures")}</small>
                      <Icon name="plus" />
                    </div>
                  </button>
                  <button
                    className="template-card twod"
                    disabled={!s.config.enabled}
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
                        {t("2D game")}
                      </span>
                      <small>
                        {t("A simple idea can become a great game")}
                      </small>
                      <Icon name="plus" />
                    </div>
                  </button>
                </div>
              </>
            )}
            {section === "projects" && s.projects.length > 0 && (
              <>
                <div className="library-projects-heading">
                  <div>
                    <p className="eyebrow">{t("Your workspace")}</p>
                    <h1>{t("My projects")}</h1>
                    <p>
                      {t("Pick up where you left off, or start a new world.")}
                    </p>
                  </div>
                  <div className="library-actions">
                    <LibraryAction
                      onClick={create}
                      disabled={!canCreate}
                      icon="plus"
                    >
                      {t("Create a game")}
                    </LibraryAction>
                    <LibraryAction
                      secondary
                      onClick={upload}
                      disabled={!canCreate}
                      icon="upload"
                    >
                      {t("Upload project")}
                    </LibraryAction>
                  </div>
                </div>
                <div className="section-heading">
                  <h2>
                    {t("Recent projects")} <span>{s.projects.length}</span>
                  </h2>
                  <button
                    className="text-button"
                    onClick={act(() => s.refresh())}
                  >
                    {t("Refresh")}
                  </button>
                </div>
                <div className="project-list">
                  {s.projects.map((p, i) => (
                    <button key={p.id} onClick={act(() => s.open(p))}>
                      <div className={`project-icon shade-${i % 3}`}>
                        <Icon name="cube" size={24} />
                      </div>
                      <div>
                        <strong>
                          {p.title}
                          {p.id === s.workspace?.id ? t(" · open") : ""}
                        </strong>
                        <small>
                          {new Date(p.updatedAt * 1000).toLocaleDateString(
                            resolveLanguage(
                              languagePreference(),
                              navigator.languages,
                            ),
                            { day: "numeric", month: "long" },
                          )}{" "}
                          · {t("Version {0}", p.revision)}
                        </small>
                      </div>
                      <Icon name="chevron" />
                    </button>
                  ))}
                </div>
              </>
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
            <i /> {t("Everything you create belongs to you")}
          </span>
          <span>{t("Your working projects are private")}</span>
        </footer>
      </div>
    </main>
  );
}

export { Home };
