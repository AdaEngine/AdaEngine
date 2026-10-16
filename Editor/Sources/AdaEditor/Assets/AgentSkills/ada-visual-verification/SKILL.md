---
name: ada-visual-verification
description: Verify scene, rendering, gameplay and AdaUI changes by looking at the running game and playing it with scripted input.
allowed-tools: editor.project.context, editor.scene.get, editor.play.start, editor.play.capture, editor.play.run_scenario, editor.output.read, editor.task.status, world.list_worlds, entity.find, ui.list_windows, ui.get_tree, ui.find_nodes, ui.get_layout_diagnostics, ui.capture_node_screenshot, render.capture_screenshot
---

# Ada Visual Verification

Use this after any change whose success is visible or playable.

## What counts as evidence

- **Game frame**: a PNG of the running game's own camera (2D or 3D) returned by `editor.play.capture`, by `render.capture_screenshot` while Play is running, or by a `capture` step of `editor.play.run_scenario`. Look at the image. A path alone is not evidence.
- **Game state**: `snapshots` from `editor.play.run_scenario` (entity transforms, component values) and `logs` (script prints/errors). State proves logic; a frame proves appearance. Use both for "bird falls", "space lifts it", "pipe gives +1", "collision ends the run", "R restarts".
- **Not evidence**: compilation, a build success line, a saved scene, the editor window, or `render.capture_screenshot` without Play. Without a running game it captures the **editor window** and its result `world` says `editor-window`; never use that as game proof. `editor.play.capture` errors instead when no game runs.

## Look at the game

1. Build (`editor.build.start`, poll `editor.task.status`, read `editor.output.read` errors) and fix errors first.
2. Start Play (`editor.play.start`) and wait until `editor.task.status` reports it running, then call `editor.play.capture` (optional `cameraName`, `maxDimension`). It waits for a completed frame and fails with an explicit message if the game is not rendering. Keep `maxDimension` at 640 unless detail matters.
3. Inspect the image: is the subject visible and framed, is the background intended (not a flat default color), are lights/materials right, is the HUD readable?

## Play the game

Use `editor.play.run_scenario` to test behavior without a person. It defaults to an isolated offscreen runtime of the AdaScript project (your Play window is untouched); `target: "play"` drives the game already running.

```json
{"steps":[
  {"t":0.2,"capture":"idle"},{"t":0.3,"snapshot":"before"},
  {"t":0.5,"key":"space","tap":true},{"t":0.7,"capture":"after-flap"},{"t":0.7,"snapshot":"after-flap"},
  {"t":6,"snapshot":"late"},{"t":6.1,"key":"r","tap":true},{"t":6.6,"snapshot":"restarted"}],
 "watch":{"entities":["Bird"],"components":["Transform"]},"duration":7}
```

- Step forms: `{t,key,down|tap}`, `{t,mouse:'left',down|tap,x,y}`, `{t,move:{x,y}}`, `{t,capture:label,camera?}`, `{t,snapshot:label}`. Same-time steps run in written order; `tap` presses and releases after `hold` seconds.
- Limits: 60 s, 400 events, 12 frames, 40 snapshots, frames up to 1280 px. Timing is wall-clock, so compare behavior (direction, order, thresholds) not exact positions.
- Read `status`, `errors`, `scriptErrorCount`, `diagnostics`, `logs`, `frames[].path`/`error`, and compare `snapshots`. A frame error is a `manualChecks` entry, not a pass.
- Make state observable: snapshots list each watched entity's components and its scriptable objects' `@export` fields (`scripts[].fields`). Script globals/statics and `System.print` output are NOT readable (print goes to the process stdout, `logs` only has errors). Keep score/phase/alive flags in `@export var` fields of a scriptable object on a named entity (update them every frame) and assert from `snapshots`.
- `worldElapsedSeconds` and `frameSequence` in each snapshot must grow; if they are flat the game is not advancing.
- Each frame reports `meanRGB` and `uniform`; a `uniform: true` frame (flat color) carries a warning and is not proof. Use `warmup:false` to capture startup frames when hunting flashes.
- Scene HUD/UI overlays are not rendered offscreen; verify HUD layout with `target: "play"` and `editor.play.capture`, or with `ui.capture_node_screenshot`.

## Other captures

Use `ui.capture_node_screenshot` for AdaUI or editor layout, not for game output. For static scene appearance outside Play, the scene viewport is the editor camera; it does not show what the game camera sees.

## When a check is unavailable

If the tool is missing, the host cannot render (no GPU/display), Play fails to show frames, or a frame call returns an error: do not retry in a loop and do not claim it passed. Record the exact check as **manual** (what to look at, how to trigger it), keep the evidence you do have (build, snapshots, logs), and continue with the remaining work. Report manual checks in the final summary.

## Blank or white frames

A viewport used to turn transparent (showing the panel behind it) for a few frames whenever its size changed, which looked like a white flash; the engine now keeps the last frame until the resized one is ready. If a frame is still blank or white, check the scene: no `Camera`, a camera clear color not set, no light, or no `Environment3D`/background so geometry floats on a flat clear color. Inspect with `entity.find`/`editor.scene.get`, set the camera `backgroundColor` and clear flags, add a light and (for 3D) an environment, rebuild, and capture again. See `ada-scene-authoring`.
