# AdaUI and AdaEditor Performance Technical Debt

Last updated: 2026-08-26

## Context

AdaEditor previously dropped to approximately 10 FPS while displaying a large build failure. Two independent regressions were fixed:

- the macOS display-linked frame loop now processes AppKit events before every world update;
- compiler output is no longer rendered through the compact workspace footer, and individual output lines are bounded and horizontally scrollable.

The production Editor application builds and launches. A bounded runtime smoke sample of the current project reported 60.39 FPS, 16.56 ms mean frame time, and 0.41 ms mean `UIRenderNode` time. This is not a representative large-UI benchmark and must not be used as a general performance claim.

## Open debt

### P1: Add a reproducible large-Editor benchmark

Current profiling covers only the currently open, relatively light project and a short nine-frame sample. It does not reproduce the original 10-15 FPS workload.

Work:

- define a real filesystem project with a large hierarchy, long source files, diagnostics, inspector content, and an active scene;
- record idle, scrolling, hover, selection, build-output, and scene-update phases;
- capture at least 300 steady-state frames per phase, including p50/p95/p99 frame time, CPU/GPU time, allocations, resident memory, tessellation work, cache hits, and dropped frames;
- compare 60 Hz and 120 Hz displays where hardware is available;
- keep the fixture representative of production Editor usage; do not seed an empty user project with demo content.

Done when:

- the benchmark runs repeatably from a documented command;
- results are stored as a machine-readable baseline;
- CI or a scheduled performance job detects material regressions;
- acceptance budgets are agreed for idle, interaction, and heavy-scene workloads.

### P1: Bound and virtualize the complete build-output pipeline

Individual `EditorWorkspaceLogLine` values are capped, but the number of retained and rendered lines remains unbounded. A sufficiently long build can still grow memory, layout, accessibility, and hit-testing work.

Work:

- replace the unbounded output collection with a configurable ring buffer;
- virtualize visible rows instead of constructing every `Text` node;
- batch process output updates so every incoming line does not independently invalidate the UI;
- store full raw build output in a bounded file or explicit build artifact when it must remain available;
- replace `EditorWorkspaceStatus.failed(String)` with structured compact state so large output is not duplicated in status memory.

Done when:

- output memory remains bounded during multi-megabyte builds;
- only visible rows participate in layout and rendering;
- full diagnostics remain discoverable without entering compact status chrome;
- a stress test proves stable frame time while output is streaming.

### P1: Make frame-loop failures recoverable and observable

An exception from `appWorlds.update()` currently ends the frame task and presents the full `localizedDescription` in an alert. This can leave a drawn but non-updating application and can create another pathological text surface.

Work:

- emit a bounded structured error before presenting UI;
- limit alert text and provide an explicit way to inspect or export details;
- define whether the world can recover, restart, or must terminate;
- expose frame-loop health through profiler/telemetry state;
- add a test that injects an update failure and verifies the selected lifecycle policy.

Done when:

- a failed frame cannot silently leave the Editor frozen;
- error details are retained without rendering an unbounded alert;
- runtime telemetry clearly reports stopped, recovering, or terminated state.

### P2: Add a native macOS input integration test

Unit coverage verifies click, hover, drag, scroll, hit testing, window routing, and event-before-update ordering. There is no automated end-to-end test that posts an AppKit/CoreGraphics event into a production window and observes the resulting Editor state.

Work:

- launch a temporary real project outside protected user folders;
- post native mouse move, click, drag, and scroll events;
- assert hover transitions and a visible document-selection state change;
- avoid dependence on persistent Documents/Desktop privacy permissions;
- run the test against both display-linked and fallback pacing paths.

Done when:

- CI can catch removal or starvation of `processEvents()`;
- the test proves the complete platform event to AdaInput to AdaUI action path.

### P2: Audit actor isolation and frame scheduling

The current regression was missing event pumping, not a demonstrated Swift Concurrency race. However, platform events, display-link callbacks, world updates, rendering, and Editor model mutations cross several scheduling boundaries without a documented isolation contract.

Work:

- document which stages are `@MainActor`, world-isolated, render-thread-owned, or lock-protected;
- audit `Task` captures, cancellation, display-link replacement, and continuation shutdown;
- verify that no synchronous main-actor work blocks input for an entire long frame;
- add signposts for event queue age and time from native event receipt to AdaUI dispatch;
- remove or justify every relevant `@unchecked Sendable` and unsafe nonisolated access.

Done when:

- the ownership model is documented next to the frame pipeline;
- Thread Sanitizer and strict-concurrency validation find no relevant race;
- interaction-latency telemetry distinguishes queueing from update/render cost.

### P2: Remove SwiftPM plugin deprecation noise

Texture-atlas plugins still use deprecated `Path` APIs such as `tool.path`, `directory`, `pluginWorkDirectory`, and string-based URL conversion. These warnings greatly inflate build output and make real diagnostics harder to find.

Work:

- migrate plugins to URL-based PackagePlugin APIs;
- keep command inputs and outputs deterministic across macOS, Linux, and Windows;
- add focused plugin build validation.

Done when:

- a clean build emits none of these PackagePlugin deprecation warnings;
- generated atlas/font outputs remain byte-for-byte or semantically equivalent.

### P2: Establish Editor memory budgets

The latest smoke sample reported an approximately 826 MB resident footprint, but no clean-launch or workload baseline exists, so the number cannot yet be classified as a regression.

Work:

- measure clean launch, indexed workspace, large scene, long build output, and repeated open/close cycles;
- attribute retained memory to source models, text layouts, render layers, textures, build logs, and package tooling;
- verify cache eviction and window/project teardown;
- define warning and failure thresholds per workload.

Done when:

- repeatable baselines exist for each workload;
- closing a project releases workload-specific memory within an agreed tolerance;
- automated checks detect sustained footprint regressions.

### P2: Stabilize full parallel validation

A previous full parallel run observed a timing-sensitive `ViewVisibilityTests.task_restartsOnReInsertion` failure even though the test passed in isolation. Focused UI and Editor suites are green, but full-suite reliability remains incomplete.

Work:

- replace wall-clock assumptions with deterministic frame advancement;
- rerun the entire suite repeatedly under parallel execution;
- separate genuine concurrency failures from shared-machine timing variance.

Done when:

- repeated `swift test --parallel` runs pass without timing-only retries;
- the focused performance and input suites remain green.

## Current verification baseline

- production AdaEditor Xcode build: passed;
- focused input, hover, hit-test, gesture, and frame-pump tests: 25 passed;
- focused AdaEditor UI tests: 34 passed;
- `git diff --check`: passed;
- short live sample: 60.39 FPS, 16.56 ms mean, 27.69 ms maximum frame time;
- short live `UIRenderNode` sample: 0.41 ms mean, 0.85 ms maximum;
- independent review found no clipping or retained-layer-cache regression explaining the reported overflow.

## Suggested order

1. Build the reproducible heavy-project benchmark.
2. Bound and virtualize build output.
3. Make frame-loop failure handling recoverable and observable.
4. Add native input integration coverage and concurrency latency instrumentation.
5. Remove plugin warning noise and establish memory budgets.
6. Stabilize the full parallel suite.
