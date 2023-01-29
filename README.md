# AdaEngine

AdaEngine is a game engine fully written on Swift. The main idea is push swift developers to use this game engine to write fast and mindblowing games and user interfaces using Swift as a main language. We hope that AdaEngine can push Swift to GameDev party like Rust and C# does.

AdaEngine based on data oriented paradigm using self written ECS. AdaEngine ECS has been inspired from Apple ReallityKit framework.

## Roadmap AdaEngine v0.1.0

In first release we have a next milestones:

1) Full 2D/3D engine with basics models and materials
2) Supports iOS, macOS and tvOS devices.
3) Multiple rendering backends (Vulkan, Metal with MoltenGL)
4) 2D Physics using box2d
5) Standart support inputs from keyboard/mouse and touches
6) Event system.
7) Sounds.
8) Embeddable views (Insert AdaEngine to you owns projects UIKit/AppKit/SwiftUI)
9) Assets Managment. Loading assets from file and execute them.
10) Documentation and tutorials.

## Contributing to AdaEngine

If you are interested to contibuting to AdaEngine follows the next steps to setup your dev environment.

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

