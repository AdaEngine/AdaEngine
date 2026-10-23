// Public catalog data stays separate from private Studio workspace snapshots.
export function publicationAvailable(publication, now = Date.now()) {
  if (!publication || publication.revoked) return false;
  if (publication.mode === "ugc")
    return (
      publication.approved === true &&
      publication.expiresAt === null &&
      !!publication.releaseId
    );
  return (
    typeof publication.expiresAt === "number" &&
    publication.expiresAt * 1000 > now
  );
}
export function gameLaunchURL(game) {
  const p = game.publication;
  if (
    !publicationAvailable(p) ||
    typeof p.url !== "string" ||
    !/^https?:\/\//i.test(p.url)
  )
    return null;
  if (p.runtime?.kind !== "adascript") return p.url;
  return (
    "adaeditor://community/preview?" +
    new URLSearchParams({
      url: p.url,
      game: p.pageId || game.id,
      release: p.uploadId || p.releaseId || "",
      api: String(p.runtime.apiVersion ?? 1),
      title: game.title,
    })
  );
}
export function filterGames(pages, filter, query, sort) {
  const normalized = query.trim().toLocaleLowerCase();
  return pages
    .filter(
      (g) =>
        (filter === "all" ||
          (filter === "studio" &&
            g.publication?.runtime?.kind === "adascript") ||
          (filter === "browser" &&
            g.publication?.runtime?.kind !== "adascript") ||
          (filter.startsWith("tag:") &&
            (g.tags || []).some(
              (t) => t.trim().toLocaleLowerCase() === filter.slice(4),
            ))) &&
        [g.title, g.description, g.authorName, g.owner, ...(g.tags || [])]
          .filter(Boolean)
          .join(" ")
          .toLocaleLowerCase()
          .includes(normalized),
    )
    .sort((a, b) =>
      sort === "likes"
        ? (b.likes || 0) - (a.likes || 0)
        : sort === "title"
          ? a.title.localeCompare(b.title)
          : 0,
    );
}
