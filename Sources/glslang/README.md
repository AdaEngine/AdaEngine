# Glslang

This is a set of tools to compile SPIR-V binary from GLSL and HLSL. Supports Swift Package Manager.
For more details see also [KhronosGroup/glslang](https://github.com/KhronosGroup/glslang).

## Installation

```swift

dependencies: [
// ...
    .package(url: "https://github.com/AdaEngine/glslang", from: "main")
// ...
]

```

Also set `-enable-experimental-cxx-interop` to your executable target in `swiftSettings` like so:

```swift

.target(
    name: "MyApp",
    swiftSettings: [
        .unsafeFlags(["-enable-experimental-cxx-interop"])
    ]
)

```

In the end of the package set the `cxxLanguageStandard` to `.cxx20`.