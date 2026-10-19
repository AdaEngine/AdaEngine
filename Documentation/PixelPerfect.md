# Pixel-perfect rendering

`Camera.pixelPerfect` renders a 2D camera at a fixed low resolution and presents it with a whole-number scale and nearest sampling. The picture does not depend on the window size, pixels stay square, and user interface is still drawn crisp at the output's own resolution.

```swift
var camera = Camera()
camera.pixelPerfect = PixelPerfectSettings(
    resolution: SizeInt(width: 320, height: 180),
    scaleMode: .integer,                  // or .fit
    letterboxColor: Color(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
)
world.spawn("Camera") { Camera2D(camera: camera) }
```

In Studio select the camera and turn on **Pixel Perfect**, then set **Pixel Width**, **Pixel Height**, **Pixel Scale** (`integer` or `fit`) and **Pixel Border**. The preset needs `UpscalePlugin`, which `DefaultPlugins` includes.

## What it does

- **Fixed-resolution target.** The scene is drawn into a texture of `resolution` pixels. One world unit is one art pixel at zoom 1, so a 16 × 16 sprite is 16 art pixels wide whatever the window is. The camera's projection uses that size, not the window's.
- **Whole-number scale.** `integer` picks the largest whole number of output pixels per art pixel that fits and centres the picture on whole pixels; the rest is the border in `letterboxColor`. If the output is smaller than the resolution, the picture is scaled down to fit instead, which is no longer pixel exact. `fit` uses the largest factor that fits, so the picture fills the output along one axis, with uneven pixel sizes where the factor is fractional.
- **Nearest sampling.** The upscale never blends neighbouring pixels. Sprite textures keep their own samplers: the Aseprite importer already writes `nearest`, and a linear texture inside the picture will still look soft.
- **Crisp UI.** AdaUI is not part of the low-resolution picture. The scene is scaled into a picture of the output's size first, and the UI is drawn onto it at full resolution, so text and controls stay sharp and can sit over the border.
- **Input and picking.** A window point is measured against the picture, not the whole window: `Camera.viewportToWorld2D`, `viewportToWorld` and sprite picking account for the border, and a point in the border is outside the picture's world area (`Camera.pixelPerfectPresentation` gives the picture's rectangle in logical points).

Use `Camera2DController` with `snapsToPixels` to keep a gliding camera on the art-pixel grid.

## Limits

- Not combined with temporal upscaling or foveation; those take precedence when set. An invalid size (zero, negative or above 4096 per side) is ignored and the camera renders normally.
- The picture's sampling is nearest. Anti-aliased geometry, fractional zoom and rotated sprites still shimmer at art-pixel scale; the preset does not hide them.
- The glass UI effect samples the picture the UI is drawn onto, which is the scaled-up scene.
- Cameras with `rasterizationRateMap` ignore the preset.

## Validation

```sh
swift test --filter "PixelPerfect"
```

covers the layout (scale choice, centring on whole pixels, border rounding, fit, small outputs, invalid input, point mapping), the camera's projection, limits and input mapping with the real systems. The GPU check runs the whole engine (camera extraction, target preparation, the 2D render graph with UI and the upscale node) on Metal and reads pixels back: exact picture position and border at several output sizes, hard-edged blocks with no blended colours, fit mode, an ordinary camera unaffected, and UI blocks that land on exact output pixels, including over the border. Run it alone in a fresh process:

```sh
ADAENGINE_PIXEL_PERFECT_METAL_SMOKE=1 swift test --filter PixelPerfectMetalTests
```
