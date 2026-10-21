# Native Shader Graph — PR Decomposition Map

- **Created:** 2026-10-20
- **Epic reference:** user-approved architecture discussion in this chat: typed
  graph/IR, Sprite and PBR outputs, native AdaUI document editor and templates.
- **Trunk:** `main`; discovery baseline `5b6085790`. Working tree was clean.
- **Approval:** user approved all eighteen slices and additive integration without
  a shared feature flag on 2026-10-20.
- **Size budgets:** target <=600 added + removed reviewable lines per slice,
  including tests and localization. Markdown, generated files and image fixtures
  are excluded. Re-slice before exceeding the target; 600–1000 requires an
  explicit justification, and >1000 is not an accepted feature slice.
- **Delivery:** implement and validate locally, one slice at a time. This map
  does not authorize publishing, merging, deploying or submitting a release.
  PR creation and subsequent transitions follow the user's delivery instructions.

## Intended result

Create a graph asset, connect typed nodes, preview it on a sprite or 3D surface,
assign it in the Inspector, edit per-instance parameters, save/reopen the project,
and see the same result in scene edit mode and Play. Multiple instances share
compiled code but retain their own values. Ordinary materials keep their existing
rendering and batching paths.

The first release authors fragment computations. Vertex displacement, custom
shader-code nodes, subgraphs, post-processing and a browser graph editor are
outside this map. Native shared-workbench UI uses AdaUI; no AppKit/SwiftUI-only
editor implementation. Mobile interaction parity must be verified separately.

## Integration decision

**Recommended: additive APIs followed by complete consumers.** The graph compiler
is useful and testable without a Studio editor. Sprite/PBR assignment becomes
available only when its rendering and persistence work. Canvas/model components
remain unregistered until the complete graph document is connected in slice 12.
Opaque PBR ships before graph alpha modes; mask/blend controls arrive only with
the corresponding passes in slice 8. No shared feature flag or cleanup debt.

Alternatives considered:

1. Gate the graph authoring entry points: the new-file template registration,
   `.shadergraph` dispatch in `EditorViewModel.openProjectItem`, and rendering in
   `EditorCenterWorkbench.activeDocumentView`. This permits unfinished authoring
   on trunk but needs a project toggle convention and a separate removal slice;
   it does not remove the need to preserve old scene/rendering behavior.
2. Replace existing materials behind a new universal material interface and
   migrate all consumers. This creates a much larger migration and temporary
   dual implementations; the new capability does not require that replacement.

The recommendation is additive integration. Existing `Material`/`PBRMaterial`,
stock sprite rendering, animation graphs and text shader editing remain useful;
their wholesale replacement is not part of this feature.

## Slices

Every row includes production-path tests appropriate to its behavior. The
budgets are estimates, not permission to hide implementation in generated files.

| # | PR title | Purpose | Strategy | Budget | Depends on | Status |
|---|----------|---------|----------|--------|------------|--------|
| 1 | Validate and lower typed shader graphs | Decode graph assets, validate typed connections and produce deterministic IR. | Additive CPU API | 550 actual | — | in-review (local) |
| 2 | Compile graph expressions into shader functions | Generate GLSL with node/port diagnostics and compile a real fixture through the engine compiler. | Additive compiler API | ~550 | 1 | implemented locally |
| 3 | Bind graph parameters and texture resources | Produce stable resource layouts and independent material-instance values. | Additive material API | ~550 | 2 | implemented locally |
| 4 | Render Sprite graph materials | Support graph output in sprite extraction, batching and both draw implementations. | Complete opt-in runtime path | ~600 | 3 | implemented locally; CPU/render preparation verified |
| 5 | Author Sprite graph assignments in Studio | Persist graph references/values and expose assignment in the Sprite Inspector. | Complete consumer of slice 4 | ~550 | 4 | implemented locally; focused Editor checks pass |
| 6 | Extract the existing PBR surface evaluation seam | Separate surface evaluation from shared lighting with identical stock-material pixels. | Complete behavior-preserving shader refactor | ~550 | — | implemented locally; Metal golden frames pass |
| 7 | Assign opaque PBR graph materials | Render and persist graph surface overrides for primitives and imported model material slots. | Complete opaque-only path | ~600 | 3, 6 | implemented locally; Metal pixels and Editor tests pass |
| 8 | Keep graph alpha consistent across 3D passes | Add mask/blend settings with matching depth, shadow and auxiliary-pass behavior. | Complete alpha-mode addition | ~600 | 7 | implemented locally; all 29 core/GPU checks pass |
| 9 | Edit graph documents with transactional history | Add document operations, stable selection and undo/redo independent of the visual canvas. | Additive unused authoring model | ~550 | 1 | implemented locally; document tests pass |
| 10 | Draw a reusable AdaUI node canvas | Implement graph-space geometry, node/port layout, wires, pan/zoom and hit testing. | New unregistered component | ~600 | 9 | implemented locally; canvas geometry checks pass |
| 11 | Connect and manipulate nodes on the canvas | Add compatible-port gestures, node movement, selection and transaction boundaries. | New unregistered interactive component | ~600 | 10 | implemented locally; AdaUI pointer events pass |
| 12 | Open complete Shader Graph documents in Studio | Wire tab routing, creation, file IO, Inspector and parameter controls into the existing workbench. | Final small authoring registration | ~600 | 5, 7, 9, 11 | implemented locally; creation/routing/save/history/UI events pass |
| 13 | Preview graph edits through the production renderer | Add revision-bound compilation, preview transport and visible diagnostic recovery. | Complete preview addition to working editor | ~600 | 8, 12 | implemented locally; CPU revision/recovery and real WebGPU pass |
| 14 | Ship animated and procedural effect templates | Add Time/UV operations, base procedural noise, Dissolve and UV Scroll examples. | Independently runnable nodes/templates | ~550 | 13 | implemented locally; effect compilation and templates pass |
| 15 | Navigate and organize larger graphs | Add context-aware node search, copy/paste, groups, comments and error navigation. | Complete usability additions | ~600 | 12 | planned |
| 16 | Change exposed graph values from AdaScript | Add typed parameter access through the real runtime and native AOT binding paths. | Additive scripting API | ~550 | 5, 7 | planned |
| 17 | Package graph materials for exported games | Bake/collect shader variants and resources and reject unsupported targets explicitly. | Additive export support | ~600 | 8, 14, 16 | planned |
| 18 | Verify and document the complete authoring workflow | Exercise native UI, saved scenes, GPU parity and ordinary-material performance. | Separate QA artifacts/docs | ~400 | 13–17 | planned |

## Architecture and compatibility

- Pure graph schema, validation, typed IR and common code generation belong in
  `AdaRender`; they do not depend on AdaUI, StudioCore or editor document state.
  Target-specific shader integration lives in `AdaSprite` and `AdaCorePipelines`.
  Persistence adapters stay with the owning scene/editor components.
- A versioned `.shadergraph` asset has stable node, port and exposed-parameter
  IDs. The resource contains a distinct editor-layout section; layout changes
  affect dirty/save/undo state but not the compiled-program cache key.
- One graph has one target/output: Sprite or PBR Surface. Common node definitions
  and IR are shared. Changing targets must validate every surviving connection.
  Do not silently reinterpret colors, vectors or texture spaces.
- Values include Float, Bool, Vector2/3/4, Color and Texture2D. Numeric scalar
  broadcast is explicit in lowering; incompatible vector dimensions and resource
  links are rejected. Normal input is tangent-space and textures retain the
  existing Color/Normal/Data import semantics.
- Sprite output supplies color/alpha; PBR supplies base color, tangent normal,
  metallic, roughness, emission, occlusion and alpha. The engine owns lighting,
  skinning, morphing, transforms and draw/pass setup. Vertex edits are deferred.
- Graph instances store their graph reference and typed exposed values with the
  authored component/material slot. Stable parameter IDs survive display-name
  changes; renamed display labels are not shader binding identities. Existing
  `.mat` files keep their current format and behavior.
- Sprite adds an optional graph-material assignment without changing the meaning
  of old scenes. Unassigned sprites retain the old fast path. Custom draws split
  batches by compatible shader/material bindings while preserving transparent
  order, atlas addressing, layout modes, tint and flips.
- Model overrides are authored against stable imported material-slot identities;
  they do not rewrite GLB/glTF files. Duplicate/reparent/save/undo preserve the
  instance values. Missing slots/resources produce a visible diagnostic.
- CPU compilation accepts immutable Sendable snapshots. C compiler initialization
  and finalization must be serialized against *all* existing shader compilation,
  not merely graph requests. GPU object creation/swaps respect the existing
  renderer ownership and frame lifecycle. No per-frame shader/pipeline creation.
- Cache identity includes semantic graph contents, compiler/template versions,
  backend, vertex layout, render-pass state and feature variants. Runtime values
  and node positions do not trigger shader recompilation. Old pipelines remain
  alive until in-flight frames release them.
- Failed/stale compilation never replaces a newer successful material. A preview
  retains the last valid frame with a visible stale/error state. A first-load
  failure surfaces an error; it must not silently appear as a successful default
  material. Diagnostics retain graph/node/port identity.
- Browser authoring is deferred. Native WebGPU validation is required; graph
  export must produce fresh WGSL/metadata through the existing export toolchain
  instead of assuming a browser can compile native GLSL on demand.

## Slice details and acceptance

### 1–3 — Compiler and instances

- In scope: asset round trips, typed port catalog, reachable-node lowering,
  cycle/duplicate-ID/dangling-link errors, deterministic code and node source map,
  texture/uniform binding layouts, per-instance values and revision handling.
- Start with constants, parameters, Add/Multiply/Lerp, Texture Sample, UV and the
  two output contracts. Broader operations arrive in slice 14.
- Acceptance: real generated GLSL compiles; a layout-only edit keeps the program
  key, two instances share compiled code and changing one value affects only it.
  Unknown versions or node kinds give recoverable diagnostics and preserve the
  original file; opening an unsupported asset must not rewrite it.
- Safety: public additive APIs; no existing project opens a new editor path.
- Cleanup owed: none.

### 4–5 — Sprite runtime and assignment

- In scope: stock-versus-graph draw selection, instanced and expanded paths,
  scene codec/reflection, Inspector picker and exposed-value controls, Save/Play.
- Acceptance: tint/texture graph pixels match the stock sprite, instance values
  remain independent, transparent ordering and atlas/nine-slice/tiled UVs remain
  correct; old scenes and no-graph batching metrics remain unchanged.
- Safety: only explicitly assigned valid graph instances enter the new path.
- Cleanup owed: none; the stock renderer remains the normal no-graph path.

### 6–8 — PBR surfaces and rendering passes

- In scope: a reusable surface-description function consumed by existing
  lighting, graph shader/feature variants, primitive/model-slot persistence and
  assignment, opaque first, then alpha modes with all affected passes.
- Acceptance: stock PBR golden frames match after extraction; roughness/metallic,
  normal and emission graphs render correctly on primitive and skinned models.
  Alpha-cutout shadows/depth agree with the main image; blending respects the
  renderer's supported transparency semantics. Test relevant normal/motion
  outputs and skin/morph variants rather than only a preview sphere.
- Out of scope: displacement, new lighting models and a universal material rewrite.
- Safety: the surface refactor is complete in its own slice; old variants stay
  active for stock materials. Unsupported graph modes are rejected before UI
  exposure rather than presented as half-working choices.
- Cleanup owed: remove the duplicated stock surface-evaluation block in slice 6;
  no long-lived alternative lighting implementation or feature toggle.

### 9–12 — AdaUI authoring and workbench registration

- In scope: shared graph-space geometry, port/wire hit testing, selection,
  connect/disconnect and movement transactions, deletion, property editing,
  validation, document IO/dirty state, Save/Save All, split panes and restoration.
- Layout: parameters at left, canvas in center, selected node/output Inspector
  at right, diagnostics/generated-code viewing below. Existing themes and en/ru
  language preference apply. Compact layouts collapse side panels rather than
  shrink the canvas beyond usability.
- Acceptance: one drag produces one Undo entry; rejected connections produce
  none. Save/reopen preserves connections, parameter IDs and positions. Opening
  the same graph in split panes shares document edits and stable focus.
- Initial templates: usable Sprite Tint and textured PBR; generated code is
  read-only. Graph-to-code reverse editing is not implied.
- Safety: the model/canvas are unregistered until slice 12 wires the working
  authoring document. Do not add feature toggles, test hooks or temporary launch
  objects to the production app.
- Cleanup owed: none.

### 13–15 — Preview and authoring convenience

- In scope: sprite/plane/sphere or selected-model preview through production
  rendering; Time play/pause/reset; debounced compile requests, explicit Compile,
  revision cancellation/discard, compiler diagnostics and last-valid display.
- Search opens on Space or an unfinished wire and filters by compatible ports.
  Port labels accompany colors. Copy/paste remaps IDs and connections; groups
  and comments affect layout only. Undo transactions apply to every command.
- Procedural nodes/templates are validated on both renderer backends. Node-level
  previews are optional on demand; do not render every node continuously.
- Acceptance: typing/moving nodes remains interactive during compilation;
  outdated success/failure cannot replace current state; language switching keeps
  mounted input and longer Russian labels usable.
- Safety: each slice adds complete behavior to an already usable document editor.
- Cleanup owed: none; task-only QA projects remain outside production sources.

### 16–18 — Scripting, export and release evidence

- In scope: discover exposed parameters by stable ID/name, read/set typed values,
  real AdaScript VM and native AOT access, scene serialization, resource discovery
  and target compilation for graph variants in exported games.
- Export errors identify the graph/target and block success if required variants
  cannot be built. Do not silently drop graph materials or reuse unrelated WGSL
  caches. A browser graph-editing UI is not required for exported game playback.
- Acceptance: Save → close → reopen → Play reproduces both graph kinds and
  instance values; a script changes a parameter without recompilation; a packaged
  game renders the graph and includes its textures and generated shader artifacts.
- Safety: new scripting APIs and exporter support are additive. Unsupported
  export targets fail with a clear diagnostic until their support is proven.
- Cleanup owed: remove only disposable task-owned QA artifacts; retain evidence,
  user projects and shared build caches. Document actual verified platforms.

## Verification gates

- Use Swift Testing for compiler, scene/runtime and editor tests. Run focused
  suites per slice, then the owning target. Use a task-local scratch path on any
  shared-toolchain cache mismatch; never remove the user's `.build`.
- Shader/rendering slices run `python3 script/ensure_tint.py --check` and
  `script/validate_webgpu.sh` from the engine root with compatible Swift/Swan/Dawn.
  Add 3D GPU cases under the serial `Render3DGPUTests` suite; run Metal golden
  frames and inspect mismatch images before changing references.
- Measure ordinary sprite batching/instancing and relevant 3D benchmark timings
  on a quiet machine. Record baseline and changed results; do not infer performance
  from apparent smoothness or run other GPU work during benchmarks.
- Every UI slice updates both localization catalogs and runs
  `python3 ../script/check_studio_localization.py` plus `EditorLocalizationTests`
  from Editor. Exercise the real AdaUI event/renderer path and a real project.
- Build and launch native Studio on macOS for the end-to-end flow. When shared
  changes affect iOS, launch the affected app in iOS Simulator and report mobile
  launch/runtime evidence separately. Windows/Linux validation is separate and
  must not be inferred from a macOS build; native WebGPU proves no browser UI.
- Before any PR: measure its actual reviewable diff, run `git diff --check`,
  inspect the intended files, and update this map with evidence and remaining
  blockers. No publication or CI success is claimed from local tests alone.

## Decision log

- 2026-10-20: User explicitly requested uninterrupted implementation through all
  functionality and checks. Continue the approved sequence using separate local
  commit/branch boundaries; do not stop after each slice or require repeated
  approval. Public PR creation/merges remain outside this local delivery.
- 2026-10-20: Slice 2 produces GLSL, stable parameter/texture binding metadata and
  node/port source maps. Real fresh SPIR-V compilation passes for both graph
  targets; 21 graph tests pass. glslang initialization/finalization is protected
  by one process-wide lock for all existing ShaderCompiler callers.

- 2026-10-20: User selected 2D and 3D outputs and native Studio first, then
  approved the proposed typed-IR/AdaUI direction and requested implementation.
- 2026-10-20: Repository discovery confirmed existing ShaderCompiler/Material
  APIs, stock sprite pipelines, fixed PBR variants, workbench split documents and
  editor localization. No Shader Graph implementation or prior map was found.
- 2026-10-20: Proposed additive integration and the boundaries above. The TBD
  skills require approval of the concrete map before implementation; this is
  distinct from the architecture approval already given.
- 2026-10-20: User approved the entire map and integration without a shared
  feature flag. Started slice 1 on `codex/shader-graph-core`.
- 2026-10-20: Slice 1 is implemented locally in 550 reviewable lines, including
  tests. It adds `ShaderGraph`, `ShaderGraphAsset`, typed diagnostics and a
  deterministic reachable IR. Remaining slices and the additive strategy still
  apply; no PR, merge or release has been published.

## Evidence

- Slice 9: 10 document/Inspector/localization tests pass. One drag produces one
  Undo, metadata-only moves do not change shader revision, selection survives
  history, invalid wires produce no Undo, incomplete intermediate nodes can be
  connected, and external/future-version files cannot be overwritten.
  Log: `/tmp/adaengine-shader-graph-document-tests.log`.
- Public port metadata is shared by authoring and validation. Optional labels,
  texture defaults, groups and notes extend v1 decoding compatibly; layout-only
  metadata stays out of lowered shader computations.

- Slice 8: 29 tests in 7 suites pass, including actual Metal directional and
  point-light alpha clipping, equality against hiding the same caster, matching
  depth images, actual temporal/motion encoding, texture/parameter changes,
  stock golden frames, core validation and immutable binding snapshots. Log:
  `/tmp/adaengine-shader-graph-alpha-final.log`.
- Masked graph revisions participate in both scene-wide and per-face shadow
  digests. Opaque graph materials retain the stock shadow/motion fast paths.
- Point-light testing caught a fragment UBO collision with LocalShadow's slot
  28. The final resource contract below fixes it. Tests remain enabled and static
  face reuse is retained; temporary debugging code was removed.

- Slice 7: actual Metal verifies roughness values in the G-buffer, runtime value
  changes, texture replacement through the production material bindings, and
  byte-identical restoration when removing the graph. Imported model overrides
  are independent per instance and never mutate the asset's original materials.
  Log: `/tmp/adaengine-shader-graph-pbr-tests.log` (2 tests, 3 suites).
- Native Editor's PBR/Inspector/model/localization checks pass (19 tests, 4
  suites), log `/tmp/adaengine-shader-graph-editor-pbr-tests.log`.
- Portable bindings (corrected during slice 8): all graph resources use group 1.
  Uniforms use binding 24, textures start at binding 48, and the shared sampler
  uses binding 14. Native fragment slots avoid LocalShadow (28), LightTiles (27)
  and stock samplers; descriptor groups separate View/Skinning on WebGPU.
  Texture/uniform/sampler snapshots are created atomically and remain immutable.

- Slice 6: `Render3DGPUTests/DebugViews/everyViewMatchesItsGoldenFrame` passes
  on actual Metal after the surface-function extraction, comparing all existing
  debug views with their checked-in golden frames. No references were changed.
  `script/ensure_tint.py --check` passes. Log:
  `/tmp/adaengine-shader-graph-pbr-golden.log`.

- Slice 5: the native Editor builds; 10 tests across Graph Inspector, localization
  and existing Sprite layout suites pass. The localization checker passes for
  2426 messages in each language. Graph assignment and numeric/color overrides
  use structured scene payloads and existing Inspector controls/transactions.
- Editor's existing lockfile required automatic resolution (including the
  previously missing PartialJSONDecoder dependency). Keep that incidental
  `Editor/Package.resolved` change out of feature commits and restore its baseline
  before delivery; the scratch workspace records the versions used for checks.

- Slice 4: 39 graph/Sprite tests pass. Real SpriteRenderSystem scheduling preserves
  A/B/A material order and three batches while both instances reuse one compiled
  pipeline. Both expanded and instanced templates have graph integration; GPU
  pixels are still required by the final acceptance gate.

- Slice 3: 23 graph tests pass, including independent material instances,
  Codable round trips and immutable per-device uniform snapshots. Changing an
  instance does not overwrite GPU bytes retained by a previous frame.

- Slice 1: `swift test --scratch-path /tmp/adaengine-shader-graph-build
  --disable-automatic-resolution -j 4 --filter ShaderGraphTests` passed:
  19 tests. The same scratch path's `--filter AdaRenderTests` run then passed
  190 tests across 31 suites, including the final asset-preservation assertion.
- The asset test uses real `AssetsManager.save`/`loadFresh`, verifies metadata and
  preserved graph contents, and confirms a rejected future-version file is not
  rewritten. CPU tests include explicit broadcasts, conflicting parameter
  declarations, unknown operations, typed texture sampling, disconnected nodes,
  deterministic ordering and a 4096-operation shared chain without recursion.
- Strict SwiftLint passed for all three new production files; `git diff --check`
  passed. Validation used Swift 6.3.3 with Swift 6 language settings and isolated
  scratch/module caches. SwiftPM required sandbox escalation to run its manifest
  sandbox; no shared `.build` was created, cleaned or rewritten.
- Logs: `/tmp/adaengine-shader-graph-final-focused.log` and
  `/tmp/adaengine-shader-graph-owning-tests.log`. The owning-target run includes
  existing Metal shader tests; this is not graph GPU rendering evidence.
- Graph-generated GLSL/WGSL, GPU pixels, Studio UI/app interaction, mobile,
  Windows/Linux and exported-game validation remain for their corresponding
  slices. No claim of a working Shader Graph editor is made by slice 1.

### WebGPU auto-layout prerequisite (during canvas work)

- Native Dawn auto-layout prunes resources unreachable from a shader entry point.
  Pipeline binding layouts now follow the generated WGSL call graph; empty groups
  are not submitted. Original SPIR-V member metadata remains available to materials.
- Fresh Tint/WebGPU graph PBR parameter/texture and directional/local alpha-shadow
  pixel checks pass (`/tmp/adaengine-shader-graph-webgpu-focused.log`).
- WGSL reflection reachability tests and stock WebGPU debug-view golden frames pass
  (`/tmp/adaengine-shader-graph-webgpu-reflection.log`).
- The full WebGPU script additionally exposed an existing unequal Metal/WebGPU
  golden-reference filename inventory; this is tracked separately from passing
  graph pixels and is not waived by the focused checks.

### Authoring integration refinement

- Canvas drawing and pointer interaction (10–11) remain one review-sized local
  unit. The document registration is split into 12a (node presentation/templates)
  and 12b (workbench/UI registration), with the standalone preview helper (13)
  built before 12b. This keeps registration complete when it is introduced and
  avoids a placeholder preview or a feature flag. All parts remain in scope.

- Canvas + graph/workbench/localization validation: 18 tests in 5 suites pass,
  including actual AdaUI pointer events and one-step movement Undo
  (`/tmp/adaengine-shader-graph-workbench-tests.log`).

- Preview/compiler/resource reload: 32 CPU and real WebGPU tests pass
  (`/tmp/adaengine-shader-graph-preview-core-gpu.log`). Graph source diagnostics
  use virtual source 101 to preserve node/port mapping across target templates.
  New material instances read freshly saved graph assets; existing instances keep
  their authored values. Background preview validation is CPU-only.

- Slice 14: Time, procedural integer-hash 2D value noise, scalar/vector math and
  explicit vector channels/composition; Dissolve and UV Scroll use ordinary nodes.
  Static graphs ignore clock changes; animated graphs use a world-relative clock
  and preview transport takes explicit ownership. Persistent validation logs:
  `.shader-graph-effects-tests.log` (32 CPU/GLSL/WebGPU tests),
  `.shader-graph-editor-tests.log` (22 authoring/UI/localization checks).
