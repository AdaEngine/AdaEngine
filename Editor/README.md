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

## Generating the Xcode Project

Install XcodeGen if it is not already installed, then run:

```bash
cd Editor
xcodegen generate
open AdaEditor.xcodeproj
```

The generated project uses the local `AdaEditor` SwiftPM package. To build and run the editor, select the `AdaEditor (Editor)` scheme that Xcode creates for the package's executable product.
