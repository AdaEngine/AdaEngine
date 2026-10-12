# Performance review — 2026-10-12

Static review (no profiling). Status: `[ ]` open, `[x]` fixed. P2 fixed for growth only (upload skipping still open); P5 partly not needed (array only copied on flip). Headless SpriteInstancingValidation run produced no output, so it is not counted as verification.

## Bug
- [x] B1 `Schedulers.insert(_:after:)` / `insert(_:before:)` never store the scheduler (`AdaECS/Scheduler.swift`).

## Critical
- [x] P1 `FilterQueryIterator.next()` per-row `Entities` hash lookup and `Entity` retain skipped unless a target reads the entity (`QueryTarget._requiresEntity`). Per-row chunk-array retain still open.
- [x] P2 `BufferData.reserveCapacity` reallocates GPU buffer at exact size, `write` uploads every frame (`AdaRender/Misc/BufferData.swift`).
- [x] P3 `VisibilitySystem` allocates Set/array per camera, `AABB.transformed` allocates corner array per entity (`AdaRender/VisibleEntities.swift`).
- [x] P4 `PrepareSprites` looks up pipeline per sprite per camera (`AdaSprite/SpriteRenderSystem.swift`).
- [ ] P5 `SpriteRenderSystem` allocates UV array per sprite, dynamic cast per item.
- [x] P6 3D blend sort does casts and matrix math inside comparator (`Main3DRenderNode.swift`).

## Medium
- [x] P7 `MultiThreadedSystemsGraphExecutor`: batch plan is now built once in `initialize` (rebuilt on graph change) instead of every frame. Not benchmarked (no scheduler benchmark exists).
- [ ] P8 `RenderItems.sorted()` copies fat items; 2D sort key lacks texture tie-break.
- [ ] P9 `WGPURenderCommandEncoder.commitBindGroup` sorts dictionary keys and builds key arrays per draw.
- [ ] P10 `Chunk.entityIndices` dictionary duplicates `Entities` location data.
- [x] P11 `TextLayoutSystem` re-lays out on `Changed<Transform>`.
- [x] P12 `Entity: Hashable` hashes `name` String.
- [ ] P13 `ExtractSprite` rebuilds whole SparseSet each frame; `LinearGradientUniform` temp arrays.

## Verification
Run `swift test --parallel` (use `--scratch-path` if toolchain cache mismatches) and `Benchmarks/AdaECSBenchmarks` before/after P1/P7.

## P1 benchmark (AdaECSBenchmarks, release, p50, same machine)
| Scenario | before | after | retains before -> after |
| --- | --- | --- | --- |
| SimpleIter | 21 ms | 18 ms | 408K -> 208K |
| FragmentedIter | 17 ms | 13 ms | 407K -> 207K |
| HeavyCompute | 504 us | 460 us | 4085 -> 2085 |
| Spawn / SpawnBatch / AddRemove / InsertCoW | unchanged (within noise) | | |
