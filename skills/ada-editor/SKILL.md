---
name: ada-editor
description: AdaEditor app and tooling work, including AdaUI views, editor windows and menus, input handling, and layout inspection. Use when editing the editor UI or platform-specific editor code.
---

# Ada Editor

## Overview
Handle AdaEditor UI, tooling, and platform integration. Keep UI code on the main actor and follow AdaUI view patterns.

## Key Areas
- `Sources/AdaEditor` for app entry, editor components, and UI.
- `Sources/AdaEditor/UI/EditorWindow.swift` for window layout, menu items, and inspector behavior.
- `Sources/AdaEditor/Platforms` for platform-specific editor wiring.
- `Sources/AdaUI`, `Sources/AdaApp`, `Sources/AdaInput` for view system, app lifecycle, and input events.
- `Tests/AdaUITests`, `Tests/AdaEngineTests` for UI-related behavior.

## Workflow
1. Identify whether the change is UI layout, input handling, or platform integration.
2. Update AdaUI views and window wiring in `Sources/AdaEditor/UI` as needed.
3. For input changes, align with `Sources/AdaInput` events and modifiers.
4. For platform changes, update only the relevant platform folder.

## Guardrails
- Keep UI and app lifecycle code `@MainActor` when interacting with UI APIs.
- Avoid blocking calls in UI update paths.
- Respect existing `@_spi(AdaEngine)` usage and do not widen SPI without need.

## Testing
- Run `swift test --parallel --filter AdaUITests` when changing AdaUI or editor UI.
