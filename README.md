# AdaEngine

AdaEngine is a game engine fully written in Swift. The main idea is to encourage Swift developers to use this game engine to create fast and impressive games and user interfaces using Swift as their main language. We hope that AdaEngine can become as popular in the GameDev community as Rust and C# are.

![Screenshot from test game SpaceInvaders](Assets/space_invaders.jpeg)

# Features

1) AdaEngine is based on the data-oriented paradigm using a self-written ECS. The AdaEngine ECS has been inspired by Apple's RealityKit framework. ECS provides a fast way to work with the game world because it is more friendly to CPU caches.
2) AdaEngine is easy to use, and our main goal is to enable a quick start and deliver quick results.

## Roadmap for AdaEngine v0.1.0

In the first release, we have the following milestones:

1) Full 2D support with basic models and materials
2) Support for iOS, macOS, and tvOS devices
3) Metal render backend (for now)
4) 2D Physics using Box2D
5) Standard support for inputs from the keyboard/mouse and touch
6) Event System
7) Audio System
8) Embeddable views (you can insert AdaEngine into your own projects that use UIKit/AppKit/SwiftUI)
9) Asset management, loading assets from files and executing them
10) Documentation and tutorials

## Roadmap for AdaEngine v0.2.0

1) UI interface for games and apps
2) Vulkan and GLSL support
3) 3D capabilities
4) 3D Physics
5) More documentation and tutorials

## Contributing to AdaEngine

You are welcome to contribute to AdaEngine. Currently, it is under development, and we are working towards our roadmap goals. If you find a bug or have some improvements, we would be glad to see your pull request!

## How to build

Currently we use Bazel and Swift Package Manager as build tools. 

* Bazel 

Bazel is major build system for project, SPM maybe will be removed in future versions. To build project for development download [Bazelisk](https://github.com/bazelbuild/bazelisk). To generate xcproject, use `make xcproj` command in terminal. 

* Swift Package Manager

Use Xcode 15 or Visual Studio Code with the [Swift VSCode Extension](https://www.swift.org/blog/vscode-extension/) and then open `Package.swift` file from the root directory. 