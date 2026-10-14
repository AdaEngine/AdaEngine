# ADR-0025: Voxel graphics and MagicaVoxel import

- Status: Accepted
- Date: 2026-10-14
- Implementation: Partial (`.vox` parser and CPU mesher; not released)

## Context

AdaEngine has no voxel support. Authors want to bring models from MagicaVoxel
(`.vox`) into scenes, animate them, and build dynamic voxel worlds with
physics.

The engine already provides `Mesh`/`MeshDescriptor` with per-vertex colors,
`Mesh3DComponent`, PBR, cascaded shadows, SSAO, frustum/GPU visibility and LOD.
The asset system selects loaders by file extension. `AdaAssets` does not depend
on `AdaRender`. The render backend exposes no public compute encoder, and
`AdaPhysics` (box3d) supports box, sphere and triangle-mesh shapes only.

## Decision

### 1. CPU meshing into ordinary meshes

Voxels are converted on the CPU into a regular `MeshDescriptor` and rendered
through the existing 3D pipelines. No backend changes are required, and shadows,
SSAO, PBR and visibility work unchanged. GPU-driven voxel rendering (compute
meshing, ray marching) is out of scope until the backend exposes compute.

Meshing starts with culled faces, then greedy merging of same-color faces.
Palette colors are baked into the vertex `color` attribute; one material per
model. Ambient occlusion is baked into vertices. Material properties from
`MATL` (roughness, metallic, emission, glass) map to the PBR material.

### 2. Layered `.vox` import

- **Parser (`AdaAssets`, pure data, no render dependency).** Reads `SIZE`, `XYZI`,
  `RGBA`, `MATL`, `LAYR` and the scene graph (`nTRN`, `nGRP`, `nSHP`) including
  per-frame transform keys. The parser keeps MagicaVoxel's raw space (right-handed,
  Z up, palette index 0 means empty). Unknown chunks are skipped.
- **Meshing (`AdaRender`/`AdaScene`).** Converts a model grid to a mesh.
- **Scene import (`AdaScene`).** Converts the scene graph to entities.

Axis conversion to the engine's convention happens in scene import, not in the
parser. The default scale is 1 voxel = 0.1 world units, configurable per import.

### 3. Hybrid scene representation

By default a `.vox` scene is imported as an entity hierarchy: one entity per
shape node with a `Transform` taken from the `nTRN` chain. This keeps the
structure for part animation. An import option, `mergeStatic`, merges subtrees
that contain no animated transform (every `nTRN` has at most one frame) into one
mesh per subtree, trading structure for fewer draw calls. The parser exposes
`VOXTransformNode.isAnimated` so the importer can decide without extra data.

### 4. Animation

Three levels, delivered in this order:

1. Rigid part animation: animate entity `Transform`s from `nTRN` frame keys and
   from `AdaAnimation` clips.
2. Frame-by-frame: swap cached meshes by time for models with multiple frames.
3. Skinned deformation: only if needed, reusing existing skinning if available.

### 5. Dynamic voxel world

World storage is split into fixed-size chunks (initially 32³). Each chunk is a
separate mesh entity, so frustum culling, GPU visibility and LOD apply per chunk.
Edits mark chunks dirty. Remeshing runs on background tasks with a per-frame
budget. Chunk state lives in a dedicated component and is mutated through an
actor-isolated API.

### 6. Physics

Static voxel geometry uses a triangle mesh of exposed faces. A compound-shape
fixture made of merged boxes is added to `Shape3DResource` for dynamic bodies.
Disconnected islands (flood fill) can detach into dynamic bodies.

### 7. Deferred

Mesh instancing for many identical models, skinning and GPU-driven paths are
deferred until the corresponding backend capabilities are verified.

## Consequences

- A usable MagicaVoxel pipeline needs no render-backend work.
- Raw-space parsing keeps the parser testable in isolation and independent of
  engine conventions.
- Merged static subtrees lose per-part addressing, so the option is off by default.

## Delivery stages

1. ADR and `.vox` parser with tests (done).
2. Mesher: culled faces, then greedy, with baked AO (done).
3. Scene import and editor integration.
4. Animation.
5. Chunked dynamic world.
6. Physics.
7. Optional: instancing, skinning, GPU paths.
