# Ada Studio Web

`Editor/WebUI` is the default browser editor: a small React/DOM shell with native
text inputs and floating object/assistant/inspector panels. Both the scene viewport
and Play use the fixed `AdaWebPlayer` in one isolated iframe; the editor does not
draw a separate scene in SVG, Canvas or another renderer. Opening a project starts
AdaEngine asynchronously while the DOM controls remain available. There is no
user Swift compilation, native process runner, ACP subprocess, SourceKit or
credential-store dependency in the browser target.

## Modules and boundaries

- `Editor/StudioCore` owns portable values, project snapshots, scene operations,
  document transactions/undo, source templates, bounded ZIP interchange and the
  platform service protocols. Native Studio uses its scene value codec and runtime
  capabilities; its existing workbench remains the native editor.
- `Editor/WebUI/src` owns the DOM interface, document transactions, ZIP interchange,
  cloud/recovery controller and browser agent loop. It consumes the existing
  portable snapshot/scene/API contracts; it does not import native Swift tooling.
- `platform.js` provides HTTP/SSE, IndexedDB and download; `preview.js` owns the isolated engine bridge.
- `Editor/Web` retains the previous AdaUI/WASM editor (`AdaEditorWeb`) as an
  optional legacy export, including its explicit publishing/release UI. Publishing
  controls have not yet been ported to the DOM shell; local testing has them disabled.
- `studio-player.js` runs on a separate HTTPS origin. It accepts only the
  configured Studio origins and mounts source snapshots into the fixed player's
  virtual filesystem. No Cloud token or provider key is part of that payload.

The Editor/Code/Game tabs share one document. File and scene tools use the same
transactions as manual changes. Undo preserves the conversation. Scene preview
installs component schemas without running gameplay systems; Game runs gameplay.
The inspector edits authored component values, including position/quaternion/scale.
Unknown runtime components fail with a diagnostic before scene entities spawn.
Scene selection uses the object hierarchy or viewport bounds picking; the inspector edits supported transforms,
materials and camera properties. Move/rotate/scale gizmos update the live world during
a drag and commit one document transaction on release. Escape/pointer cancellation
restores the original transform. Translation supports global/local axes; rotation
and scale use local axes. Ctrl enables positional/15-degree/scale snapping.
Scene changes replace the world inside the running
Player, retaining its WASM instance, GPU device and browser window. Editor mode uses
an ephemeral copy of the authored game camera and the same renderer with gameplay scripts, physics and autoplay
disabled. Play recreates the world from the same source snapshot with gameplay on;
Stop restores the authored scene. Readiness is acknowledged after an actual completed
GPU frame. Failed updates show engine diagnostics, and older queued updates cannot
mark a newer document revision ready. The SVG layer contains only gizmo handles and
selection bounds projected with actual AdaEngine matrices; all scene pixels remain
AdaEngine output. Camera/light entities are selected through the hierarchy. Meshes,
models and sprites use bounds picking (sprite transparent pixels are not filtered).
An edit overlapping a newer document/agent revision is discarded and reloaded.

Right-drag looks around; right-drag + WASD/QE flies (Shift is faster). Alt-left-drag
orbits the selection, middle-drag or Q pans, the wheel dollies/zooms, and F/double
click frames the selection. Reset returns to the authored game view. Navigation
never changes project cameras or enters undo; Play always uses authored cameras.
Studio captures pointer gestures and forwards bounded coordinates/revisions to the
isolated Player; dragging across panels does not lose the gesture. Expand Scene
hides panels until the toolbar button or Escape restores them.
Tools and navigation hints are available from the viewport toolbar. Duplicate
retains children and remaps their parent IDs. Delete removes the selected subtree.

The Code tab uses CodeMirror with an AdaScript tokenizer, syntax colors, line
numbers, bracket matching, indentation and Ctrl-F search. Code edits and undo use
the same document as scene/agent edits; a selection becomes assistant context.

The side rail navigates sections of the open project: overview (Home), scene,
assets, code and assistant. Assets have their own section instead of covering code.
The project title and save status stay visible. Switching sections retains the
document, undo, selected object, code editor and isolated Player instance.

All Projects is a separate action. It waits for cloud save before opening the
project list, which offers Continue for the open project. Selecting that project
returns to the existing document; opening another project reads its cloud snapshot
and pending IndexedDB recovery. On save failure the user can stay, retry, export a
ZIP or explicitly save a local draft and leave. The latter waits for a successful
IndexedDB transaction; storage failure keeps the project open. Local recovery is
scoped to this browser/device and cloud reopen currently requires a connection.
The browser's unload guard protects unsaved cloud changes and active agent work.

## Export

Use Swift 6.3.2 with its `swift-6.3.2-RELEASE_wasm` SDK on Linux/macOS (WSL on
Windows), plus the pinned Tint host tool:

```sh
cd Editor/WebUI
pnpm install --frozen-lockfile
pnpm test
pnpm build
cd ../..
python3 script/export_studio_web.py --output dist/studio-web \
  --studio-origin https://cloud-test.adaengine.org
```

The command copies the DOM build to `studio/` and exports `player/` using the existing
`export-web` plugin. `--legacy-wasm-editor` additionally builds the older AdaUI shell
instead of the DOM frontend. `--prepare-only` installs entrypoints into existing
exports; `--ui-dist` selects an already built DOM bundle. For frontend-only edits,
run `pnpm build` and `python3 script/prepare_studio_frontend.py --output dist/studio-web`
without rebuilding Swift. The helper removes non-runtime debug/name custom sections
from the player and writes `AdaWebPlayer.wasm.gz`; configure the static server to
serve precompressed gzip files with `Content-Encoding: gzip`. The helper verifies/prepares Tint and propagates the
selected Swift toolchain to plugin subprocesses. Each allowed Studio origin needs its own
`--studio-origin`. `ADAENGINE_YAMS_PACKAGE_PATH` can select an already prepared
WASI dependency; otherwise the helper creates a pinned private Yams copy with the
WASI binary64 precision constant. It never rewrites shared dependency checkouts.

Serve `studio/` at `/studio/` on the API origin. Serve the fixed player on a
separate HTTPS hostname, with `studio-preview.html` as the preview URL (a different
port on the Cloud host would still share host cookies). See the Cloud
repository's `docs/studio-web.md` for service/database/environment configuration.

Web Player **runtime API 4** and community source package **API 2** are separate
contracts. Do not compare or substitute their numbers.

## Saving, recovery and agents

Cloud snapshots include source files, assets and chat. Autosave sends an expected
server revision; a conflict creates a separate project copy. IndexedDB stores
pending changes, scoped by account and project. Restoring a checkpoint creates a
new revision. ZIP export contains editable portable sources, never authentication
settings. Import creates another project identity. ZIP import accepts stored and
deflated entries and validates paths, sizes and CRCs.

The provider registry is controlled by Cloud. Models without tools are unavailable
to the agent. Ada AI uses the existing credit reservation/settlement API; BYOK
passes the ephemeral in-memory key to the Cloud provider proxy. Neither mode sends
credentials to the player. Generation stops advancing when the tab closes; an
already submitted upstream response may finish server-side solely to settle its
actual cost. Interrupted tool calls are not blindly replayed on return.

The retained legacy publishing UI captures a source snapshot, checks Pro and uses the existing upload,
validation and moderation pipeline. An agent cannot call publication. Draft saves
do not alter approved releases. Public release activation uses the existing
approved-release rollback API.

## Validation

```sh
swift test --package-path Editor/StudioCore
ADA_CLOUD_ONLY=1 swift test --filter 'StudioProvider|Workspace'
```

The second command belongs in the Cloud checkout. Its workspace integration suite
requires a disposable PostgreSQL database, Redis and private S3-compatible storage;
see the Cloud guide. Run `script/validate_webgpu.sh` with a compatible native
Swan/Dawn configuration and build native Studio after shared-code changes.

The browser release gate also requires real WebGPU frames, keyboard/text input,
2D/3D scene edits, recovery/conflict handling and an end-to-end publication in the
test environment. Compilation or deterministic provider fixtures alone do not
establish live-provider, audio or hosted moderation acceptance.

Local verification results and remaining hosted release gates are recorded in
[StudioWebValidation.md](StudioWebValidation.md).

For local development only, the editor and isolated player may use HTTP on
different loopback hosts (for example `localhost` and `127.0.0.1`). Hosted
previews still require HTTPS on a distinct hostname. Set
`STUDIO_PUBLISHING_ENABLED=false` in Cloud to hide publication/Pro controls
while testing project editing.
