# AdaEngine project metadata

Ada projects may contain a committed portable metadata file at `.ada/project.json`.
Schema version 1 is described by `Docs/Schemas/ada-project.schema.json` and is
implemented by `ProjectSystem` in `AdaEditor`.

## `.ada/` layout

- `.ada/project.json`: portable project config; commit this file.
- `.ada/workspace.json`: local user/editor state; do not commit.
- `.ada/cache/`, `.ada/logs/`, `.ada/indexes/`, `.ada/ai/cache/`: generated local data; do not commit.

Suggested `.gitignore`:

```gitignore
.ada/workspace.json
.ada/cache/
.ada/logs/
.ada/indexes/
.ada/ai/cache/
```

## `project.json` schemaVersion 1

Only `schemaVersion` is required. Optional sections are `project`, `engine`,
`paths`, `build`, `run`, `editor`, and `ai.mcp`. `ProjectSystem` supplies stable
defaults for omitted sections while preserving parsed metadata such as project
name, display name, bundle identifier, engine package, build/run information, and
MCP resource roots.

All path-like values in `project.json` are portable project-relative paths. POSIX
absolute paths, Windows absolute paths, home-relative paths, backslash syntax,
empty path segments, URLs, and `..` traversal segments are rejected.

Future schema versions must be explicitly migrated before validation. Readers
must reject missing `schemaVersion` and unsupported versions.
