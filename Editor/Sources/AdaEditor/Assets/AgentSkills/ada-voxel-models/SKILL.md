---
name: ada-voxel-models
description: Generate MagicaVoxel (.vox) models from an AdaScript program in Ada Studio, then place them in a scene with Model3DSource.
allowed-tools: editor.project.context, editor.voxel.generate, editor.components.describe, editor.scene.get, editor.scene.apply, editor.docs.read, editor.build.start, editor.play.start, editor.task.status
---

# Ada Studio Voxel Models

Use this to create props, characters, terrain pieces and sprites-in-3D as `.vox` files without external tools. Python, MagicaVoxel and Blender are not available; the model is described in AdaScript and Studio writes the file.

1. Read `editor.project.context` for the Assets root. Pick a new destination such as `Assets/Models/tree.vox`; `editor.voxel.generate` never overwrites, so use a new name for each revision.
2. Call `editor.voxel.generate` with `source` (the script) and `destination`. The script runs in an isolated VM: no files, network, scene or engine access, a 64 KiB source limit and a small time/step budget. Errors come back as text; fix the script and call again.
3. Read the result: `size`, `voxelCount`, `paletteIndicesUsed` and `assetReference` (`@res://...`). Check them against what you intended before placing the model.
4. Read `editor.components.describe` with query `Model3DSource`, add that component and a Transform to an entity, and set `source` to the `assetReference`. One voxel is 0.1 world units by default (`voxelSize` setting), so a 32-voxel tree is 3.2 units tall. Preserve unrelated payload fields and pass the current scene revision.
5. Build, run visible Play and inspect a completed frame before claiming the model looks right. Generation proves the file is valid, not that it reads well.

## Script API

Define `func build(model)`. Call `model.size` first, once. Coordinates are whole numbers; `x` right, `y` forward, `z` up (MagicaVoxel space; the importer maps it to the engine's Y-up). Maximum size is 256 per axis. Painting outside the model is clipped for shapes and an error for `voxel`.

| Call | Meaning |
| --- | --- |
| `model.size(x, y, z)` | Grid size, 1...256 per axis. |
| `model.palette(index, r, g, b)` | Palette color, index 1...255, channels 0...255. Unset indices are gray. |
| `model.voxel(x, y, z, color)` | One voxel. Color `0` erases. |
| `model.box(x0, y0, z0, x1, y1, z1, color)` | Filled box, corners inclusive, any order. |
| `model.sphere(x, y, z, radius, color)` | Filled sphere; the center and radius may be fractional. |
| `model.cylinder(x, y, z0, z1, radius, color)` | Vertical cylinder from `z0` to `z1`. |
| `model.colorAt(x, y, z)` | Current color index, `0` when empty. |

Later calls overwrite earlier ones, so paint large shapes first and details last. Carve with color `0`.

```
func build(model) {
    model.size(16, 16, 24);
    model.palette(1, 110, 72, 40);   // trunk
    model.palette(2, 54, 140, 60);   // leaves
    model.cylinder(8, 8, 0, 9, 2, 1);
    model.sphere(8, 8, 15, 6.5, 2);
    model.sphere(8, 8, 21, 3.5, 2);
}
```

## Craft

- Work at a consistent scale: roughly 16 voxels for small props, 32 for characters, 64-128 for buildings. Larger grids cost more to mesh and draw.
- Use few, distinct palette entries (4-12) with clear light/mid/dark steps; flat color blocks read better than noise.
- Prefer shapes and loops over many `voxel` calls: shape calls are native and do not use the script budget, while loops over thousands of cells can hit the step limit.
- For symmetry, paint one half and mirror it with a loop over `colorAt`/`voxel`, or use symmetric shape pairs.
- Keep the model centered in its grid: the pivot is the center of the box.
- Only the supported calls above exist; do not use `print`, files, imports or `System`. A script that fails validation is rejected before running.
