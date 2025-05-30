//
//  GameAppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/14/22.
//

import AdaApp
import AdaECS
import AdaUI
import Math

/// GameAppScene will present game scene in the pre-configured window.
/// You must use this type of scene if your application should launch a game scene.
public struct GameAppScene: AppScene {

    public typealias SceneBlock = @MainActor @Sendable () throws -> Scene

    public var body: some AppScene {
        EmptyWindow()
            .transformAppWorlds { appWorlds in
                do {
                    let entity = Entity(name: "GameAppScene")
                    entity.components += try DynamicScene(scene: AssetHandle<Scene>(gameScene()))
                    appWorlds.mainWorld.addEntity(entity)
                } catch {
                    fatalError("Error \(error)")
                }
            }
    }

    private let gameScene: SceneBlock
    private let filePath: StaticString

    /// Create a new app scene from a game scene.
    public init(
        scene: @escaping SceneBlock,
        filePath: StaticString = #filePath
    ) {
        self.gameScene = scene
        self.filePath = filePath
    }
}

// MARK: - InternalAppScene

//
//extension GameAppScene: InternalAppScene {
//    @MainActor
//    public func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> Any {
//        let scene = try await self.gameScene()
//
//        let frame = Rect(origin: .zero, size: configuration.minimumSize)
//        let window = UIWindow(frame: frame)
//
//        let gameSceneView = SceneView(scene: scene, frame: frame)
//        gameSceneView.autoresizingRules = [.flexibleWidth, .flexibleHeight]
//        window.addSubview(gameSceneView)
//
//        window.setWindowMode(configuration.windowMode == .fullscreen ? .fullscreen : .windowed)
//        window.minSize = configuration.minimumSize
//
//        if let title = configuration.title {
//            window.title = title
//        }
//
//        return window
//    }
//
//    @MainActor
//    public func _getFilePath() -> StaticString {
//        self.filePath
//    }
//}
