# Browser agent autonomy — PR Decomposition Map

- **Created:** 2026-10-20
- **Epic reference:** [Acceptance requirements](../../../Documentation/AgentAutonomy.md)
- **Trunk:** main
- **Size budgets:** target <=600 reviewable lines, cap 1000; generated catalogs,
  fixtures and Markdown are excluded. Existing unrelated working-tree changes
  remain outside these slices.
- **Approval:** user approved all seven slices without a shared feature flag on 2026-10-20.
- **Delivery:** local implementation and evidence first. No publishing, merge or
  deployment is requested by the user.

## Slices

| # | PR title | Purpose | Strategy | Size budget | Depends on | Status |
|---|----------|---------|----------|-------------|------------|--------|
| 1 | Rank browser documentation sections | Return relevant, readable sections for English/Russian authoring queries. | Complete replacement of the existing search/read handlers with compatibility for article IDs | ~500 | — | implemented; local retrieval checks pass |
| 2 | Export browser authoring contracts | Produce a versioned, native-verified description of all supported built-ins and input codecs. | Additive export and parity tests before mutation handlers consume it | ~550 | — | implemented; native export and parity checked |
| 3 | Make authoring edits diagnostic and atomic | Validate named input bindings and scene operations before changing the document. | Self-contained handlers; preserve legacy saved encoding and Undo | split 3a–3c | 2, 4 | implemented; focused atomicity checks pass |
| 4 | Discover script components and APIs without a working scene | Expose compiled project schemas and structured API/member lookup independently of scene loading. | Additive Player inspection operation, then browser handler replacement | ~550 | 2 | implemented; native parser exercised in WASM |
| 5 | Ship complete browser examples and recipes | Export runnable scene/configuration/source examples with accurate host capabilities. | Self-contained resource export; remove incomplete source-only example path | ~550 | 2, 4 | implemented; all four examples checked in real WASM |
| 6 | Return revision-bound runtime feedback | Feed validation and runtime failure back to the owning agent turn and preserve the last valid state. | Complete change/result path with stale-revision guards | ~500 | 3, 4 | implemented; revision guards and recovery checked |
| 7 | Prove autonomous authoring and repair | Add reproducible evaluations and run local Codex through real browser/Player authoring and recovery. | Separate QA harness; no test hooks in the production app | ~500 | 1–6 | complete locally; live Codex authoring, own repair and final Play verified after host fixes |

## Review boundaries within part 3

Implementation exposed separate review units within the approved atomic-authoring
part; the seven capability parts and the no-shared-flag decision are unchanged.
Producers ship before their consumers. No PR has been opened or published.

| Unit | Boundary | Approximate review size | Dependencies |
|---|---|---|---|
| 3a | Named input encoding and lossless scene integer codec | <=600 lines including focused tests | 2 |
| 3b | Component/operation/runtime schemas and native value preflight | <=1000 lines including focused tests | 2, additive Player bridge |
| 3c | Staged source/scene transaction and guarded tool integration | <=600 lines including transaction tests | 3b, 4 |

## Scope and checks

### 1 — Search

- In scope: section index, exact symbols, weighted lexical ranking, small
  authoring synonym vocabulary, bounded match excerpts, section read references.
- Out of scope: hosted embeddings and extra paid search requests.
- Ships safely because existing article IDs remain valid and the replacement
  is covered by positive/negative relevance cases before it is enabled.
- Cleanup owed: remove the old whole-article matching/excerpt path in this slice.

### 2 — Authoring contract

- In scope: native codec/component contract export, version/hash, supported
  features, defaults and fields; completeness/parity checks against Player.
- Out of scope: adding unsupported runtime components.
- Ships safely because export is additive until its consumers are updated.
- Cleanup owed: template-derived component defaults are removed in slice 4.

### 3 — Atomic edits

- In scope: explicit operation/input schemas, lossless canonical encoding,
  structured field diagnostics, staged validation and unchanged Undo on failure.
- Out of scope: arbitrary native scene support.
- Ships safely because each rejected operation leaves the existing project
  unchanged; coordinated edits and existing project loading remain supported.
- Cleanup owed: remove unchecked configuration/operation assignments here.

### 4 — Introspection

- In scope: built-in and dynamic component descriptions, structured static API
  catalog, type/member search and inspection while the scene is invalid.
- Out of scope: SourceKit, shell and external MCP.
- Ships safely because the Player inspection operation is additive and old
  clients continue to load; browser switching happens after parity tests pass.
- Cleanup owed: remove raw compiler-source fallback and template-only catalog.

### 5 — Examples and docs

- In scope: minimal keyboard, script-component and scene examples; browser
  adaptation of the runner; exact JSON/operation recipes and capability notes.
- Out of scope: claiming native HUD/runtime features work in Web Player without
  their implementation and verification.
- Ships safely because examples are checked as complete browser projects.
- Cleanup owed: remove the incomplete native-source export and duplicate recipes.

### 6 — Feedback

- In scope: revision-bound operation/build diagnostics, asynchronous preview
  feedback, useful repair context, stale response protection and last valid frame.
- Out of scope: turning a save into an implicit paid agent retry.
- Ships safely because feedback remains attached to the originating project/turn
  and a runtime failure cannot commit a partially validated edit.
- Cleanup owed: replace ambiguous success messages in changed handlers.

### 7 — Acceptance

- In scope: deterministic contract/search/repair tests and live local Codex
  authoring with visible Player/input evidence; document limitations honestly.
- Out of scope: funded hosted inference and unrelated UI redesign.
- Ships safely because the harness is separate from production execution.
- Cleanup owed: remove only task-owned temporary QA projects if disposable;
  preserve user projects, chat, drafts and shared caches.

## Integration decision

Recommended: complete, independently enabled corrections in the order above;
additive contract/introspection producers precede consumers. No feature toggle
is needed for a complete corrected handler. Alternative: a single browser agent
capability-version gate covering the new handlers, with a separate removal slice;
this keeps two implementations and postpones user-visible improvements.

## Decision log

- 2026-10-20: Investigation reproduced inaccurate search excerpts, a five-type
  template catalog, incomplete runner export and accepted invalid `space` input.
  The current 22-article catalog is fresh; regeneration alone does not solve it.
- 2026-10-20: Captured the complete autonomy objective and acceptance evidence;
  implementation awaits approval of these review boundaries and integration choice.
- 2026-10-20: User approved the seven-part map, with complete corrections enabled
  separately and no shared feature flag. Began section search and relevance tests.

## Evidence

- Baseline: `python3 scripts/update-offline-documentation.py --check` passed.
- Baseline: `node --test WebUI/test/agent-resources.test.mjs` passed (one export
  filesystem test; it does not test completeness or search relevance).
- Baseline: `npm --prefix WebUI test` passed, 126/126 tests.
- Native baseline: matching Swift 6.3.2 toolchain and WASM SDK are installed.
  `EditorAgentExampleTests` did not reach compilation: SwiftPM detects the
  existing `Package.resolved` is stale because `PartialJSONDecoder` was added.
  No shared caches or lockfiles were deleted or rewritten. Resolve this in an
  isolated validation setup before claiming native parity.
- Implementation and live acceptance: pending.
- Native codec probe (isolated, no package or lockfile edits): compiled the exact
  current InputAction/InputBinding declarations and input enums with Swift 6.3.2.
  All 146 binding variants round-tripped: 107 keyboard values, three mouse
  buttons, 16 gamepad buttons, both directions of six gamepad axes, scroll,
  motion and touch variants. The production decoder reproduced the exact
  `KeyCode` corruption for `space`; canonical Space is `" "`.
  Artifacts and source SHA-256 hashes: `WebUI/.local/autonomy-codec-probe/`.
- Production browser configuration dispatch accepted both the native canonical
  Jump action and the invalid `space` value in isolated documents. This is a
  confirmed parity failure, not proof of acceptance. Fixture:
  `WebUI/.local/autonomy-codec-probe/browser-parity-baseline.json`.
- Added twelve concrete retrieval evaluation cases to the acceptance document;
  these require useful ranking and excerpts, not merely a nonempty result.
- Slice 1 local implementation: ranked section search, English/Russian authoring
  terms, matching excerpts, stable section IDs and paginated section/article reads
  are wired into the real tools. Exact unknown symbols return an honest empty
  result. Seven focused retrieval tests pass; all 133 WebUI tests, the frontend
  build and localization source check pass. No provider inference was used for
  this deterministic retrieval check. Live agent acceptance remains in slice 7.
- Native dependencies resolved successfully in an isolated copy of the package;
  the primary package and engine lockfiles remain unchanged. Added the
  noninteractive `agent-resources --output <file>` CLI exporter and focused Swift
  tests. Compilation and exporter runtime proof are pending; frontend consumers
  still use the existing contract until the producer is verified.
- Slice 2 producer proof: the native CLI exported all 12 supported component wire
  types, 146 input bindings and 26 compiler API types. Both focused Swift tests
  pass, including native decoding of the exact 64-bit collision mask and real CLI
  export without a project. The checked-in generated snapshot fingerprints 489
  source/fixture files; browser builds reject stale fingerprints. All 135 WebUI
  tests and the frontend build passed after adding snapshot verification.
- Slice 3 input path: added `editor_input_describe`, native-name encoding and
  field diagnostics. Configuration calls, whole metadata writes and file patches
  reject invalid input before committing. Five focused tests cover all 146 native
  bindings, invalid inputs, duplicates, unchanged Undo on failure and saved
  canonical data after reopening. Scene/schema validation and coordinated
  source/component edits are still outstanding in this slice.
- Additional codec finding: Environment3D is defined in AdaCorePipelines but uses
  the established AdaRender wire key in Player. Export maps this alias explicitly.
  Physics masks exceed JavaScript's exact integer range: the contract preserves
  exact JSON text and decimal strings. Lossless scene editing remains required
  before component-default consumers can be considered complete.

- Current implementation: source-defined components come from the production
  AdaScript schema parser in fixed Player, independently of loading the scene.
  Built-in and member API lookup use the verified native catalog. Four focused
  browser tests and two compiler-core tests cover source ownership, defaults,
  caching, missing bridge and stale responses. This is source-schema validation;
  full compilation remains a separate Player build.
- Atomic edits now stage source/configuration/scene changes in one ordinary Undo
  transaction. Whole-file scene/config writes, patches and legacy scene tools use
  the same validation. Unknown fields/types, vector sizes, enum cases, missing
  dependencies/assets, runtime shape errors and native codec failures reject
  before commit. `editor_project_apply` can declare and attach a new component
  together. Input/code/file changes during asynchronous validation reject stale
  results. Signed Int fields follow wasm32 limits; explicit UInt64 collision
  masks retain the full native range.
- Full examples: four native-generated project fixtures are adapted at build time;
  the runner includes three actual WAV files from the native sound generator.
  Browser import includes text and binary assets in one Undo transaction.
  Unsupported HUD bindings are removed explicitly; phase/score appear in logs.
  Keyboard movement queries PlayerState + Transform so its camera stays fixed.
  Native example cameras were facing away from geometry; their authored Z
  positions (and runner sound listener positions) are corrected at the producer.
- Native validation: all four exported browser projects and the exact movement
  snippet returned by documentation passed the native CLI `validate` command
  with `metadata,adascript,entry-scene,runtime-bindings` scope. This does not
  establish visible rendering or paid-provider operation by itself.
- Feedback: accepted and failed loads carry content generation and scene revision.
  Late responses for changed sources/projects cannot overwrite current feedback.
  Asynchronous script diagnostics carry the accepted iframe revision. Mutation
  batches feed the current result back to the same agent conversation. Failed
  candidate loads retain the existing scene; error UI no longer covers it fully.
- Separate browser QA: `python3 WebUI/scripts/check-agent-player.py` serves only
  bundled fixtures on localhost:38080 and the production fixed WASM Player on
  127.0.0.1:38081. It adds no QA hooks or routes to the main application and has
  no Cloud credentials. CUA controls exercise the normal Player protocol.
- Real WASM proof: keyboard movement loads and 500 ms of ArrowRight moves the
  reference sprite exactly 60 pixels (bounds x=564..643 to x=624..703), matching
  120 units/second. Pixel measurement and before/after screenshots are under
  `WebUI/.local/cloud/screenshots/autonomy-keyboard-*`.
- This exposed an actual automation input defect: DOM canvas focus did not
  activate the native scene viewport. Bounded agent keyboard input now targets
  the game's Input resource directly; ordinary browser focus routing is retained.
- Real WASM runner proof: visible bird/pipes/ground, Space changes phase 0 to 1,
  and an invalid `space` enum is rejected while retaining the last scene. Source
  inspection still returns six component schemas after that failed load; native
  PhysicsBody2D decoding accepts the exact UInt64.max payload. Reloading the
  repaired fixture succeeds in the same iframe/WASM instance. Artifacts:
  `autonomy-runner.png`, `autonomy-invalid-retains-frame.png`,
  `autonomy-recovered-runner.png` and `autonomy-native-schema-browser.json`.
- Local Cloud blocker: RediStack's default connection lease deadline is 10 ms,
  confirmed in the linked dependency source. Cold pools sporadically returned
  RedisConnectionPoolError and HTTP 500 despite a healthy Redis PING. The
  neighboring service checkout's CloudRuntime/Server.swift now uses a bounded
  five-second lease timeout; its local binaries were rebuilt and restarted while
  preserving the existing PostgreSQL/Redis/object state.
- The user opened a fresh HTTP tab and authorized testing there. Authenticated
  Local Codex created a separate QA project through the ordinary Create composer;
  the brief described a purple-square/star-collection game without API/JSON hints.
  It discovered recipes, input bindings and API/component schemas, authored 11
  entities and gameplay sources, and started the real WASM Player. It diagnosed
  an ECS row-access error from runtime logs and repaired its own source code.
- Final local checks for this implementation turn: 164/164 WebUI tests pass;
  frontend build passes; localization source check finds 692 explicit messages;
  shared catalog/placeholder check passes for 2422 en/ru keys. The latest six
  focused native contract/localization tests pass. The snapshot fingerprints 540
  current native source files, including AdaScripting codec implementations.
- All four adapted examples have now been loaded through the real production
  WASM Player protocol. The Counter example emits increasing values in Play logs;
  basic 3D displays its cube with the corrected camera. The native verification
  command is repeatable: `python3 WebUI/scripts/check-agent-player.py
  --verify-native <AdaEditor>` (four projects pass). Default `editor_docs_read`
  recipes are generated from the same browser contracts; the old native HUD
  recipe and unused raw compiler-source payload are no longer shipped there.
- Field capability details: ordinary Int values use wasm32 signed bounds;
  explicit UInt64 masks remain lossless. Script entity-reference fields are
  declared as runtime-default-only rather than advertised as writable scene IDs.
  Default entity references are omitted from the wire payload, retaining the
  native runtime descriptor's default instead of causing its read-only decoder
  to reject the component.
- Additional feedback regression checks: a retained frame from a rejected newer
  generation cannot be used as current input/capture evidence. Input, logs and
  build responses include generation/rendered-generation metadata. Long Unicode
  logs and runtime diagnostics are bounded before entering model context.
  Component error envelopes and field explanations both follow mounted language
  changes.
- Scoped `git diff --check` passes for task changes. A whole-worktree invocation
  reports pre-existing whitespace in the unrelated Box2D changes; those files
  are preserved. Both primary Package.resolved files remain unchanged. No commit,
  PR, publish, production deployment or paid hosted inference was performed.
- The first live run exposed three host defects: shared workflows proposed the
  forbidden Design/ folder; opening RuntimeConsole crashed React through a
  shadowed active variable in its effect; asset validation rejected existing
  resource-relative texture paths. Bundled guidance now uses Docs/Design/ and
  Docs/Generators/ (user workflows are untouched), returning project context
  includes those notes after ZIP/reopen, the console mounts/polls/pauses in a
  regression test, and existing asset paths normalize to native @res:// form.
  Missing/traversal/remote references still reject atomically.
- The first run correctly reported incomplete verification after the shell
  failure. Its saved QA project was reopened with the fixed build; Local Codex
  GPT-6.1-Sol was selected again and received only a normal continuation request
  to finish and verify movement/collection/loss/win/restart. No developer supplied
  missing JSON/API calls or edited the QA game's source. This is an interrupted
  creation run plus a successful continuation after host repairs, not a claimed
  clean first-attempt run.
- Live acceptance succeeded on the final game, not just its initial primitives:
  29 authored entities, sprites, sprite-based instructions/score/result banners,
  and three WAV sound cues. The agent itself used real key input and inspected
  frames/logs: five STAR COLLECTED events, VICTORY, R reset, FAIL on a red obstacle,
  and R reset again. It repeated those scenarios after adding the HUD sprites.
  Its final log tool result has empty diagnostics, generation/renderedGeneration
  6, currentFrame true and sceneRevision
  `5aa3665bc797aa0028eb82ac98c8f05c7712b77dc5e65f10519be33ff84746d6`.
  A notes-only edit then advances generation 7 with the same scene revision.
- Independent native CLI validation of the UI-downloaded QA ZIP passes:
  `AdaEditor --ada-studio-cli validate --project
  WebUI/.local/cloud/autonomy-live-project --format json` reports 16 sources,
  seven systems, scope metadata/adascript/entry-scene/runtime-bindings, no
  diagnostics and exit 0. ZIP, extracted project and report are retained at
  `WebUI/.local/cloud/autonomy-live-project.zip`, `autonomy-live-project/`, and
  `autonomy-live-native-validation.json`.
- Browser evidence is retained under `WebUI/.local/cloud/screenshots/`:
  `autonomy-live-collection.png`, `autonomy-live-acceptance.png`,
  `autonomy-live-final.png`, `autonomy-live-acceptance.txt`, and
  `autonomy-live-final-conversation.txt`. The QA project is left open in Play.
  Sound references and native validation are proven; physical audio listening
  was not performed and the agent's final report states that limitation.
- Final checks after live-discovered fixes: 166/166 WebUI tests pass, frontend
  build passes, 692 explicit WebUI localization messages and 2422 shared en/ru
  keys pass their checks, and scoped diff whitespace checks pass. The six native
  contract/localization tests and four real WASM examples remain unchanged from
  their successful runs above. All seven approved parts are now complete locally;
  no commit, PR, publication, production deployment or paid hosted inference was
  performed. This bounded game/repair evaluation does not claim that arbitrary
  games or unsupported browser capabilities work autonomously.
