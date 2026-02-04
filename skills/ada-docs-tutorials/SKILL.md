---
name: ada-docs-tutorials
description: Write and update AdaEngine documentation tutorials and guides. Use when creating DocC tutorials, walkthroughs, or narrative docs for engine features and workflows.
---

# Ada Docs Tutorials

## Overview
Create and update AdaEngine tutorials and guides with DocC-friendly structure. Prefer concrete, runnable examples and keep code snippets aligned with the current public API.

## Key Areas
- DocC output is generated from package targets listed in `Package.swift`.
- Tutorials are published under `adaengine-docs` hosting base path (see `AGENTS.md` Documentation section).
- Source docs live with the modules; keep changes scoped to the relevant target.

## Workflow
1. Identify the module(s) the tutorial targets (e.g., AdaEngine, AdaECS, AdaRender, AdaUI).
2. Confirm the public APIs used in examples exist and compile.
3. Write the tutorial in a stepwise flow: goal → setup → core steps → verification → next steps.
4. Keep snippets short and focused; prefer building on earlier steps instead of duplicating.
5. If introducing new APIs, ensure docs explain constraints and platform caveats.

## Doc Structure Guidelines
- Use clear section headings and consistent terminology with existing API docs.
- Include “What you’ll build” and “Prerequisites” when the tutorial is multi-step.
- Use small, incremental code changes and explain why each change is needed.

## Testing
- Run `swift build` to ensure code examples compile in the target modules.
- If the tutorial includes behavior changes, run the relevant tests.
