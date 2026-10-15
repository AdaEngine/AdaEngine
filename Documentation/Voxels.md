# Voxels

AdaEngine renders voxels through ordinary meshes, so lighting, shadows, ambient
occlusion and culling work as for any 3D model. The design is in
[ADR-0025](ArchitectureDecisions/0025-voxel-graphics-and-magicavoxel-import.md).

## MagicaVoxel models

`.vox` files load as `ModelAsset3D`, so a `Model3DSource` can reference them:

```swift
app.spawn("Castle") {
    Model3DSource(source: "@res://castle.vox", autoplay: true)
    Transform()
}
```

MagicaVoxel is right-handed with Z up; the engine is left-handed with Y up and +Z
forward. The importer swaps Y and Z, so a model keeps the look of MagicaVoxel's front
view. A model's pivot is the center of its box, as in MagicaVoxel, and one voxel is
0.1 world units by default.

The scene graph becomes an entity hierarchy that keeps node names and transforms.
Hidden nodes and layers are skipped. Colors come from the palette (stored in vertex
colors, with baked ambient occlusion) and the model uses one diffuse material; the
`MATL` chunk is parsed but not applied.

### Import settings

`Model3DSource.voxel` takes a `VoxelImportSettings`:

```swift
Model3DSource(
    source: "@res://castle.vox",
    voxel: VoxelImportSettings(voxelSize: 0.05, mergeStatic: true, framesPerSecond: 24)
)
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `voxelSize` | 0.1 | Edge length of one voxel in world units. |
| `mergeStatic` | `false` | Merges parts without animation into one mesh: fewer draw calls and no hidden faces between parts, but the parts are no longer separate entities. |
| `framesPerSecond` | 30 | Playback rate of MagicaVoxel frames. |

The settings reach the importer as an asset query, so the same options work with
`AssetsManager`: `@res://castle.vox#voxelSize=0.05&mergeStatic=1&fps=24`. Invalid
values are ignored. To import a parsed file yourself, use `VOXLoader` and
`ModelAsset3D(voxelFile:options:)`.

### Animation

Keyframes of a node's transform (position interpolates linearly, rotation along the
shortest arc, the pose holds after the last key) and models with several frames
(switched without interpolation) animate. A `VoxelAnimationPlayback3DComponent` on
the model root owns the clock: `isPlaying`, `repeats`, `speed` and `time`.
`Model3DSource.autoplay` and `repeats` set the initial values. The timeline lasts
until the highest keyed frame; MagicaVoxel's own project length is not read.

## Editable voxel worlds

`VoxelWorld3DComponent` renders an editable world as one mesh entity per 32³ chunk.
Edit it through its thread-safe `storage` in engine axes (X right, Y up, Z forward;
negative coordinates are fine). Palette index 0 is empty.

```swift
let world = VoxelWorld3DComponent(palette: palette, voxelSize: 0.1, meshingBudget: 8)
app.spawn("Terrain") {
    world
    Transform()
}

world.storage.fill(from: SIMD3(0, 0, 0), to: SIMD3(63, 7, 63), color: 1)
world.storage.setVoxel(x: 10, y: 8, z: 10, color: 2)
```

Edits mark the chunk and every neighbour they touch as dirty. `VoxelWorldMeshing3DSystem`
remeshes up to `meshingBudget` chunks per update, in parallel, so big edits spread
across frames. A `VoxelGrid` (for example from a `.vox` model) can be stamped into the
world with `storage.stamp(_:at:)`.

## Physics

With `generatesColliders: true` the world keeps a static body per chunk built from
merged boxes (`VoxelColliderBuilder`). This needs `Physics3DPlugin`. Colliders are
placed in world space and follow the world when it moves; scale is not supported.

Cut-off groups of voxels can become dynamic bodies:

```swift
storage.fill(from: cutStart, to: cutEnd, color: 0)
let islands = storage.detachFloatingIslands(around: removedVoxels, isAnchored: { $0.y <= 0 })
for island in islands {
    island.spawnBody(in: world, palette: palette, voxelSize: 0.1, worldTransform: terrainMatrix)
}
```

A group is detached when it touches no anchored voxel and has at most `maxVoxels`
voxels (4096 by default); larger groups are treated as part of the main structure.
`spawnBody` sets the body's density so its mass equals `voxelCount × voxelSize³ ×
density` (800 by default).

## Not supported yet

Voxel materials from `MATL`, transparency, skinned deformation, mesh instancing of
many identical models, `AdaAnimation` clips on voxel nodes, and GPU-driven rendering.

## Testing with real MagicaVoxel files

The repository does not contain MagicaVoxel's own sample files. To check a directory of real
files, such as the `vox` folder of a MagicaVoxel release, point `ADAENGINE_VOX_SAMPLES` at it:

```sh
# Parse every file.
ADAENGINE_VOX_SAMPLES=/path/to/vox swift test --filter VOXRealFilesTests

# Render them on Metal to PNGs in /tmp (castle, teapot, T-Rex, ...); ADAENGINE_VOX_RENDER
# takes a comma separated list of names relative to the directory.
ADAENGINE_VOXEL_METAL_SMOKE=1 ADAENGINE_VOX_SAMPLES=/path/to/vox \
    swift test --filter rendersRealMagicaVoxelSamples
```
