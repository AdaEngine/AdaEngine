# AdaEngine

AdaEngine is a game engine fully written on Swift. The main idea is push swift developers to use this game engine to write fast and mindblowing games and user interfaces using Swift as a main language. We hope that AdaEngine can push Swift to GameDev party like Rust and C# does. 

# Features

1) AdaEngine based on data oriented paradigm using self written ECS. AdaEngine ECS has been inspired from Apple ReallityKit framework. ECS gives you a fast way to works with game world, because it's more friendly for CPU caches.
2) Easy to use. Our main goal is fast start and quick result.

## Roadmap AdaEngine v0.1.0

In first release we have a next milestones:

1) Full 2D with basics models and materials
2) Supports iOS, macOS and tvOS devices.
3) Metal render backend for now
4) 2D Physics using box2d.
5) Standart support inputs from keyboard/mouse and touches
6) Event system.
7) Sounds.
8) Embeddable views (Insert AdaEngine to you owns projects UIKit/AppKit/SwiftUI)
9) Assets Managment. Loading assets from file and execute them.
10) Documentation and tutorials.

## Roadmap AdaEnginge v0.2.0

1) UI interface for your games and apps
2) Vulkan and GLSL support
3) 3D capabilities
4) 3D Physics
5) More documentations and tutorials

## Contributing to AdaEngine

You are welcome to contibute to AdaEngine. Currently it's under development and we target to our roadmap goals, but I you find a bug or some improvements we will glad to see your Pull Request!

## How to build

Download Xcode 14.2 or Visual Studio Code with [Swift VSCode Extension](https://www.swift.org/blog/vscode-extension/).
We also recommended you using [Tuist](https://github.com/tuist/tuist) for generating xcode project, but for other platforms Swift Package Manager is only way.