import React, { useEffect, useRef, useState } from "react";
import { studio } from "./state.js";
import { Icon, act } from "./controls.jsx";
import { t } from "../localization.js";
import { json } from "../platform.js";
import { filterGames, gameLaunchURL } from "../playground.js";
import tagArtwork from "../playground-tag-art.json";

export function LibraryRail() {
  const s = studio;
  const activeView = ({ publications: "projects", legal: "account" })[s.libraryView] || s.libraryView;
  return (
    <>
      <nav
        className="library-navigation"
        aria-label={t("Playground navigation")}
      >
        {[
          ["games", "play", t("Games")],
          ["create", "spark", t("Create")],
          ["projects", "folder", t("My projects")],
        ].map(([view, icon, label]) => (
          <button
            key={view}
            className={`library-nav-item ${activeView === view ? "active" : ""}`}
            aria-current={activeView === view ? "page" : undefined}
            disabled={s.leaving}
            onClick={act(() => s.browseLibrary(view))}
          >
            <Icon name={icon} size={21} />
            <span>{label}</span>
          </button>
        ))}
      </nav>
      <div className="rail-bottom library-bottom">
        <button
          className="library-nav-item"
          onClick={() => {
            s.settings = true;
            s.emit();
          }}
        >
          <Icon name="settings" />
          <span>{t("Settings")}</span>
        </button>
        <a
          className={`library-nav-item ${activeView === "account" ? "active" : ""}`}
          aria-current={activeView === "account" ? "page" : undefined}
          href="/account"
        >
          <svg
            width="21"
            height="21"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.65"
            aria-hidden="true"
          >
            <path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM4 21v-2a8 8 0 0 1 16 0v2" />
          </svg>
          <span>{t("Account")}</span>
        </a>
      </div>
    </>
  );
}
function TagArt({ theme }) {
  const key = theme.trim().toLowerCase().replace(/[ _]+/g, "-");
  const art =
    tagArtwork[key === "singleplayer" ? "single-player" : key] ||
    tagArtwork.all;
  function sprite(rect, size, cls) {
    const scale = size / Math.max(rect.width, rect.height);
    return (
      <span
        className={`playground-tag-sprite ${cls}`}
        style={{
          width: rect.width * scale,
          height: rect.height * scale,
          backgroundImage: `url("${art.file}")`,
          backgroundSize: `${art.width * scale}px ${art.height * scale}px`,
          backgroundPosition: `${-rect.x * scale}px ${-rect.y * scale}px`,
        }}
      />
    );
  }
  return (
    <span className="playground-tag-art" aria-hidden="true">
      {art.props.map((r, i) => (
        <React.Fragment key={i}>
          {sprite(r, 24, `playground-tag-prop playground-tag-prop-${i + 1}`)}
        </React.Fragment>
      ))}
      {sprite(art.core, 42, "playground-tag-core")}
    </span>
  );
}
function Art({ game, hero = false }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [game.cover]);
  return (
    <div
      className={`playground-art ${hero ? "playground-art-hero" : ""} ${!game.cover || failed ? "playground-art-missing" : ""}`}
    >
      {game.cover && !failed && (
        <img
          src={`/v1/media/${encodeURIComponent(game.cover)}`}
          alt=""
          loading={hero ? "eager" : "lazy"}
          onError={() => setFailed(true)}
        />
      )}
      <span className="playground-monogram" aria-hidden="true">
        {game.title.slice(0, 1)}
      </span>
    </div>
  );
}
const author = (game) =>
  game.authorName || t("Creator {0}", String(game.owner || "").slice(0, 8));
function Meta({ game }) {
  return (
    <div className="playground-meta">
      <span>{author(game)}</span>
      <span className="playground-platform">
        {game.publication?.runtime?.kind === "adascript"
          ? "Ada Studio"
          : t("Browser")}
      </span>
    </div>
  );
}
function Arrow() {
  return (
    <svg
      className="playground-action-icon playground-action-icon-external"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M7 17 17 7M7 7h10v10" />
    </svg>
  );
}
function Play({ game }) {
  const href = gameLaunchURL(game);
  return href ? (
    <a
      className="playground-button playground-button-primary playground-link-with-icon"
      href={href}
      target="_blank"
      rel="noopener noreferrer"
    >
      {game.publication?.runtime?.kind === "adascript"
        ? t("Open in Ada Studio")
        : t("Play now")}
      <Arrow />
    </a>
  ) : (
    <p className="playground-unavailable">
      {t("This release is no longer available.")}
    </p>
  );
}
function Hero({ game, detail, onDetails }) {
  return (
    <section className="playground-feature">
      <Art game={game} hero />
      <div className="playground-feature-copy">
        <p className="playground-eyebrow">
          {detail
            ? t("A GAME BY THE COMMUNITY")
            : t("DISCOVER SOMETHING DIFFERENT")}
        </p>
        {detail ? <h1>{game.title}</h1> : <h2>{game.title}</h2>}
        <Meta game={game} />
        <p className="playground-feature-description">
          {game.description || t("A new world, made with Ada.")}
        </p>
        <div className="playground-actions">
          <Play game={game} />
          {!detail && (
            <button
              className="playground-button playground-button-secondary"
              onClick={onDetails}
            >
              {t("About this game")}
            </button>
          )}
        </div>
      </div>
    </section>
  );
}
function Likes({ game }) {
  return (
    <span className="playground-card-likes">
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z" />
      </svg>
      <strong>{Math.max(0, game.likes || 0)}</strong>
      <span>{t("likes")}</span>
    </span>
  );
}
export function GameCard({ game, onOpen }) {
  return (
    <article className="playground-card">
      <button className="playground-card-link" onClick={onOpen}>
        <Art game={game} />
        <Likes game={game} />
        <div className="playground-card-copy">
          <h3>{game.title}</h3>
          <p className="playground-card-description">
            {game.description || t("Explore a game made with Ada.")}
          </p>
          <Meta game={game} />
          <div className="playground-card-footer">
            {(game.tags || []).slice(0, 2).join(" / ")}
          </div>
        </div>
      </button>
    </article>
  );
}
export function Games({ selectedId = null }) {
  const [pages, setPages] = useState(null),
    [failure, setFailure] = useState(false),
    [retry, setRetry] = useState(0);
  const [query, setQuery] = useState(""),
    [filter, setFilter] = useState("all"),
    [sort, setSort] = useState("catalog");
  const selected = selectedId;
  const setSelected = id => studio.router.navigate(id ? `/games/${encodeURIComponent(id)}` : "/games");
  const [detail, setDetail] = useState(null),
    [detailError, setDetailError] = useState(false),
    [detailRetry, setDetailRetry] = useState(0),
    [busy, setBusy] = useState(false),
    [socialError, setSocialError] = useState(false);
  const filters = useRef();
  useEffect(() => {
    const controller = new AbortController();
    setFailure(false);
    setPages(null);
    json("/v1/catalog", undefined, undefined, controller.signal)
      .then((value) => {
        if (!Array.isArray(value)) throw new Error();
        setPages(value);
      })
      .catch((e) => {
        if (e.name !== "AbortError") setFailure(true);
      });
    return () => controller.abort();
  }, [retry]);
  useEffect(() => {
    if (!selected) return;
    const controller = new AbortController();
    setDetail(null);
    setDetailError(false);
    setSocialError(false);
    json(
      `/v1/catalog/${encodeURIComponent(selected)}`,
      undefined,
      undefined,
      controller.signal,
    )
      .then(setDetail)
      .catch((e) => {
        if (e.name !== "AbortError") setDetailError(true);
      });
    return () => controller.abort();
  }, [selected, detailRetry]);
  async function like(liked) {
    setBusy(true);
    setSocialError(false);
    try {
      const result = await json(
        `/v1/catalog/${encodeURIComponent(detail.id)}/like`,
        { liked },
        "PUT",
      );
      setDetail((g) => ({ ...g, likes: result.likes }));
      setPages((p) =>
        p.map((g) => (g.id === detail.id ? { ...g, likes: result.likes } : g)),
      );
    } catch {
      setSocialError(true);
    } finally {
      setBusy(false);
    }
  }
  const open = (id) => {
    setSelected(id);
  };
  const featured = pages?.find((g) => gameLaunchURL(g));
  const games = filterGames(pages || [], filter, query, sort);
  const tags = new Map();
  for (const game of pages || [])
    for (const tag of game.tags || []) {
      const key = tag.trim().toLocaleLowerCase();
      if (key && !tags.has(key)) tags.set(key, tag.trim());
    }
  const choices = [
    ["all", t("All games")],
    ["browser", t("In your browser")],
    ["studio", t("In Ada Studio")],
    ...Array.from(tags, ([key, label]) => ["tag:" + key, label]),
  ];
  const create = act(() => studio.browseLibrary("create"));
  return (
    <main className="playground-main" tabIndex="-1">
      {selected ? (
        <>
          <button
            className="playground-back"
            onClick={() => {
              setSelected(null);
              setDetail(null);
            }}
          >
            <Icon name="chevron" />
            {t("All games")}
          </button>
          {detailError ? (
            <section className="playground-empty" role="alert">
              <h2>{t("This game is unavailable.")}</h2>
              <button
                className="playground-button playground-button-secondary"
                onClick={() => setDetailRetry((n) => n + 1)}
              >
                {t("Try again")}
              </button>
            </section>
          ) : !detail ? (
            <p role="status">{t("Loading game…")}</p>
          ) : (
            <>
              <Hero game={detail} detail />
              <section className="playground-about">
                <h2>{t("About this game")}</h2>
                <p>
                  {detail.description ||
                    t("The creator has not added a description yet.")}
                </p>
                <div className="playground-tags">
                  {detail.tags?.map((tag) => (
                    <span key={tag}>{tag}</span>
                  ))}
                </div>
                <div className="playground-actions">
                  {studio.account ? (
                    <>
                      <button
                        className="playground-button playground-button-secondary"
                        disabled={busy}
                        onClick={() => like(true)}
                      >
                        {t("Like")}
                      </button>
                      <button
                        className="playground-button playground-button-secondary"
                        disabled={busy}
                        onClick={() => like(false)}
                      >
                        {t("Remove like")}
                      </button>
                    </>
                  ) : (
                    <a
                      className="playground-button playground-button-secondary"
                      href={`/account?continue=${encodeURIComponent(`/games/${detail.id}`)}`}
                    >
                      {t("Sign in to like")}
                    </a>
                  )}
                  <p role="status">{t("{0} likes", detail.likes || 0)}</p>
                </div>
                <form onSubmit={async event => {
                  event.preventDefault();
                  const form = event.currentTarget, reason = form.elements.reason.value.trim();
                  if (!reason) return;
                  setBusy(true);
                  try { await json(`/v1/catalog/${encodeURIComponent(detail.id)}/report`, { reason }); form.reset(); setSocialError(false); form.querySelector('[role="status"]').textContent = t("Report sent"); }
                  catch { setSocialError(true); }
                  finally { setBusy(false); }
                }}>
                  <label>{t("Report this game")}<textarea name="reason" required maxLength={2000} /></label>
                  <button className="playground-button playground-button-secondary" disabled={busy}>{t("Send report")}</button>
                  <p role="status" />
                </form>
                {socialError && (
                  <p role="alert">
                    {t("Could not update your like. Try again.")}
                  </p>
                )}
              </section>
              {!!detail.screenshots?.length && (
                <section className="playground-screenshots">
                  <h2>{t("Inside the game")}</h2>
                  <div className="playground-screenshot-grid">
                    {detail.screenshots.map((id, i) => (
                      <img
                        key={id}
                        src={`/v1/media/${encodeURIComponent(id)}`}
                        loading="lazy"
                        alt={t(
                          "{0} — gameplay screenshot {1}",
                          detail.title,
                          i + 1,
                        )}
                      />
                    ))}
                  </div>
                </section>
              )}
            </>
          )}
        </>
      ) : (
        <>
          <header className="playground-intro playground-catalog-intro playground-illustrated-intro">
            <span className="playground-intro-art" aria-hidden="true">
              <img
                src="./playground/hero-robots-v1.png"
                alt=""
                width="2172"
                height="724"
                fetchPriority="high"
                decoding="async"
              />
            </span>
            <div>
              <p className="playground-eyebrow">
                {t("YOUR NEXT LITTLE ADVENTURE")}
              </p>
              <h1>{t("What will you play today?")}</h1>
              <p>
                {t(
                  "Explore what people are making. Make something of your own.",
                )}
              </p>
            </div>
            <button
              className="playground-button playground-button-secondary playground-link-with-icon"
              onClick={create}
            >
              {t("Create a game")}
              <Arrow />
            </button>
          </header>
          {failure ? (
            <section className="playground-empty" role="alert">
              <h2>{t("The game catalog is temporarily unavailable.")}</h2>
              <button
                className="playground-button playground-button-secondary"
                onClick={() => setRetry((n) => n + 1)}
              >
                {t("Try again")}
              </button>
            </section>
          ) : pages === null ? (
            <p role="status">{t("Loading games…")}</p>
          ) : (
            <>
              {featured && (
                <Hero game={featured} onDetails={() => open(featured.id)} />
              )}
              <section className="playground-discovery">
                <div className="playground-section-heading">
                  <h2>{t("Find your next game")}</h2>
                  <p
                    className="playground-count"
                    role="status"
                    aria-live="polite"
                  >
                    {t("{0} games", games.length)}
                  </p>
                </div>
                <div className="playground-tools">
                  <label className="playground-search">
                    {t("Search games")}
                    <input
                      type="search"
                      placeholder={t("Search titles, creators, or tags")}
                      value={query}
                      onChange={(e) => setQuery(e.target.value)}
                    />
                  </label>
                  <label className="playground-sort">
                    {t("Sort by")}
                    <span className="playground-select-control">
                      <select
                        value={sort}
                        onChange={(e) => setSort(e.target.value)}
                      >
                        <option value="catalog">{t("Catalog order")}</option>
                        <option value="likes">{t("Most liked")}</option>
                        <option value="title">{t("Title A–Z")}</option>
                      </select>
                      <span className="playground-action-icon">
                        <Icon name="down" />
                      </span>
                    </span>
                  </label>
                </div>
                <div className="playground-tag-carousel">
                  {[-1, 1].map((direction, i) => (
                    <React.Fragment key={direction}>
                      {i === 1 && (
                        <div
                          className="playground-filters"
                          ref={filters}
                          role="group"
                          aria-label={t("Filter games by platform or tag")}
                          tabIndex="0"
                        >
                          {choices.map(([key, label]) => (
                            <button
                              key={key}
                              aria-pressed={filter === key}
                              onClick={() => setFilter(key)}
                            >
                              <span className="playground-tag-icon">
                                <TagArt theme={key.replace(/^tag:/, "")} />
                              </span>
                              <span className="playground-tag-label">
                                {label}
                              </span>
                            </button>
                          ))}
                        </div>
                      )}
                      <button
                        className="playground-tag-scroll"
                        aria-label={
                          direction < 0
                            ? t("Scroll tags left")
                            : t("Scroll tags right")
                        }
                        onClick={() =>
                          filters.current.scrollBy({
                            left:
                              direction *
                              Math.max(180, filters.current.clientWidth * 0.7),
                            behavior: window.matchMedia(
                              "(prefers-reduced-motion: reduce)",
                            ).matches
                              ? "auto"
                              : "smooth",
                          })
                        }
                      >
                        <span
                          style={{
                            transform:
                              direction < 0 ? "rotate(180deg)" : undefined,
                          }}
                        >
                          <Icon name="chevron" />
                        </span>
                      </button>
                    </React.Fragment>
                  ))}
                </div>
                <div className="playground-game-grid">
                  {games.map((game) => (
                    <GameCard
                      key={game.id}
                      game={game}
                      onOpen={() => open(game.id)}
                    />
                  ))}
                  {!games.length && (
                    <div className="playground-empty">
                      <h3>
                        {pages.length
                          ? t("No games match your search.")
                          : t("The next world could be yours.")}
                      </h3>
                      <p>
                        {pages.length
                          ? t("Try another title or tag.")
                          : t(
                              "Published games will appear here. Create the first one.",
                            )}
                      </p>
                      {!!pages.length && (
                        <button
                          className="playground-button playground-button-secondary"
                          onClick={() => {
                            setQuery("");
                            setFilter("all");
                          }}
                        >
                          {t("Clear filters")}
                        </button>
                      )}
                    </div>
                  )}
                </div>
              </section>
            </>
          )}
          <section className="playground-create-strip">
            <div>
              <p className="playground-eyebrow">
                {t("FROM PLAYER TO CREATOR")}
              </p>
              <h2>{t("Your idea belongs here.")}</h2>
            </div>
            <button
              className="playground-button playground-button-primary playground-link-with-icon"
              onClick={create}
            >
              {t("Make your first game")}
              <Arrow />
            </button>
          </section>
        </>
      )}
    </main>
  );
}
