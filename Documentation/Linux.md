# Linux development

The Linux backend uses X11 (including XWayland and WSLg) and the existing WebGPU
renderer. `LinuxSmoke` exercises window/input support; Studio Standalone and
AdaExamples games use the same backend.

## Ubuntu 24.04 / WSL 2

Use Swift 6.3.2 for compatibility with the current Swan/Dawn dependency. The
engine's package remains in Swift 6.2 language mode. Install the Linux toolchain
using [Swiftly](https://www.swift.org/install/linux/), then:

```sh
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config git python3 unzip \
  libx11-dev libasound2-dev libpulse0 libvulkan-dev mesa-vulkan-drivers vulkan-tools \
  libcurl4-openssl-dev libicu-dev libxml2-dev libsqlite3-dev libncurses-dev \
  libedit-dev libblocksruntime-dev libpython3-dev zip gnupg2
```

Start a desktop session and check `DISPLAY`. WSLg supplies an X11 display without
installing a complete Linux desktop. `vulkaninfo --summary` identifies the GPU;
llvmpipe is a software renderer, useful for correctness checks but not GPU
performance measurements.

Use a Linux scratch directory rather than the Windows `.build` directory:

```sh
export ADAENGINE_SKIP_SWIFTLINT=1
export ADAENGINE_LINUX_SCRATCH="$HOME/adaengine-linux-build"
ADAENGINE_HEADLESS=1 swift build --scratch-path "$ADAENGINE_LINUX_SCRATCH" --target AdaPlatform -j 6
```

`ADAENGINE_SKIP_SWIFTLINT=1` bypasses the build-tool lint plugin only. It is useful
while diagnosing platform compilation when unrelated sources have existing lint
errors. Run lint separately on changed sources before submitting changes.

## Swan compatibility

The current Swan checkout provides a Linux Dawn artifact but omits Linux from
the native `WebGPU` target dependency condition. Stage an independent copy:

```sh
mkdir -p "$HOME/adaengine-linux-tools"
git clone https://github.com/adobe/swan.git "$HOME/adaengine-linux-tools/swan-source"
git -C "$HOME/adaengine-linux-tools/swan-source" checkout --detach 1eb45a22c79439b50e9cde774454450e50147149
python3 script/prepare_swan_linux.py "$HOME/adaengine-linux-tools/swan-source" "$HOME/adaengine-linux-tools/swan"
export ADAENGINE_SWAN_PACKAGE_PATH="$HOME/adaengine-linux-tools/swan"
export ADAENGINE_TINT_CACHE="$HOME/adaengine-linux-tools/tint"
export TINT_EXECUTABLE="$(python3 script/ensure_tint.py)"
swift run --scratch-path "$ADAENGINE_LINUX_SCRATCH" -j 6 LinuxSmoke
```

The checkout used for this port is Swan commit
`1eb45a22c79439b50e9cde774454450e50147149`, compatible with Swift 6.3.2 and
SwiftSyntax 602 (the same compatibility requirement as `Tools/Tint/README.md`).
An existing compatible checkout can also be passed to the staging helper.
The helper changes
the platform list in its destination and preserves the original dependency.
It refuses unrecognized manifests and unrelated existing destinations.

An already downloaded, checksum-verified Linux Dawn `.artifactbundle` can be
copied into the staged Swan directory and selected with
`SWAN_LOCAL_DAWN=DawnLinux.artifactbundle` (relative to that package). This avoids
downloading it again through SwiftPM, including when Windows and WSL use different
proxy settings.

## Validation

```sh
ADAENGINE_LINUX_WINDOW_TESTS=1 swift test --scratch-path "$ADAENGINE_LINUX_SCRATCH" \
  --filter 'LinuxPlatformTests|LinuxRuntimeTests' -j 6
python3 -m unittest discover -s script -p test_prepare_swan_linux.py
python3 script/ensure_tint.py --check
ADAENGINE_SWIFT_JOBS=4 bash script/validate_webgpu.sh
```

The window test requires a working X11 display. Headless rendering can validate
native window creation, resizing and teardown; it does not prove rendered pixels.
For graphical verification run `LinuxSmoke`, edit its message, press its button,
resize the native window and close it through the window manager. The executable
prints its render backend and button actions.

The initial screen implementation reports the primary display at scale 1.
Per-monitor scaling, native Wayland, custom cursor textures and native alert
dialogs require further work. Alerts currently appear in the engine log.

## Verified on 2026-10-17

Ubuntu 24.04 under WSL 2 / WSLg, Swift 6.3.2 and Mesa llvmpipe Vulkan:

- `AdaPlatform` and `LinuxSmoke` build successfully.
- All 5 focused Linux runtime/platform tests pass, including real X11 resize,
  keyboard/text delivery, focus-loss releases and `WM_DELETE_WINDOW` teardown.
- All 70 `AdaUtilsTests` / `AdaInputTests` tests pass.
- All 27 focused WebGPU tests pass, including fresh Tint conversion, sprite
  pixel comparisons, picking, tile occlusion and transient attachment lifetime.
- Both Swan staging helper tests pass; the Windows package manifest still loads.
- The native demo displays its UI, accepts Latin and Cyrillic text, responds to
  button clicks, resizes and exits on a native close request.

This is software Vulkan validation. Hardware GPU behavior and a standalone Linux
desktop installation have not yet been verified. The complete engine test suite
has not been run; the module and platform checks above are the tested scope.

## Studio Standalone and games

Install `zenity` for the desktop file/folder chooser. Studio uses the shared AdaUI
workbench, native X11 windows and the Linux run destination. Swift projects and
AdaScript Run in a separate game window are enabled in this Standalone distribution.

Prepare Gravity in a separate directory before building Studio or script games:

```sh
git clone https://github.com/AdaEngine/gravity-lang.git "$HOME/adaengine-linux-tools/gravity-source"
git -C "$HOME/adaengine-linux-tools/gravity-source" checkout --detach 26f80cc250d478b16dbbd21a3a517a669d13f616
python3 script/prepare_gravity_linux.py "$HOME/adaengine-linux-tools/gravity-source" "$HOME/adaengine-linux-tools/gravity"
export ADAENGINE_GRAVITY_PACKAGE_PATH="$HOME/adaengine-linux-tools/gravity"
sudo apt-get install -y zenity
bash script/run_studio_linux.sh
```

Keep the Swan, `SWAN_LOCAL_DAWN` and Tint overrides from the earlier setup.
Gravity's pinned binding needs byte lengths when passing UTF-8 sources to C:
Swift's character count truncates both Cyrillic text and CRLF files. The staging
helper also copies string values with the VM allocator. Original dependencies
remain untouched.

The shared AdaScript lexer recognizes CRLF as one newline. This preserves
declarations after `//` comments in Windows-authored projects and keeps diagnostic
line positions correct for LF, CRLF and CR sources.

The launcher builds Release by default, then packages `AdaEditor`, `gravity-lsp`,
`AdaPackageTool`, resources, Swift runtime libraries, Tint, the AdaScript compiler
and a source `BuildSDK` containing Linux Swan/Dawn. The resulting directory,
`.tar.gz` and checksum are under `~/.cache/adaengine/studio-linux/distributions`.
Run the extracted directory's `./ada-studio`; building Swift games additionally
requires the host Swift toolchain and development packages. Override
`ADA_STUDIO_SCRATCH_PATH`, `ADA_STUDIO_CONFIGURATION`, `ADA_STUDIO_VERSION` or
`ADAENGINE_SWIFT_JOBS` when needed. Use an ext4 scratch directory under WSL.

To run catalog games with the current engine without changing their upstream
checkout:

```sh
git clone https://github.com/AdaEngine/AdaExamples.git "$HOME/AdaExamples"
python3 script/run_example_linux.py "$HOME/AdaExamples/Samples/StarQuest" --product StarQuest
python3 script/run_example_linux.py "$HOME/AdaExamples/Samples/Fold" --product Fold
```

The helper makes a separate editable copy under `~/.cache/adaengine/examples-linux`,
selects this engine by local path and migrates Fold's older reflection API names.
Open AdaScript-only samples such as UnfoldTheWorld through Studio's Open Project
dialog. Under WSLg, `GDK_BACKEND=x11` can select X11 for Zenity as well.

The Linux Studio validation passes 13 focused tests across distribution, Linux
destination/SDK discovery, UTF-8/CRLF AdaScript compilation, localization, scene
script loading, hot reload and project input delivery. Another 23 compiler tests
pass in an isolated package built from the production compiler sources, including
newline positions and scriptable schema discovery after comments.
StarQuest and Fold render native windows; Fold's Jump and Turn controls execute
its AdaScript controller. A 45-second Fold run held shared graphics memory near
105 MiB after excluding transient render attachments from the persistent WebGPU
binding cache. This measurement is a short regression check, not a long-run
performance guarantee.

The packaged debug preview launches from `/tmp` with only `/usr/bin:/bin` in
`PATH`, opens UnfoldTheWorld and runs its scripts in a separate game window: the
drone moves to the closed airlock without UI binding errors. The inline scene
viewport's Play currently stays at the authored positions for this sample; use
the top toolbar's Run button. Inline simulation parity is still incomplete.

Linux scope remains limited: native Wayland, remote AdaPlayer, local ACP agents,
debugger, Cloud sign-in and Web/Android export parity have not been established.
The current MCP dependency logs HTTP startup on Linux but does not open its
listener there. Skeletal Garden's 3D preview reproduces a crash on a llvmpipe worker
inside Mesa's `libvulkan_lvp.so`; this sample is not validated as playable on this
software renderer. A hardware Vulkan desktop still needs separate verification.
