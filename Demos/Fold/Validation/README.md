# Migration validation — 2026-09-11

- Standalone Fold package: `swift test --package-path Demos/Fold --scratch-path /tmp/adaeditor-foldable-build --cache-path /tmp/adaeditor-foldable-cache --disable-index-store --disable-sandbox --skip-update --jobs 6` — 8 Swift Testing tests passed after removal of the engine-owned game implementation.
- AdaUI VirtualJoystickTests — 5 passed, including custom dimensions, transparent drag/release, contact ownership, invalid settings and real .ui parameter-to-input integration.
- EditorFoldableTests — 6 passed, including retained runtime identity, companion bindings and missing source diagnostics. These two focused suites were compiled from their actual source files with the SwiftPM-produced modules/object lists; this is not a full Editor-suite pass.
- AdaEditor product built successfully in the isolated scratch directory (71.56 s).
- No ShadowFold, ShadowLevel, ShadowPlatformer, FoldPose or FoldAttachment references remain in Editor/Sources or the engine Sources.

## Native macOS interaction

The diagnostic app hosts the project's unmodified FoldGameView and adds a read-only game snapshot serializer to MCP in a temporary QA entry point. No QA plugin is included in Fold or AdaEditor sources.

Native keyboard/mouse input completed the entire level: checkpoint 1 at 135°, checkpoint 2 at 90°, drag the outer prism into the portal, transfer it, return inside and reach the exit at 80°. Final x=745.337 and completed=true, with no runtime error. See playthrough.json and completed.png. All stages retained the same SceneView world.

Joystick screenshots show idle → drag → release. The base stays transparent; the thumb appears while dragging. Native input reached x-axis 0.926 and moved the character from x=55 to approximately x=117 in a separate input check; release resets the axis. Screen captures explicitly use pauseBeforeCapture=false because the diagnostic capture tool otherwise pauses the runtime.

Older Promo captures predate this refactor. Original migration inputs are backed up at /tmp/fold-migration-originals; no shared .build cache was deleted.
