# Performance review — 2026-10-12

Static review (no profiling). Status: `[ ]` open, `[x]` fixed. P2 fixed for growth only (upload skipping still open); P5 partly not needed (array only copied on flip). SpriteInstancingValidation (QA app wrapped in a local .app, driven via computer use) showed the green PASS border and an identical frame before and after P8. NOTE: on macOS that app runs the Metal backend; WebGPU code is only compiled with ADAENGINE_WEB_EXPORT=1 (needs Swift 6.3.x, Tint).

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
- [x] P8 (partial) 2D batching sorts the extracted items in place and writes batches directly, no `sorted()` copy / intermediate array. Texture tie-break in the sort key is still open (item has no texture data).
- [x] P9 per-pipeline `sortedBindingSlots` replaces per-draw `keys.sorted()`; `commitBindGroup` re-binds only dirty descriptor sets (all after a pipeline switch). Verified: `script/validate_webgpu.sh` (real Tint + Dawn pixel tests) passes, WASM export compiles (Swift 6.3.2 + wasm SDK). Browser run of the WASM export (built-in browser, WebGPU): `[SpriteValidation] PASS backend=webgpu pixels=identical frames=10 quads=1242 draws=8 instancing=true`. The repo's `BrowserWASIShim` has no `dist/`, so the exported site needed `@bjorn3/browser_wasi_shim@0.4.2` `dist/` copied in by hand. Key/owner arrays per dirty set are still built per draw.
- [x] P10 `Chunk.entityIndices` removed; row lookups by id scan the chunk's `entities` (<= 250), removal uses the row already tracked by `Chunks`. Benchmarks (Swift 6.3.2, p50): AddRemove 301 -> 283 ms, Spawn 87 -> 84 ms, SpawnBatch 76 -> 74 ms, InsertCoW 161 -> 153 ms; iteration unchanged. Gains are small; per-chunk memory saving (250-entry hash table per chunk) not measured.
- [x] P11 `TextLayoutSystem` re-lays out on `Changed<Transform>`.
- [x] P12 `Entity: Hashable` hashes `name` String.
- [x] P13 (partial) `LinearGradientUniform.init` no longer builds three temporary arrays; clipped gradient indices are appended lazily instead of via an intermediate array (`AdaUI/Render/UIDrawPass.swift`, `UIPlugin+Render.swift`), covered by a new padding/cap test. `ExtractSprite` still rebuilds its SparseSet each frame: capacity is already kept, so the remaining cost is one hash insert per sprite; incremental extraction needs change/despawn/visibility tracking and was not attempted without a sprite benchmark.

## Verification
Run `swift test --parallel` (use `--scratch-path` if toolchain cache mismatches) and `Benchmarks/AdaECSBenchmarks` before/after P1/P7.

## P1 benchmark (AdaECSBenchmarks, release, p50, same machine)
| Scenario | before | after | retains before -> after |
| --- | --- | --- | --- |
| SimpleIter | 21 ms | 18 ms | 408K -> 208K |
| FragmentedIter | 17 ms | 13 ms | 407K -> 207K |
| HeavyCompute | 504 us | 460 us | 4085 -> 2085 |
| Spawn / SpawnBatch / AddRemove / InsertCoW | unchanged (within noise) | | |

## ExtractSprite benchmark (AdaSpriteBenchmarks, release, p50, Swift 6.3.2)
| Scenario | 50k before -> after | 100k before -> after | mallocs (50k) | retains (50k) |
| --- | --- | --- | --- | --- |
| ExtractSprite (full extract stage) | 26 -> 21 ms | 55 -> 45 ms | 100K -> 46 | 754K -> 454K |
| ExtractQueryOnly (query iteration alone) | 15 ms | 31 ms | 0 | 304K |

Cause of the extra mallocs/retains: `ExtractSprite` wrote each sprite through `ResMut.subscript(dynamicMember:)`
(`extractedSprites.sprites[id] = ...`), i.e. a runtime `WritableKeyPath` access plus `Ref` change-tick bookkeeping
for every row (about 2 mallocs and 6 retains per sprite). Diagnostic variants showed the rest is cheap: building
`ExtractedSprite` and appending to an array allocated nothing, a local `SparseSet` insert added about 2 retains per
sprite. Fix: take the set out of the resource once (`swap`), fill it locally, swap back. What remains is query
iteration (the `Entity` target) and the per-sprite hash insert.

The same `ResMut` dynamic-member pattern in other per-element loops (for example `renderItems.items.append` in
`PrepareSprites`) is likely to pay the same cost and has not been measured.

## PrepareSprites benchmark (AdaSpriteBenchmarks, headless backend, release, p50)
| Scenario | current | experiment: local array + swap | mallocs | retains |
| --- | --- | --- | --- | --- |
| 1 camera x 50k sprites | 6.3 ms | 1.75 ms | 100K -> 55 | 400K -> 100K |
| 2 cameras x 50k sprites | 13 ms | 3.6 ms | 200K -> 61 | 800K -> 200K |
| 1 camera x 100k sprites | 13 ms | 3.5 ms | 200K -> 55 | 800K -> 200K |

The current system pays about 2 mallocs and 8 retains per emitted render item, the same `ResMut` dynamic-member
pattern seen in `ExtractSprite` (`renderItems.items.append(...)` per item). Appending to a local array and swapping it
into the resource once removed almost all of it in an experiment. The fix is applied in `PrepareSprites`
(`AdaSprite/SpriteRenderSystem.swift`); confirmed numbers after applying: 1 camera x 50k 6.3 -> 1.78 ms,
2 cameras x 50k 13 -> 3.5 ms, 1 camera x 100k 13 -> 3.65 ms.

## Audit: per-element writes through `ResMut` dynamic member
Pattern: a function-style system takes `ResMut<T>` and writes `param.collection.append(...)` / `param.set[id] = ...`
inside a per-entity loop (keypath access, about 90 ns and 2 mallocs per operation in the sprite benchmarks).
`@ResMut` property wrappers in `@PlainSystem` types are not affected: they use `wrappedValue` directly and
`Ref.wrappedValue._modify` only yields the pointer and sets the change tick.

| Place | Per-element write | Expected size |
| --- | --- | --- |
| `AdaSprite/SpriteRenderSystem.swift` `ExtractSprite`, `PrepareSprites` | fixed | 10k-100k items |
| `AdaSprite/Text2DRenderSystem.swift` `ExtractText` (`extractedTexts.texts[id] =`) | open | texts, usually hundreds |
| `AdaSprite/Text2DRenderSystem.swift` `PrepareTexts` (`renderItems.items.append`, per text per camera) | open | texts x cameras; also looks up pipeline/draw pass per item |
| `AdaScene/3D/Model3DPlugin.swift` `sources.meshes.append` | open | meshes, up to thousands (other buffers there already use locals) |
| `AdaSprite/Lighting2D/ExtractLighting2DSystem.swift`, `AdaScene/3D/ExtractLighting3DSystem.swift`, `AdaCorePipelines/.../Environment3D.swift` | open | tens of lights/occluders |
| UI/camera/window/input extract systems | open | a handful per frame |

Only the sprite systems have enough elements for this to matter; the others are estimated under about 0.5 ms per frame.
