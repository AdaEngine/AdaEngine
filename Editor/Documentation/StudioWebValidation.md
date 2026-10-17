# Ada Studio Web validation — 2026-10-17

The implementation spans AdaEngine and the sibling `ada_cloud` checkout. No
external environment was deployed, no paid provider request was submitted, and
`STUDIO_WEB_ENABLED` remains off by default.

## Engine viewport correction (current)

The SVG scene renderer has been removed. Opening a project now starts the actual
AdaEngine Player in editor mode; both editor and Play use its authored cameras,
materials, lights and asset loaders. DOM panels still render independently of WASM.

- The updated fixed Player exports with Swift 6.3.2/WASI. Scene/source updates mount
  a new bounded `/game` tree and replace the SceneView world in the same WASM/GPU
  instance. The bridge acknowledges readiness only after a completed GPU frame.
- Real browser checks covered 3D object transforms and undo, camera movement and
  undo, a malformed AdaScript diagnostic, and recovery after fixing the source.
  The Player retained its browser window/canvas across changes and Play/Editor.
- A 500 × 330 pixel viewport region of the static 3D test scene was **identical**
  between editor and Play (mean absolute channel error 0). Moving the player caused
  a measurable difference in that same region, confirming the engine applied the edit.
- The existing 2D project with scripted behavior loads in editor mode and runs in
  Play; Stop restores its authored scene. World changes do not refetch/reinstantiate
  WASM. Logs show one initial player load/window creation per project.
- All 16 DOM/document/bridge tests pass, including coalescing duplicate updates,
  rejecting superseded acknowledgements, cancellation and origin/source checks.
  The WebGPU validation script passes 38 tests in 13 suites, including actual pixels.

Selection and transforms currently use the hierarchy/inspector. Direct on-viewport
picking/gizmos remain unimplemented; there is no substitute schematic or second
renderer. First project opening still waits for engine compilation/GPU setup in the
viewport while panels and code remain usable.

## Earlier DOM frontend iteration (superseded viewport)

The default frontend now lives in `Editor/WebUI`; the AdaUI/WASM editor remains
an optional legacy export. This iteration changed the browser shell and packaging,
not the Swift renderer. Local Playwright checks used real Edge/WebGPU, the running
Workspace/PostgreSQL/S3 service and separate local identity/provider fixtures.

- `pnpm install --frozen-lockfile`, `pnpm test` (10 tests) and `pnpm build` pass.
  Document tests cover shared tool/manual undo, atomic invalid edits, native YAML,
  ZIP import/export, CRC corruption, unsafe paths, entry limits and secret exclusion.
- Two Python tests verify player debug-section stripping and malformed-module
  rejection. `export_studio_web.py --prepare-only` installs the DOM shell and player
  bridge successfully; both Cloud Caddy configurations adapt with fixture variables.
- A fresh browser context fetched approximately 359 KB of JS/CSS, with **zero WASM
  requests** before Play. Local first contentful paint was 32 ms; this is a loopback
  observation, not a hosted-network performance promise.
- The current debug player shrank from 232,970,294 bytes to 98,731,427 bytes after
  removing non-runtime debug/name sections. Its gzip transfer is 34,508,239 bytes;
  browser responses report `Content-Encoding: gzip` and `application/wasm`.
  Both a real 2D sprite and the new primitive 3D environment render after stripping.
- Manual inspector/source editing, undo/redo, cloud save/reload, ZIP download/file
  import, checkpoint creation/restoration, and a two-tab conflict copy passed.
  A failed save survived in IndexedDB and recovered when its original project reopened.
- The deterministic agent completed scene/file edits, runtime validation and Play.
  Rapid cancellation removes the iframe without a spurious error. The mobile game
  viewport reaches 420 px while the editor controls remain desktop controls.
- Observed preview requests carried neither cookies nor Authorization, and the
  iframe could not read the parent DOM (`SecurityError`). An entered fixture API key
  was absent from the exported ZIP and empty after reload. Pro/publication controls
  are absent in this local test iteration.

The instant scene overview is an editable SVG map, not a 3D camera viewport. Actual
3D rendering/compiler validation uses the lazily loaded AdaPlayer. First runtime
startup still includes WASM compilation and GPU setup; release-player optimization
remains separate from the now lightweight editor startup. DOM publishing/release UI
has not yet been ported. The checks below describe the earlier retained AdaUI build;
they do not establish feature parity for every DOM interaction.

## Confirmed locally

| Area | Result |
|---|---|
| Portable core | 7 Swift Testing tests pass on Windows: ZIP CRC/deflate/round trip, import identity, atomic edits/undo, limits and credential exclusion |
| Native editor | Windows debug editor and its test executable build after extracting the common value codec; 11 selected scene/agent/mobile validation tests pass |
| WASM | `AdaEditorWeb` and fixed `AdaWebPlayer` export with Swift 6.3.2 and the matching WASM SDK |
| GPU | `script/validate_webgpu.sh` on Windows passes 38 tests in 13 suites, including actual pixels, picking and Tint conversion |
| Player source contract | Three focused scene-backed Web Player compiler tests pass, with runtime API 4 |
| Cloud | Services compile; 55 selected CloudCore/AI credit tests and 9 workspace/provider policy/integration tests pass against disposable PostgreSQL, Redis and S3-compatible HTTP storage; provider adapter tests also pass |
| Packaging | 16 Python archive/source-package tests pass; a ZIP actually downloaded from Studio assembles with the real fixed player into a 165-file publication build (runtime API 4, community package API 2) |
| Edge | Local/VPS Compose YAML parses; both Caddy configurations adapt successfully |

Real Chrome/WebGPU interaction used the actual AdaUI/WASM application and Workspace
HTTP service, with local session/catalog/provider fixtures. These are separate
from the shipped application. Confirmed workflows include:

- Create/open 2D and 3D projects and render actual sprite/primitive frames.
- Edit source text and camera position/cube rotation in the inspector, autosave,
  and inspect the resulting server revision. The rotated cube has visible shaded faces.
- Type Cyrillic through browser keyboard events and verify UTF-8 source storage;
  paste Cyrillic from the actual browser system clipboard into the AdaUI editor.
- Import and render the actual static GLB crate fixture; load a generated PCM WAV,
  activate audio with pointer input, and observe nonzero audio samples submitted
  by AdaAudio to Web Audio (peak 0.01144). This checks decoding/output, not a
  human listening test.
- Lose connectivity, edit offline, reload, and recover from IndexedDB into Cloud.
- Download an editable ZIP and import it through the browser file picker as a new project.
- Run an in-tab deterministic agent through scene/file edits, source diagnostics and
  game launch. Undo/redo preserves chat. The disposable API key is absent from snapshots.
- Save a conflicting revision through another client, then edit the stale browser
  document: both original and automatically created copy retain their own changes.
- Create a checkpoint and reject publication for an account without Cloud Pro.
- Switch Game/Scene rapidly and retain exactly one preview iframe.
- Use a distinct HTTPS preview hostname: observed game requests carry neither
  Cloud cookies nor Authorization; iframe parent DOM access is denied.

## Remaining release gates

A configured live provider must exercise both hosted Ada AI settlement and BYOK,
including a disconnected request. A Pro test account must complete the full hosted
upload, moderation, release activation and rollback path. Physical IME input, human
listening checks and the full set of supported browsers still need acceptance coverage.
The Windows GPU run does not establish every macOS-only 3D golden-frame suite. Debug WASM bundles are validation artifacts; prepare the
release exports before deploying.

The existing full `AdaWebPlayerTests` suite has four failures in older `@view`
fixtures: the unchanged schema parser reports that AdaUI views in AdaScript are
temporarily unavailable. Scene-backed tests pass. This work does not enable the
disabled view feature or claim the full engine suite is green. The Windows Swift
6.3.1 driver also emits corrupted-JSON diagnostic-decoding warnings during otherwise
successful native compilation/linking; the selected executable tests run successfully.

See [StudioWeb.md](StudioWeb.md) and the Cloud checkout's `docs/studio-web.md` for
commands, configuration and the feature-flag rollout gate.
