# AdaEngine

A description of this package.

## Start

### macOS

Download and install vulkan-sdk LunarG

To install pkg-config for vulkan, call Make function

```bash
$ make install_vulkan
```

If all installed correct, you got message:

```
$ pkg-config --libs --cflags vulkan
-I/usr/local/include  -L/usr/local/lib -lvulkan
```

Make sure, that you have vulkan headers by path: `/usr/local/include/vulkan/`

Another tutorial [how to install vulkan to SPM](https://blog.spencerkohan.com/vulkan-swift-linking-moltenvk-using-swift-package-manager/)

## Compile shaders for Vulkan

While waiting Swift Package Manager build plugins we use manual compilation for `glsl` shaders using `glslc` compiler.

Call next command in terminal `make compile_shaders` to compile all shaders by path `/Sources/AdaEngine/Rendering/Shaders/`


## Roadmap AdaEngine v0.1.0

1) Full 3D engine with basics models and materials
2) Full support Apple platforms
3) Multiple rendering backends (Vulkan, Metal with MoltenGL)
4) Physics
5) Standart support inputs from keyboard/mouse and touches
6) Event system
7) Sounds
