# AdaEditor

AdaEditor is a standalone SwiftPM package for the AdaEngine editor. It contains the `AdaEditor` executable target, UI resources, and tests for editor logic.

## Structure

- `Package.swift` — the editor package manifest.
- `Sources/AdaEditor` — the editor application's source code.
- `Sources/AdaEditor/Assets` — editor assets, including images and fonts.
- `Tests/AdaEditorTests` — editor tests.
- `project.yml` — the XcodeGen configuration for generating the Xcode project.

## Dependencies

The package depends on:

- the local `AdaEngine` package in the parent directory (`.package(path: "..")`).

## Building and Testing

Run the following commands from the `Editor` directory:

```bash
swift build
swift test
```

### Windows

Use Swift 6.3 or newer for the Swan/WebGPU dependency, Visual Studio C++ Build
Tools, Python 3, CMake and Ninja. From the engine root, run:

```powershell
./script/run_studio_windows.ps1
```

The launcher verifies/builds the pinned Tint shader compiler and prepares a
pinned Gravity binding with native string allocation and UTF-8 lengths under
`.build-tools/gravity-windows`; it never edits shared SwiftPM checkouts. It sets
`ADAENGINE_GRAVITY_PACKAGE_PATH`, builds Studio and opens its window.
Use the same dependency override for manual Windows builds/tests:

```powershell
$env:ADAENGINE_GRAVITY_PACKAGE_PATH = python ./script/ensure_windows_gravity.py
swift build --package-path Editor --product AdaEditorPackageTests
swift test --package-path Editor --skip-build --filter EditorWindowsCompatibilityTests
```

`-ScratchPath D:/Temp/ada-studio-build` selects an isolated
SwiftPM cache when the shared cache belongs to another Swift toolchain.
Local Run uses the Windows destination for SwiftPM and embedded AdaScript
projects. Project/folder selection, multi-file asset import and RGB color dialogs
use Windows controls; inspector alpha remains editable. HTTPS clients support
bounded streaming downloads and cancellation. Rendering/readback uses Dawn D3D12.
Ada Cloud browser sign-in/Apple purchases and AdaPlayer device pairing currently
require Apple frameworks and are unavailable on Windows.

## Generating the Xcode Project

Install XcodeGen if it is not already installed, then run:

```bash
cd Editor
xcodegen generate
open AdaEditor.xcodeproj
```

The generated project uses the local `AdaEditor` SwiftPM package. To build and run the editor, select the `AdaEditor (Editor)` scheme that Xcode creates for the package's executable product.

## Command Line

The standalone macOS bundle also includes the `adastudio` command-line entry for
project inspection, validation and AdaScript app builds. See [CLI](Documentation/CLI.md)
for commands, SDK prerequisites and the JSON contract. iOS uses its existing
embedded validation and Play services.

## TestFlight

Fastlane can build a signed iPadOS IPA (`bundle exec fastlane ios build`) or build
and upload it (`bundle exec fastlane ios beta`). See
[TestFlight setup](fastlane/SETUP.md) for signing prerequisites, versioning, and
private environment variables. No credentials belong in the public repository.

## Offline Documentation

Open **Help > AdaEngine Documentation**, or use the **Documentation** button on the welcome screen or editor toolbar. The native SwiftUI reader includes full-text guide search, section navigation, Back/Forward history, and copyable code examples. On macOS it opens a reusable window; on iPadOS it opens an in-app reader with a Done button.

The bundled library contains the editor guide and substantive Markdown articles from the AdaEngine and AdaScripting DocC catalogs. It works without internet or a source checkout. Generated API reference pages and external websites are not bundled; external links are labeled **Internet**.

After changing a source article, regenerate and verify the checked-in snapshot:

```bash
python3 scripts/update-offline-documentation.py
python3 scripts/update-offline-documentation.py --check
```

The snapshot lives in `Sources/AdaEditor/Assets/Documentation/catalog.json` and ships through the existing SwiftPM `Assets` resource copy, including the macOS and iPadOS app wrappers. The generator preserves code examples, removes DocC presentation metadata, and validates internal article links.

### Android

Standalone macOS Studio supports **Build → Export to Android…** and Android
Run Destinations with connected devices and AVDs. Swift and AdaScript projects
use the native Swift/WebGPU Android host. Configure **Settings → Build & Export → Android** and
see [Android export and run](Documentation/Android.md).

Build & Export also groups iOS, Web, Windows, Linux, macOS and VR / XR tool paths.
See [build tool settings and platform availability](Documentation/BuildExport.md).

Official games and feature examples are available from the HUB Samples section.
See [Examples.md](Documentation/Examples.md) for downloading editable projects and local catalog development.
