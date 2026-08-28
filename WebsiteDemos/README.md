# Website demo metadata

`scripts/build-website-demos.mjs` adds metadata and a preview image to every
website demo bundle.

## Description

Curated descriptions and search keywords live in `WebsiteDemos/metadata.json`,
keyed by the SwiftPM product name. Add an entry there for every published demo.

For an uncatalogued demo, an explicit source description can be used:

```swift
/// Demo description: Build and organize cards on an interactive Kanban board.
```

The script uses catalog metadata first, then that line, then the first
documentation comment in the source file, and finally a generated description
based on the product and category.

## Preview image

Place an optional custom preview in `WebsiteDemos/Previews` and name it after
the SwiftPM demo product:

```text
WebsiteDemos/Previews/KanbanBoardExample.webp
```

Supported extensions, in preference order, are `webp`, `png`, `jpg`, `jpeg`,
`avif`, and `svg`. A slug-based name such as `kanban-board-example.webp` is also
accepted. The exported file is normalized to `preview.<extension>`.

When no custom image exists, the script generates a branded 1200x675
`preview.svg`, so website cards always have a usable image.

## Generated contract

Each demo directory contains:

- `metadata.json` with title, description, keywords, category, source, embed,
  preview, accessibility text, preview kind, and build state;
- `preview.<extension>`;
- the existing source and web bundle files.

The root `manifest.json` repeats the fields needed to render a demo card without
fetching each demo's metadata first.

After introducing metadata into an existing website output, run one metadata-only
refresh before selective builds so every preserved manifest entry is upgraded:

```bash
node scripts/build-website-demos.mjs --skip-build
```
