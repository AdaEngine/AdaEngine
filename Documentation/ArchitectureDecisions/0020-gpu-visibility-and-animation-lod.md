# ADR-0020: GPU visibility and animation LOD

- Status: Accepted
- Date: 2026-10-05
- Implementation: Implemented on Metal and WebGPU with CPU fallback

## Context

The renderer already batches/instances meshes and uses CPU frustum lists,
independent shadow-cascade visibility, static LOD and distance fading. It does
not yet use GPU Hi-Z occlusion, GPU-generated indirect draws, character mesh LOD
or reduced animation evaluation rates.

## Decision

Keep CPU visibility as the reference and fallback. Add conservative Hi-Z
occlusion from scene depth, with explicit previous-frame/disocclusion handling,
and GPU compaction/indirect submission where backend capabilities allow it.
Keep camera and shadow-caster decisions separate. Newly visible or moved objects
must not disappear because of stale depth.

Extend LOD to skinned characters with compatible skeleton/palette/material
contracts. Schedule animation evaluation by projected significance and distance;
retain gameplay/root transforms and interpolate render poses between evaluations.
Use hysteresis to prevent mesh and update-rate oscillation. Keep collision and
gameplay simulation independent from visual LOD.

## Implementation checklist

- [x] Hi-Z generation, conservative bounds tests and disocclusion recovery.
- [x] Backend-neutral indirect draw/compaction capability and Metal implementation.
- [x] Skinned mesh LOD asset/runtime contracts.
- [x] Animation evaluation cadence, interpolation and significance policies.
- [x] Large-scene CPU/GPU profiling with correctness comparison to CPU reference.

## Validation requirements

Compare visibility with CPU reference in moving-camera, moving-object and
occluder-removal scenes. Verify offscreen shadow casters and independent cameras.
Measure draw/triangle counts separately from actual GPU and CPU time. Validate
character transitions, animated bounds and gameplay independence.

## Recorded implementation

The first GPU path uses current-frame opaque/alpha-mask depth and max-depth
Hi-Z, followed by per-draw instance compaction and indexed indirect arguments.
This avoids stale-depth disocclusion errors and keeps shadow lists independent.
Metal and WebGPU execute this path; other backends retain CPU visibility. Character mesh
LODs preserve the ordered palette and material contracts. Projected-size
animation cadence interpolates visible poses while playback/gameplay clocks
remain independent. See [PerformanceValidation.md](https://github.com/AdaEngine/AdaExamples/blob/main/Samples/SkeletalGarden/PerformanceValidation.md)
for concrete tests, measurements, opt-in controls and platform limits.

### WebGPU implementation

Set `Environment3D.gpuOcclusionEnabled = true` (or
`meshVisibility.gpuOcclusion`) to enable the existing current-frame occluder
prepass followed by WGSL max-depth reduction and atomic instance compaction.
The default remains disabled: the extra prepass is not beneficial for every
scene. No previous-frame depth or CPU GPU readback is required, and shadow
visibility remains independent.

Each camera owns a cached `r32float` mip pyramid and a ring of candidate,
uniform, compacted vertex and storage/indirect argument buffers. Separate
compute passes provide WebGPU resource transitions between mip levels and
the draw pass. Explicit unfilterable-float bindings support the `rgba32float`
occluder target without requiring `float32-filterable`. Draws use a zero
`firstInstance` and bind the compacted segment through the vertex-buffer
offset, so `indirect-first-instance` is not required. Native and browser
backends share WGSL; the browser draw uses the JavaScript WebGPU method where
Swan does not yet expose that wrapper.

Invalid candidate segments, overlapping output ranges and buffers exceeding
the baseline 128 MiB storage-binding limit retain the CPU path. Near-plane
intersections, invalid bounds/projections and force-visible instances are
conservatively kept. Odd mip sizes include the final source row and column.

`script/validate_webgpu.sh` includes `WGPUVisibilityProcessorTests`. The tests
exercise GPU counts and compacted instance contents, camera/object motion,
occluder removal, odd-size holes, resize, ring reuse, multiple cameras and
allocation growth. A pixel test consumes the generated indexed indirect
arguments and compacted instance colors, including zero-instance draws,
nonzero first-index and negative base-vertex values. Native GPU results do
not establish browser runtime validation or a performance improvement;
those require testing an exported scene on its target browser/device.

Recorded native validation (2026-10-17): `script/validate_webgpu.sh` passed all
36 tests on Windows with Swift 6.3.1, Dawn 147 and an NVIDIA GeForce RTX 4070
using D3D12. This includes all three WebGPU Hi-Z tests and existing sprite,
tile-occlusion, binding-state and fresh Tint conversion checks. The recommended
validation toolchain remains Swift 6.3.2; no browser/WASM build or runtime
validation was recorded for this change.

The full-app `WGPUVisibilitySceneTests` additionally compares exact pixels with
Hi-Z on/off across camera movement, physical occluder removal, SSAO/SSR and
odd-size target replacement. Its shadow scene compares separate GPU geometry
with shared instanced geometry and equivalent material bindings. Shadow draw
counts must decrease while pixels remain identical; removing the wall and
disabling shadows must actually change the image. Focused extraction, material,
instance-ring and diagnostics validation passed 18 tests in five suites.

A native Skeletal Garden Release A/B on Ryzen 9 7900X / RTX 4070 measured
65.78 to 70.86 FPS (15.202 to 14.113 ms per frame), a 7.7% increase. Three
alternating pairs each used six seconds of warmup and twelve seconds of frame
intervals, with unchanged 1100x760 output, three shadow cascades, local shadows,
SSAO, SSR and FXAA. Profiling/readback were disabled and the app cap raised to
1000 FPS; FIFO presentation remained unchanged. This measures the accompanying
CPU/cache optimizations, not a Hi-Z speedup: enabling Hi-Z on that open scene
measured 65.60 FPS and remains opt-in. These are frame intervals, not GPU timestamps.

## Consequences

This is an accepted implementation direction, not evidence of shipped behavior.
Each slice must record its tested platform and remaining checklist items.
