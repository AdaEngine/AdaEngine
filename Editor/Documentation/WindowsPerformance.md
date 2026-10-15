# Windows Studio performance

Measure the Release executable on a visible, foreground window after startup and
shader compilation have finished. Compilation, screenshots and detailed CPU tracing
must not run during the FPS capture. Repeat with the same project, viewport,
window size and monitor for before/after comparisons.

## Reproduce

Build with `script/build_studio_windows.ps1 -Configuration release -Jobs 4`.
Launch the resulting `AdaEditor.exe`, or extract and launch the portable ZIP
produced by `script/package_studio_windows.py`.

Download the console application from the official
[PresentMon releases](https://github.com/GameTechDev/PresentMon/releases).
For PresentMon 2.6.0 x64, the SHA-256 used in this validation is
`b2a706bc6ad475749e3b7e3409263aa1e6906d45bdcf993f6dbc0f660188f1af`.
Select the Studio PID (not another running Debug instance), then run:

```powershell
PresentMon.exe --process_id <PID> --session_name AdaStudioPerf --delay 5 `
  --timed 30 --terminate_after_timed --no_console_stats --output_file editor.csv
python script/summarize_presentmon.py editor.csv --output editor-summary.json
```

The script reads PresentMon's default hybrid CSV. It reports each swapchain
separately and excludes the first interval, whose previous frame lies outside
the capture. Present FPS, display FPS, p95/p99, worst intervals and intervals
above 25 ms are distinct metrics. Missing display/GPU data stays unavailable.
Do not add together FPS from multiple Studio windows. The reciprocal of GPU
busy time is not display FPS. See the official
[PresentMon console documentation](https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md)
for metric definitions.

## Windows timing

`Time.absolute` uses QueryPerformanceCounter and caches its immutable frequency.
The previous Foundation uptime clock advanced in approximately 15 ms steps on
the tested Windows Swift toolchain. That is too coarse for a 16.67 ms frame.
Microsoft documents QPC's monotonic interval clock and fixed frequency in
[Acquiring high-resolution time stamps](https://learn.microsoft.com/en-us/windows/win32/sysinfo/acquiring-high-resolution-time-stamps).

Studio requests display synchronization on Windows. The existing WebGPU FIFO
swapchain provides the visible window's pacing; the Windows application loop
does not add another `Task.sleep` after a display-paced frame. Fixed-rate,
headless and fully hidden/minimized configurations retain the timed fallback.
This also lets Studio follow monitors with refresh rates above 60 Hz.

## Validation machine

2026-10-15: Windows 11 Pro 10.0.26200, Swift 6.3.1, Ryzen 9 7900X,
32 GB RAM, NVIDIA RTX 4070, D3D12/WebGPU. Native `EnumDisplayDevicesW` /
`EnumDisplaySettingsW(ENUM_CURRENT_SETTINGS)` report the attached primary display
as 2560×1080 at 144 Hz. CIM's video-controller inventory instead reported stale
60/143 Hz adapter modes; do not use that inventory as the active monitor rate.
Editor captures use the primary display, a maximized 2560×1032 client and the
existing My_Gam scene with one root entity.

The baseline at commit `9188df5c`, before timing changes, recorded 32.58 present
FPS and 32.58 displayed FPS over 29.56 seconds (963 measured intervals).
Present p95/p99 were 32.27/390.50 ms, with a worst interval of 426.41 ms.
GPU busy time averaged 4.18 ms, with p95 7.48 ms. Replacing the clock alone
left the extra sleep in place: 28.53 present/display FPS, p95 32.42 ms.
With the display-pacing change, 30-second captures recorded:

| Workload | Present FPS | Display FPS | Present p95 / p99 | Worst present interval |
| --- | ---: | ---: | ---: | ---: |
| 2D editor, idle | 143.99 | 144.00 | 7.37 / 7.81 ms | 12.63 ms |
| 3D editor, idle | 143.95 | 143.94 | 7.39 / 8.41 ms | 14.79 ms |

Both idle captures had zero intervals above the 16.67 ms budget for 60 FPS.
Input testing then exposed another issue: native wheel zoom reached 123.75 FPS
on average but had p99 96.66 ms / worst 111.28 ms. A separate 500 ms CPU capture
located a 231 ms update in `AdaUI.UpdateWindowManagerSystem`; it is diagnostic
evidence, not an FPS measurement. Caption hit-region collection previously walked
the whole UI twice on each layout, including content outside the caption. It now
uses one pass, filters controls by caption geometry before protocol checks, and
prunes clipping ancestors outside the caption while preserving overflowing controls
in non-clipping containers. Camera movement also updates a localized observable
presentation model for the rulers/status rather than rebuilding the viewport host.

The larger Skeletal Garden scene (539 entities) exposed a second caption issue.
The command closure in the caption environment was recreated on every layout.
Environment comparison treated each closure-bearing value as changed, invalidating
geometry content and reconciling the complete hierarchy again. With a game window
open, a bounded CPU capture recorded 2282.01 ms in `AdaUI.UpdateWindowManagerSystem`;
PresentMon measured 0.427 present/display FPS per window (five intervals spanning
11.71 seconds, worst 2352.39 ms). This is a UI stall, not the reciprocal of GPU time.
Caption presentation now has a stable, weakly window-bound command target and
value equality for its visible state. The hierarchy uses lazy rows with a 34-point
height estimate, keeping distant entities accessible through scrolling.

The editor navigation camera now inherits the active authored camera's background,
IBL and quality settings. Previously it used a separate default environment and
forced reflections on in 3D, so the preview did not match Run. Authored lighting
values are preserved; comparison screenshots must use the same pose and settings.

After the stable caption fix, the same 539-entity garden recorded 34.79 present
FPS in the maximized editor (p95/p99 30.80/32.49 ms, worst 42.70 ms). Running
the game alongside its editor preview recorded 13.30 FPS per native window
(p95/p99 90.74/94.68 ms, worst 147.14 ms). These intermediate captures are
`garden-final-idle.csv` and `garden-final-game.csv`; their names predate the
subsequent annotation caching and inactive-preview changes and do not describe
the final implementation. They establish that removing the multi-second UI stall
alone did not achieve 60 FPS on this scene.

The next changes retain the grid and gizmo drawing groups until navigation or
scene edits invalidate them. The live scene texture remains independent. Editor
`SceneView` opts out of updates while its window is inactive; its coordinator
suspends the complete preview runtime (including its render subworld) in the
host's automatic frame loop and resumes the same runtime on activation. It stays
registered for ACP/MCP discovery, inspection and explicit updates. The game keeps
the default background-update behavior. Native Debug validation confirmed a
right-button camera rotation updates both the scene and annotations, and that
the scene and annotations resume correctly after switching between the editor and the
native game window. The initial detach-based implementation was replaced to
preserve tooling access while the editor is inactive.

Focused validation passed 32 editor tests covering retained annotations, local
presentation invalidation, preview suspension/resumption, authored environment,
lazy hierarchy/file-tree selection, stable play inspection and gizmo interaction.
A fully started Run activity keeps its progress indicator static; unfinished
operations still animate. This avoids continuously redrawing the editor while
the game is running. Another 58 AdaUI tests cover
caption stability/regions, environment propagation, lazy stacks and offscreen
input/lifecycle behavior, including both inactive-update policies. These runs do
not establish display FPS. Broader headless rendering suites still encounter
the existing combined-sampler GLSL compilation failure; native D3D12 rendering
was exercised separately.

Stopping the background scene by itself recorded 21.49 FPS in the game and the
editor's separate native swapchain, with game p95/p99 63.58/65.79 ms. A bounded
CPU capture still measured repeated editor UI drawing/tessellation and natural
sorting of the live entity list. The project navigator now mounts only visible
rows, and the play entity picker preserves its sorted inventory between unchanged
refreshes while continuing to refresh selected component values.

The WebGPU pipeline's bind-group cache previously cleared every entry after
512 distinct bindings. A large scene multiplies material bindings across buffered
uniforms and shadow cascades, so that limit can repeatedly discard the active
working set. Its limit is now 8192, with a bounded FIFO ring that evicts one entry
on overflow rather than discarding unrelated bindings. Cached owners remain
retained to prevent resource identity reuse; eviction releases them. The cache
tests include capacity overflow, failed creation, ring wraparound, independent
copies and a 539 × 3 × 3 binding working set.

The main 3D pass also uses a per-camera ring of view-uniform buffers. Inline
camera bytes allocated a fresh WebGPU buffer on every pass, changing the resource
identity in every material's bind-group key each frame. Reusing the buffered
uniforms preserves those keys while uploading the current matrices, including
temporal jitter. Tests read back the uploaded matrices, verify the in-flight
buffer count and check that different cameras and removed views keep independent
buffer lifetimes. The six binding-cache tests passed, and the native Windows
`script/validate_webgpu.sh` run passed seven tests, including fresh Tint
conversion and GPU-pixel checks, with the pinned Dawn backend and Swift 6.3.1.

Keep detailed CPU captures short: their JSONL recording/decoding changes timing.
Five-second detailed captures produced large in-memory results on this machine;
they are excluded from the display-FPS results above.

These captures establish performance for the measured Studio workloads on this
machine. They do not establish a minimum FPS for arbitrary user scenes or hardware.
