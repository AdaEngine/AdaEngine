# Validation — 10 September 2026

- Editor package: 12 passing Swift Testing tests across EditorFoldableTests, EditorScriptUIBindingTests and EditorPreviewViewportTests.
- Runtime scripting: 6 passing tests across ScriptUIBindingTests, GravityScriptableObjectTests and GravityResourceBindingTests.
- The demo test opens the real scene/UI/AdaScript files, clicks the UI airlock, checks movement, folds repeatedly and runs 2500 further updates to exercise VM garbage collection.
- A real AdaptiveSceneView container test confirms one runtime creation and one tick per UI update across layout changes.
- Scaled mouse routing at 0.5 is checked for both regions and the excluded hinge.
- Actual macOS app: opened the demo through its project browser, entered Play Mode, opened the map airlock via normal window mouse events, folded and expanded again. The SceneView world ID was unchanged (validation.json).
- Swift example: compiled from the actual Demos/UI/AdaptiveSceneViewExample.swift and linked successfully.
- Promo: 1920×1080 H.264, 30 seconds at 30 fps; 7.01-second GIF; cover extracted from the genuine recording. These are video export parameters, not an engine FPS benchmark.

## Build scope

The editor build and focused tests passed using a task-owned scratch directory. A broader root SwiftPM build attempted to link all unrelated demo executables and ran out of disk space. Task-owned unused example outputs were removed; the already-compiled test runner and AdaptiveSceneViewExample were linked using the SwiftPM-generated link commands. The six scripting regression tests then passed through swift test --skip-build. The full engine test suite was not run.

The local debug .app was ad hoc signed and launched for the recording. No App Store upload, hardware fold-sensor validation or public posting was performed.

## Commands

```sh
swift test --package-path Editor --scratch-path /tmp/adaeditor-foldable-build --cache-path /tmp/adaeditor-foldable-cache --disable-sandbox --jobs 6 --filter 'EditorFoldableTests|EditorScriptUIBindingTests|EditorPreviewViewportTests'
swift test --scratch-path /tmp/adaeditor-foldable-build --cache-path /tmp/adaeditor-foldable-cache --skip-build --skip-update --disable-sandbox --filter 'ScriptUIBindingTests|GravityScriptableObjectTests|GravityResourceBindingTests'
```

Compiler runs used CLANG_MODULE_CACHE_PATH=/tmp/adaeditor-foldable-clang. The source files were left uncommitted, preserving unrelated user changes.
