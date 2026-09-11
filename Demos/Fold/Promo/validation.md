# Shadow Fold validation — 11 September 2026

## Passed

- AdaEditor product builds with the new FoldPose, projection, simulation, native presenter and UI controls.
- 15 Swift Testing tests passed: ShadowFoldTests plus the existing EditorFoldableTests.
- New coverage includes real-level completion using movement/jumps/fold angles, projection and inverse transforms, independent stick/jump contacts, moving shadow support, disappearing support and checkpoint restore, occupied portal rejection, keyboard focus loss, real `.ada` / `.ui` project loading, repeated Play sessions, and authored initial pose/prism restoration.
- The actual macOS QA app completed the entire level using ordinary window input: 135° first bridge, 90° seam crossing, outer-screen prism drag/transfer, then the 80° final bridge.
- A separate native-window check moved the traveller with the virtual stick and released it to stop.
- Native validation retained the SceneView world and Transfer Prism entity ID across the surface transfer. The recorded run also reached the exit after a Stop → Play restart.
- Local QA bundle signature verified before launch.
- Promo is a genuine window recording, cropped and composited with typography: H.264, 1920×1080, 30 seconds, 30 fps. Export frame rate is not an engine performance benchmark.

## Validation boundaries

The combined Editor test target was modified concurrently during compilation and failed in unrelated EditorAgentActivityTests code. Focused validation therefore compiled the unchanged ShadowFoldTests and EditorFoldableTests source files into a separate Swift Testing executable using the SwiftPM-produced Editor/engine modules, object list and compiler arguments. This is not a full Editor-suite pass. Some pre-existing shader-cache permission diagnostics appeared in the sandboxed tests; the assertions passed and real Metal output was checked in the QA app.

The UIKit contact-ID path was implemented, but no physical iPad/iPhone or foldable hardware sensor was validated. Device posture remains explicitly simulated. Nothing was published.

## Artifacts

- `shadow-fold.mp4`: edited 30-second promo.
- `shadow-fold-raw.mp4`: original window-only recording.
- `shadow-fold-cover.png`: cover extracted from the promo.
- `native-input-stage*.json`: exact captured window-input sequences for the successful validation. Window IDs are session-local and must be refreshed before replay.
- `validation.json`: compact result metadata.

The game is a first playable, data-driven level. The regular Foldable Preview remains available for other projects.
