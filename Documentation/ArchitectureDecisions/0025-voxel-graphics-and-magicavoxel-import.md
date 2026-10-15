# ADR-0025: Voxel graphics and MagicaVoxel import

- Status: Accepted
- Date: 2026-10-14
- Implementation: Partial (import, animation, dynamic world and physics; editor integration shipped; not released)

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

Axis conversion happens in scene import, not in the parser. MagicaVoxel is
right-handed with Z up; the engine is left-handed with Y up and +Z forward. The
import swaps Y and Z (`(x, y, z) -> (x, z, y)`), so a model keeps the look of
MagicaVoxel's default front view. Because the swap is a mirror it is baked into
mesh vertices with reversed triangle winding, and node matrices are conjugated by
the swap, so no node carries a negative-determinant transform. The default scale
is 1 voxel = 0.1 world units, configurable per import.

### 3. Hybrid scene representation

By default a `.vox` scene is imported as an entity hierarchy: one entity per
shape node with a `Transform` taken from the `nTRN` chain. This keeps the
structure for part animation. An import option, `mergeStatic`, merges subtrees
that contain no animated transform (every `nTRN` has at most one frame) into one
mesh per subtree, trading structure for fewer draw calls. The parser exposes
`VOXTransformNode.isAnimated` so the importer can decide without extra data.

Import settings (`voxelSize`, `mergeStatic`, `framesPerSecond`) are stored per
model in `Model3DSource.voxel` and reach the importer as an asset query
(`castle.vox#voxelSize=0.05&mergeStatic=1&fps=24`), the mechanism other assets
already use for options, so they also work with `AssetsManager` directly. The
editor exposes them in the Model 3D inspector, imports and previews `.vox` like
other models, and keeps its glTF-specific tooling glTF-only.

### 4. Animation

Three levels, delivered in this order:

1. Rigid part animation: `nTRN` frame keys become per-node `VoxelNodeAnimation`
   keys (position lerp, rotation slerp, hold after the last key) applied to entity
   `Transform`s. A `VoxelAnimationPlayback3DComponent` on the model root owns the
   shared clock (30 fps by default, loop or stop, speed, pause) and
   `Model3DSource.autoplay`/`repeats` control it.
2. Frame-by-frame: an `nSHP` with several models swaps meshes (without
   interpolation) and the matching pivot offset by frame.
3. Skinned deformation: only if needed, reusing existing skinning if available.
   Not implemented.

Timeline length is the highest keyed frame plus one; MagicaVoxel's own project
length is not parsed. Clips from `AdaAnimation` are not integrated yet.

### 5. Dynamic voxel world

World storage (`VoxelWorldStorage`) is split into 32³ chunks behind a lock
(`Mutex`), so it can be edited from any thread. Each chunk is a separate mesh
entity, so frustum culling, GPU visibility and LOD apply per chunk. Edits mark
the chunk dirty, and also every neighbour the voxel touches (face, edge and corner
neighbours) because culling and ambient occlusion read adjacent voxels.
`VoxelWorldMeshing3DSystem` takes up to `meshingBudget` dirty chunks per update,
meshes them in parallel from a snapshot padded by one voxel of neighbours
(`VoxelMesher` region mode), and applies entity changes as world commands. Edits
made while a chunk is being meshed re-dirty it. The voxel world uses engine axes
directly (X right, Y up, Z forward); only `.vox` import swaps axes.

### 6. Physics

Colliders are merged boxes rather than triangle meshes: `VoxelColliderBuilder`
greedily merges solid voxels into a minimal set of boxes that cover the solid
volume exactly once, and `Shape3DResource` boxes gained a `center` offset
(backwards compatible decoding) so one body can carry many boxes. A voxel world with
`generatesColliders` keeps one static body entity per chunk; it is replaced when
the chunk's boxes change and removed when the chunk empties. Physics reads local
`Transform`s, so collider entities are placed in world space (composed from the
owner's hierarchy) and follow the world when it moves; scale is not supported.

`VoxelWorldStorage.detachFloatingIslands` flood-fills (6-connectivity) from the
neighbours of removed voxels. A component that reaches no anchored voxel and holds
at most `maxVoxels` voxels is removed from the world and returned as a
`VoxelIsland`; `spawnBody` turns it into a dynamic body with a mesh and box
colliders. The body's material density is chosen so the mass computed from its
shapes equals the requested mass: the engine overrides only the mass of a body, so
a mismatch leaves a much lighter body's inertia and heavy blocks tunnel through
thin colliders.

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
3. Scene import and editor integration (done: `.vox` loads as `ModelAsset3D`, hybrid `mergeStatic`, per-model `VoxelImportSettings`, editor import/preview/inspector).
4. Animation (done: rigid parts and frame-by-frame).
5. Chunked dynamic world (done).
6. Physics (done: compound boxes, chunk colliders, floating islands).
7. Optional: instancing, skinning, GPU paths.
