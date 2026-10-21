# Box2D feature coverage — PR decomposition map

- **Created:** 2026-10-20.
- **Request:** add all four groups selected in this chat: joints/mechanisms, additional 2D colliders, spatial queries, and a 2D character controller including mover/pogo support.
- **Approval:** approved by the user on 2026-10-21 ("делай"); strategy A.
- **Trunk:** `main` (`origin/main` observed at `5b6085790a14fa8a7461804e53c7ae3547f3b543`).
- **Checkout inspected:** `codex/shader-graph-effects`, HEAD `22dcd4a0c9bcdb23a4446cf4249a52119a4baa35`.
- **Baseline:** the inspected physics sources, physics tests and `Demos/Physics2D` have no committed differences between this HEAD and `origin/main`. Existing Shader Graph / Editor work is unrelated and must be preserved.
- **Isolation:** implementation should use a managed Git worktree/branch based on the verified physics baseline, rather than changing the active Shader Graph branch or its dirty files. Revalidate the base before creating it.
- **Size metric:** added + removed reviewable lines, including tests and demo source. Target <=600 per slice; hard cap 1000. Markdown, generated artifacts and vendored Box2D do not count. Estimates below are budgets, not measured diffs.

## Evidence and starting point

- `Shape2DResource` represents circle, box and polygon. Its box angle argument is ignored; the circle/box offsets are not applied by `BoxShape2D.makeShape`.
- `PhysicsJoint2DDescriptor` describes rope/revolute, but `Physics2DSyncSystem.update` only syncs bodies and collision entities. Its joint query is unused.
- `PhysicsWorld2D` has working finite-segment and directed-ray queries; collision/sensor begin/end and impact events already have regression tests. Preserve these semantics.
- Box2D 3.2 headers expose distance, filter, motor, mover, pogo, prismatic, revolute, weld and wheel joints; overlap/cast and character-plane APIs are already vendored.
- The engine has a 3D capsule character controller that establishes naming and fixed-step conventions. Its implementation is not a substitute for testing the 2D Box2D paths.
- No existing decomposition map for this work was found. `docs/` is ignored as a generated-docs destination, so this map lives with the tracked technical documentation under `Documentation/`.

## Capability inventory and scope

1. Correct local offsets/rotation for supported 2D shapes; retain existing serialized geometry and documented compatibility.
2. Capsule colliders, rounded boxes and rounded convex polygons.
3. Standalone segments, open chains with ghost vertices, closed chains, and loose chain segments; explicit winding and one-sided collision semantics.
4. Real ECS-managed joint creation, deferred resolution, native lifetime and removal, including bodies spawned/removed/recreated after the joint entity.
5. Distance/rope and revolute constraints with anchors/frames, springs, limits and motors where supported.
6. Prismatic, weld, filter, wheel/suspension and motor joints, with their supported tuning and runtime controls.
7. Break thresholds and world-local joint-break events, with explicit removal behavior and safe invalid-handle handling.
8. Native mover and pogo joints exposed as usable joints, followed by a dynamic character-controller mode using them.
9. Overlap queries for point, AABB and convex shapes; collision masks, sensor inclusion policy and stable entity/shape identification.
10. Convex shape casts for circle/capsule/box/polygon; nearest/all hits, distance ordering and initial-overlap semantics.
11. A capsule-based 2D character controller: horizontal motion, acceleration/braking, gravity, jump, grounded state, slopes, ground snap, ceilings/corners and teleport reset.
12. A dynamic controller mode: pushing/interacting with rigid bodies, moving-platform support and bounded mover/pogo settings.
13. Production-path Swift Testing coverage, backwards-compatible serialization, documentation and runnable demos for all four groups.

Out of scope for this request: a new 3D controller, snapshots/replay, double precision, wind/material extensions, custom Studio inspector panels, new AdaScript bindings, website deployment and unrelated renderer/Shader Graph work. The ordinary Swift/ECS APIs and serialized components must remain usable without those additions.

## Integration choice for approval

**A — additive, complete capabilities (recommended).** Extend `Shape2DResource` and `BoxShape2D.makeShape`; add query methods on `PhysicsWorld2D`; register a completed joint system and completed controller systems through `Physics2DPlugin.setup`. New systems act only on their associated components. Each slice supplies a working API, native implementation and tests together. Existing factory signatures and descriptor decoding remain supported. This needs no feature flag or later flag-removal work.

**B — introduce a backend abstraction first.** Add a `Physics2DBackend` seam with shape/joint creation, overlap/cast and character-movement operations. Route `Body2D.appendShape`, `PhysicsWorld2D` queries and `Physics2DSyncSystem` through a Box2D implementation before extending it. This permits an alternative backend later, but adds migration slices and touches working paths even though this request keeps Box2D. This alternative requires revising the slice table before implementation.

Approval of this map includes choosing A unless the user chooses a different strategy. No default-off toggle is proposed: none of the planned capabilities needs to expose an incomplete path between slices.

## Slices

All rows are ordered implementation/review units. Work on one at a time; re-check the map and actual diff size between slices. A row marked planned is not a claim of implementation or validation.

| # | PR title / purpose | Strategy | Budget | Depends on | Status |
|---|---|---|---:|---|---|
| 01 | Apply local shape offsets and box rotation correctly | A: complete compatibility fix | 300–450 | — | draft PR #167 |
| 02 | Add capsule and rounded convex colliders | A: additive factories/fixtures | 450–600 | 01 | locally validated |
| 03 | Add segments and owned chain colliders | A: additive shapes, explicit lifetime | 500–600 | 01 | locally validated |
| 04 | Add point, AABB and convex-shape overlap queries | A: additive world queries | 450–600 | 02 | locally validated |
| 05 | Add nearest/all convex shape casts | A: additive world queries | 450–600 | 02, 04 | locally validated |
| 06 | Make distance/rope joints work through the ECS lifecycle | A: complete joint system + first constraint | 500–600 | — | locally validated |
| 07 | Add revolute joints with spring, limits and motor | A: complete second constraint | 400–550 | 06 | locally validated |
| 08 | Add prismatic, weld and filter constraints | A: additive complete joint kinds | 450–600 | 06 | locally validated |
| 09 | Add wheel suspension and motor joints | A: additive complete mechanisms | 450–600 | 07, 08 | locally validated |
| 10a | Retune existing native joints without recreation | A: complete live settings API | 350–500 | 06–09 | locally validated |
| 10b | Add threshold events and opt-in break behavior | A: complete world-local events | 350–500 | 10a | planned |
| 11 | Add native mover and pogo joints | A: additive complete joint kinds | 450–600 | 06, 10 | planned |
| 12 | Add a query-based 2D capsule character controller | A: new component activates its system | 500–600 | 02, 05 | planned |
| 13 | Add dynamic character movement using mover/pogo joints | A: explicit dynamic mode | 500–600 | 11, 12 | planned |
| 14 | Add geometry/query playground scenes | A: isolated demo screens | 350–550 | 02–05 | planned |
| 15 | Add mechanism and character playground scenes | A: isolated demo screens | 450–600 | 09–13 | planned |

## Slice details

### 01 — local shape transforms

- **In scope:** apply circle/box offsets, retain box rotation in the resource and native shape, Codable defaults for old resources, regression tests against actual query/collision geometry.
- **Out of scope:** new shape kinds, changing existing circle-radius unit semantics, renderer changes.
- **Ships safely because:** existing ordinary zero-offset shapes retain their geometry; previously ignored authored offsets/angles become effective in one tested change.
- **Checks:** translated/rotated box hits, offset circles, old JSON decode and new round trips.
- **Cleanup owed:** none.

### 02 — capsules and rounded convex geometry

- **In scope:** public descriptors/factories, Codable support, native capsule/rounded-box/rounded-polygon creation, finite/dimension/radius validation and documented transform rules.
- **Out of scope:** concave polygon decomposition, chains, character control.
- **Ships safely because:** new cases are created only by new factories/data; old serialized cases keep decoding.
- **Checks:** contacts, ray hits, offsets/rotation/scale, rounded-corner behavior, degenerate/nonfinite input and serialization.
- **Cleanup owed:** none. If this exceeds 600 lines, split capsule and rounded geometry before implementation of the latter.

### 03 — segments and chains

- **In scope:** segment, open/closed chain and loose chain-segment resources; ghost vertices, winding and material/filter propagation; ownership of native chain IDs.
- **Out of scope:** treating a chain as a convex query shape, authoring tools for arbitrary terrain.
- **Ships safely because:** each new resource creates a complete collidable native object and is destroyed with its owner.
- **Checks:** front/back behavior, seam traversal, open endpoints, loops, degenerate input, sensor/filter interaction and removal without stale IDs.
- **Cleanup owed:** none; no native chain should leak after its entity/component is removed.

### 04 — overlap queries

- **In scope:** point containment, AABB candidate queries with their documented precision, exact convex-shape overlap; masks, explicit sensor policy and duplicate handling for compound bodies/chain segments.
- **Out of scope:** sweeps, solver-based movement.
- **Ships safely because:** these are additive queries on an already working world.
- **Checks:** empty world, misses, masks, rotated/offset shapes, compound bodies, sensors and invalid input. Document whether a result denotes a shape or a deduplicated entity; do not silently conflate the two.
- **Cleanup owed:** none.

### 05 — convex shape casts

- **In scope:** circle, capsule, box and polygon sweeps, nearest/all results, sorted physical travel distances, points/normals, masks and explicit initial-overlap handling.
- **Out of scope:** sweeping a non-convex chain, character gameplay.
- **Ships safely because:** callers opt into new methods; working raycast semantics remain unchanged.
- **Checks:** thin obstacles, high speed, start overlap, zero displacement, misses, nearest/all ordering, exclusions and invalid geometry.
- **Cleanup owed:** none.

### 06 — distance/rope joints and lifecycle

- **In scope:** a typed native joint holder and ECS sync/removal path; distance joints with frames/anchors, rope-style limits and spring settings; resolving entity references after bodies exist; meaningful legacy rope descriptors.
- **Out of scope:** generic unimplemented joint placeholders, other constraint kinds.
- **Ships safely because:** the slice delivers a working rope/distance constraint, not only a model or a dormant lifecycle layer.
- **Checks:** connected bodies stay within limits, spring response, late-spawned bodies, component/entity/body removal and recreation, world disposal and legacy Codable data.
- **Cleanup owed:** remove obsolete rope runtime handling when the complete typed path replaces it in this slice.

### 07 — revolute joints

- **In scope:** two-body and explicit world-anchor revolute configurations, angular limits, spring/motor tuning and documented compatibility for the existing one-entity factory.
- **Out of scope:** suspension and prismatic motion.
- **Ships safely because:** every exposed revolute factory creates a working native joint; no partially wired public type is added.
- **Checks:** pendulum pivot, angular limits, motor direction, spring convergence, world anchors, frame conversion and round trips.
- **Cleanup owed:** replace the previous inert revolute path without leaving duplicate implementations.

### 08 — prismatic, weld and filter joints

- **In scope:** sliding-axis constraints with limits/motor/spring, rigid and spring welds, and pair-filter joints.
- **Out of scope:** wheel suspension and high-level mechanisms.
- **Ships safely because:** each added kind uses the proven lifetime path from 06 and is independently usable.
- **Checks:** axis direction and frame rotation, stopped travel at both limits, weld relative pose and collision suppression/restoration.
- **Cleanup owed:** none. Split by joint kind if measured size requires it.

### 09 — wheel and motor joints

- **In scope:** wheel suspension with explicit local axis, supported travel limits/spring/motor controls; motor-joint spring/velocity targets with force/torque bounds.
- **Out of scope:** vehicle gameplay, camera/input rules inside the engine.
- **Ships safely because:** new mechanisms have complete native behavior and documented units.
- **Checks:** suspension rest/compression, vertical-axis conventions in Box2D 3.2, powered rotation and motor force/torque bounds.
- **Cleanup owed:** none.

### 10 — runtime tuning and break events

- **In scope:** documented post-creation tuning for supported joint settings, force/torque thresholds, world-local break/threshold event delivery and configured removal behavior.
- **Out of scope:** networking, replay and custom editor UI.
- **Ships safely because:** breaking remains explicit opt-in; an ordinary joint keeps its original behavior.
- **Checks:** below/above threshold, event once per defined transition, safe subscriber-driven removal, isolation between worlds and no retain cycles. Verify Box2D's threshold reporting rather than assuming it automatically destroys the joint.
- **Cleanup owed:** no temporary flags or duplicate event paths.

### 11 — mover/pogo joints

- **In scope:** usable public mover/pogo configurations and runtime controls mapped to native Box2D 3.2 joints, with force/spring limits and body-lifetime handling.
- **Out of scope:** character input, grounded/jump state and animation.
- **Ships safely because:** the joints are independently usable constraints before a character component consumes them.
- **Checks:** target response, bounded force, pogo support/spring behavior and owner/body deletion.
- **Cleanup owed:** none; mark the upstream experimental status clearly.

### 12 — query-based character controller

- **In scope:** capsule geometry, fixed-step desired velocity/acceleration/braking, gravity, jumping, grounded/slope state, ground snap, ceilings/corners and reset after teleport; use Box2D mover/plane-solving APIs.
- **Out of scope:** dynamic pushing, mover/pogo-driven rigid-body mode and gameplay-specific abilities.
- **Ships safely because:** a new character component activates a complete controller; ordinary PhysicsBody2D entities keep their path. Define conflicting-component behavior explicitly.
- **Checks:** flat/sloped ground, wall/ceiling, jumping/landing, descending terrain, small steps within the documented capability, sensors ignored, filters, teleport, variable frame rates and no tunneling through thin barriers.
- **Cleanup owed:** none. No promise of arbitrary stair climbing without an implemented/tested step-up algorithm.

### 13 — dynamic character mode

- **In scope:** explicit dynamic mode backed by native mover/pogo constraints, interaction with dynamic bodies, moving platforms, grounded/jump state, mode/owner removal and bounded tuning.
- **Out of scope:** ragdolls, networking and animation state machines.
- **Ships safely because:** the query-based mode remains complete; dynamic behavior requires an explicit configuration choice.
- **Checks:** pushes a light object, respects bounded force against heavy objects, rides a moving platform, jumps/lands, does not double-simulate its body, honors filters and releases all joints/bodies on removal.
- **Cleanup owed:** none; keep both complete modes, rather than deleting a still-useful query mode.

### 14 — geometry and query demos

- **In scope:** extend `Demos/Physics2D` with visible capsule/rounded/chain geometry and interactive overlap/sweep probes, layer/sensor options and hit markers.
- **Out of scope:** mechanism and character demos.
- **Ships safely because:** these are standalone, fully implemented screens with explicit SceneView identities.
- **Checks:** deterministic `--validate` assertions plus native `--verify` UI interaction, real GPU frames and visual review. Preserve the existing raycast/event scenes and their checks.
- **Cleanup owed:** none; generated bundles/proof files remain ignored.

### 15 — mechanism and character demos

- **In scope:** pendulum/rope, sliding and powered mechanisms, suspension and breakable connections; a character playground covering both controller modes and physical interaction.
- **Out of scope:** reusable engine code hidden inside a demo, website publication.
- **Ships safely because:** the screens consume already tested runtime APIs; game rules and fixtures stay under `Demos/Physics2D`.
- **Checks:** deterministic validation, native controls, mode switches and scene re-entry, break events, jump/grounded transitions and reviewed GPU captures.
- **Cleanup owed:** none. Split mechanisms and character screens if the actual diff exceeds the target.

## Validation and completion requirements

- Use Swift Testing and real Box2D worlds; do not substitute source-text assertions or mocked physics for behavior.
- Focused tests first, then the affected 2D/3D physics/event/fixed-step regressions. Broaden to `swift test --parallel` for the completed foundational change when environment/disk permit; report unrelated failures and platform gaps precisely.
- Run SwiftLint on changed Swift sources and inspect the task-owned diff. Preserve unrelated dirty files and dependency pins.
- Reuse an isolated task-owned SwiftPM scratch path with consistent `/tmp` spelling; do not alternate `/tmp` and `/private/tmp` or delete the shared `.build` cache.
- Native demos require build, actual launch, UI interaction, reviewed GPU frames and machine-readable results. Headless simulation alone does not prove the UI works.
- Windows CI and any other platform validation must be reported separately from macOS proof; a local pass does not imply CI/platform coverage.
- Completion requires all four requested capability groups, tests and demos. Finishing one row is progress, not completion of this request.
- Before any PR is opened, measure its actual reviewable diff and re-slice if necessary. No automatic publish or merge.

## Decision log

- 2026-10-20: Inspected the current committed physics baseline and vendored Box2D 3.2 headers; previous raycast/event work is already present.
- 2026-10-20: Proposed strategy A and fifteen bounded implementation/review slices. User approval of this map and integration strategy is still pending; no implementation code has been written for this request.

- 2026-10-21: User approved the whole map and strategy A. Started slice 01 in managed worktree `box2d-feature-coverage`, branch `codex/box2d-01-local-shapes`, based on origin/main at 5b6085790.

- 2026-10-21: Slice 01 adds backward-compatible box angles, scaled offsets/vertices, body rotation sync and consistent writeback. The writeback path also validates body IDs before reading buffered userData after a collision subscriber removes a body.
- 2026-10-21: Local evidence: 70 targeted physics/event/fixed-step tests and both deterministic Physics2DDemo scenes passed; SwiftLint: zero violations. Full parallel package testing failed on navigation, golden reference naming, scratch-path tool lookup and a WindowFrameRequests assertion outside changed files. Base main Windows CI failed and its macOS CI was cancelled; full-suite/CI success remains unproven.

- 2026-10-21: User authorized push and draft PR for slice 01; draft PR #167 created, no merge performed. A subsequent thin-obstacle sweep test exposed hull welding of thin boxes; analytic box construction was backported here with rotated/mirrored thin-box raycast regressions. The updated slice passes 83 physics/fixed-step tests in 18 suites.

- 2026-10-21: Slice 01 is locally complete in e8e3196b5 (274 reviewable lines). Push was rejected by automatic approval review pending explicit user consent to publish to GitHub; no external mutation occurred. Slice 02 continues locally on a separate dependency branch; publication and merge remain gated.

- 2026-10-21: Slice 02 is locally validated: capsule/rounded-box/rounded-polygon factories and Codable validation, native creation and conservative round scaling; 80 physics/event/fixed-step tests passed in 14 suites, SwiftLint zero violations. No remote publication performed.

- 2026-10-21: Slice 03 locally validated: two-sided segments, one-sided loose/owned chains, loop ownership/freeing, mirrored winding, sensor chains, materials/filters and event flags. 87 targeted tests passed in 15 suites; changed Swift sources pass SwiftLint.

- 2026-10-21: Slice 04 locally validated: exact point/convex overlaps, broad-phase AABB candidates, sensor/mask/exclusion options and per-shape IDs. Five new tests and all 92 targeted regressions (16 suites) passed; SwiftLint zero violations.

- 2026-10-21: User explicitly authorized push and draft PR for slice 01. Published draft PR #167 at https://github.com/AdaEngine/Ada/pull/167; no merge performed.
- 2026-10-21: Slice 05 locally validated: sorted convex sweeps, nearest clipping, sensor/mask/exclusion policy, explicit initial/zero-motion overlaps, chain-facing tests and analytic thin-box geometry. Five new tests passed; extended physics/fixed-step selection passed 109 tests in 22 suites; SwiftLint zero violations. The thin-box fix is also being backported to the slice 01 draft before review.

- 2026-10-21: Slice 06 locally validated: real rigid/spring/limited/motorized distance constraints and legacy ropes; deferred body resolution, component/entity/body removal, reconnection, checked Sendable runtime records and backwards-compatible Codable. Six new tests passed; 116 physics/fixed-step tests in 23 suites passed; SwiftLint zero violations. No remote publication of this slice.

- 2026-10-21: Slice 07 locally validated: two-body and world-anchor revolute hinges, spring targets, angular limits/motors, legacy one-body behavior and anchor-body cleanup. 11 joint tests and 121 physics/fixed-step tests in 24 suites passed; SwiftLint zero violations.

- 2026-10-21: Slice 08 locally validated: rotated-axis prismatic springs/limits/motors, rigid/soft welds and pair-filter constraints. Removing a non-colliding joint now explicitly refilters stationary overlaps before native destruction (native DestroyJoint only wakes bodies). 16 joint tests and 126 physics/fixed-step tests in 25 suites passed; SwiftLint zero violations.

- 2026-10-21: Slice 09 locally validated: vertical/rotated suspension, wheel travel limits and motors, relative velocity and bounded pose servos. 21 joint tests and 131 physics/fixed-step tests in 26 suites passed; SwiftLint zero violations. Split the next planned row into independently complete live-tuning (10a) and break-event (10b) units to keep review diffs bounded.

- 2026-10-21: Slice 10a locally validated: typed live-setting overloads retain native joint IDs and world-hinge reference frames, wake sleeping bodies, persist updated descriptors and reject stale/wrong-kind handles. Five new tests and 136 physics/fixed-step tests in 27 suites passed; SwiftLint zero violations.
