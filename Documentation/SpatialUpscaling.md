# Spatial upscaling

Enable lower-resolution window rendering through the existing scene modifier:

```swift
WindowGroup {
    GameScene()
}
.renderUpscaling(.spatial(renderScale: 0.75))
```

The scale is linear and clamped to `0.5...1`. A scale of `0.75` renders approximately
56% of the output pixel count. iOS defaults to 75%; other platforms keep native
resolution unless explicitly configured. Pixel-perfect cameras use their own
nearest-neighbor presentation and bypass spatial reconstruction.

| Backend | Spatial reconstruction |
| --- | --- |
| Metal on supported macOS/iOS devices | MetalFX Spatial |
| WebGPU, including browser WebAssembly | AMD FSR 1: EASU followed by RCAS |
| Unsupported backend | Native render resolution |

FSR 1 is spatial: it needs the current color frame and does not use history,
motion vectors, temporal reconstruction, or frame generation. It does not
replace temporal antialiasing. Render antialiased, tone-mapped content before
upscaling.

The WebGPU implementation uses full-precision WGSL with clamped texel loads.
EASU reconstructs RGB into an `rgba16float` intermediate; RCAS sharpens into the
output attachment with a fixed sharpness reduction of 0.2 stops. Alpha is bilinear
in EASU and passed through RCAS. The path accepts single-sample 2D RGBA8/BGRA8
UNORM color textures and destinations, including RGBA Android swapchains. HDR,
sRGB views, downscaling, and equal-sized images use the existing presentation
fallback. No optional WebGPU device features are required.

Pipelines and up to eight immutable size configurations are cached per device.
Cached configurations retain intermediate textures and scale constants; source
textures and swapchain drawables are retained only by encoded commands. Multiple
views can be encoded before submission without overwriting each other's scale
constants.

The WGSL implementation is adapted from AMD's MIT-licensed
[`ffx_fsr1.h` v1.20210629](https://github.com/GPUOpen-Effects/FidelityFX-FSR/blob/master/ffx-fsr/ffx_fsr1.h).
The upstream license is preserved in `WGPUFSRShaders.swift`.
The upstream header used for the port has SHA-256
`93c3922362ea7fc99cbcc698ca30c98de4f8c246d1fbb0b09e015ddef38ce3a5`.

Run `script/validate_webgpu.sh` with the compatible Swift 6.3.2 toolchain. It
includes `Render3DGPUTests/FSR`: GPU readback covers flat channels, borders, both
output formats, cache eviction, queued views, alpha preservation, and a diagonal
edge that must differ from bilinear presentation. Other renderer tests remain
serialized under `Render3DGPUTests`.
