# Native Spine demo

This separate Swift package runs `SpinePlugin` in an AdaEngine native window.
It uses the licensed example assets beside `../SpinePreview/Assets`.

Run from the engine checkout:

```
swift run --package-path Demos/SpineNative SpineNative
```

On Windows use the native toolchain/dependencies prepared by
`script/build_studio_windows.ps1`. Set `TINT_EXECUTABLE` to the verified Tint
binary and `ADA_MCP_LOCAL_PATH` to the Windows AdaMCP package prepared by
`script/ensure_windows_mcp.py`. `ADAENGINE_PACKAGE_PATH` must point to this
engine checkout, and `ADAENGINE_GRAVITY_PACKAGE_PATH` can select the prepared
Windows Gravity package. Do not enable `ADAENGINE_HEADLESS`.

Windows capture requires the AdaMCP compatibility package with asynchronous
GPU readback; unpatched AdaMCP 0.2.0 uses the unsupported synchronous texture
accessor. The compatible MCP holds exclusive world access during capture, since a
native frame must not replace the target while its readback is pending.

AdaMCP listens at `http://127.0.0.1:2511/mcp` so Studio can keep port 2510.
Discovery is disabled because the endpoint is explicit.
Use `spine.pose` (`animation`, `time`, `playing`) followed by
`render.capture_screenshot` for repeatable captures from the actual engine GPU
output. `runtime.resume` resumes the engine after capture pauses it.

With the app running, capture three poses and optionally a walk sequence:

```
python Demos/SpineNative/capture.py <output-directory> --frames 30
```

The capture report includes backend/render-graph metadata, camera, native
dimensions, original GPU capture paths and exact pose times.

Validated on Windows with NVIDIA RTX 4070 / D3D12: native 1000×760 PNGs for
walk, run and jump, followed by 32-frame and 90-frame capture sequences. These
use the actual Spine render systems, GPU textures and AdaMCP capture service.
