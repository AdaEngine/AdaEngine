---
name: ada-pixel-art
description: Draw pixel-art sprites, icons and tile sheets as PNG files from an AdaScript program in Ada Studio, check them visually, and turn them into atlases, tilesets and sprites.
allowed-tools: editor.project.context, editor.sprite.generate, editor.image.read, editor.atlas.pack, editor.tileset.create, editor.tileset.read, editor.tilemap.write, editor.components.describe, editor.scene.get, editor.scene.apply, editor.docs.read, editor.build.start, editor.play.start, editor.task.status
---

# Ada Studio Pixel Art

Use this for 2D game art you can build from shapes on a small grid: characters, enemies, items, icons, particles, UI pieces and tile sheets. Describe the picture in AdaScript and Studio writes a `.png`. Painted or photographic art needs the image generation provider (`editor.image.generate`) when one is configured; otherwise stay in pixel-art style.

1. Read `editor.project.context` for the Assets root. Choose a new destination such as `Assets/Sprites/hero.png`; `editor.sprite.generate` never overwrites, so use a new name for each revision.
2. Call `editor.sprite.generate` with `source` and `destination`. The script runs in an isolated VM: no files, network, scene or engine access, a 64 KiB source limit and a small time/step budget. Errors come back as text; fix the script and call again.
3. Look at the result with `editor.image.read` and a precise question ("Does this read as a red slime facing front? What looks wrong?"), then fix what is wrong under a new name. Do not call a sprite finished from the pixel counts alone.
4. Use the PNG: a single sprite goes into a `Sprite` component; several frames or tiles go through `editor.atlas.pack` or `editor.tileset.create` (a tile sheet is one PNG of equal cells). Read `editor.components.describe` with query `Sprite` for the component, preserve unrelated payload fields and pass the current scene revision.
5. Build, run visible Play and inspect a frame at the size the sprite is shown. Check scale, anchor and draw order, and that the pixels stay sharp: if they look blurry, set the texture's sampler filter to nearest in its texture settings.

## Script API

Define `func build(sprite)`. Coordinates are whole pixels, `(0, 0)` is the top-left corner, x grows right and y grows down. Color `0` is transparent and also erases. A failed call records the error and generation is rejected with that message.

| Call | Meaning |
| --- | --- |
| `sprite.size(w, h)` | Canvas size, 1...512 per side. Call it first, once. |
| `sprite.palette(i, r, g, b)` | Palette entry `i` (1...255), channels 0...255. Unset entries are magenta so mistakes are visible. |
| `sprite.opacity(i, a)` | Alpha 0...255 of a palette entry, for shadows and glass. |
| `sprite.pixel(x, y, c)` | One pixel. Outside the canvas is ignored. |
| `sprite.rect(x0, y0, x1, y1, c)` | Filled rectangle, corners inclusive. |
| `sprite.line(x0, y0, x1, y1, c)` | Line. |
| `sprite.ellipse(cx, cy, rx, ry, c)` / `sprite.circle(cx, cy, r, c)` | Filled ellipse or circle around a pixel. |
| `sprite.fill(c)` | Fill the whole canvas. |
| `sprite.mirror()` | Copy the left half onto the right half, mirrored: draw half a character and get a symmetric one. |
| `sprite.outline(c)` | Paint `c` on every transparent pixel next to a painted one. Do it last. |
| `sprite.colorAt(x, y)` | Palette index at a pixel, for loops and checks. |

Later calls overwrite earlier ones: paint large shapes first and details last.

```
func build(sprite) {           // 16x16 slime, drawn as a half and mirrored
    sprite.size(16, 16);
    sprite.palette(1, 90, 200, 110);    // body
    sprite.palette(2, 150, 240, 160);   // highlight
    sprite.palette(3, 30, 60, 40);      // eyes
    sprite.palette(4, 20, 30, 25);      // outline
    sprite.ellipse(7, 10, 7, 5, 1);
    sprite.rect(0, 11, 7, 14, 1);
    sprite.rect(3, 5, 4, 6, 2);
    sprite.pixel(4, 9, 3);
    sprite.pixel(4, 10, 3);
    sprite.mirror();
    sprite.outline(4);
}
```

## Craft

- Pick the size for how big the sprite appears: 16 px for small tiles and items, 32 px for characters, 8 px for particles and bullets. Draw at the final size; do not scale up later.
- Use a small palette: 4-8 colors per sprite, with a darker shade for the underside and a lighter one for a highlight, plus a very dark outline. Keep the same palette across a game so the art matches.
- Use `sprite.mirror()` for anything symmetric, and loops for repeating details (bricks, grass, windows).
- A tile sheet is one canvas of equal cells (for example 4 by 4 cells of 16 px): draw each tile in its cell with a loop over cell offsets, keep edges seamless where tiles meet (match the pixels on opposite borders), then call `editor.tileset.create` with the cell size.
- Animation frames are cells in one sheet; slice them with `editor.atlas.pack` or the tile source and check the first and last frame loop.
- Only the calls above exist; do not use `print`, files, imports or `System`. A script that fails validation is rejected before running.
