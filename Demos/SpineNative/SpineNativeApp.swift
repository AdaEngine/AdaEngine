import AdaEngine
import AdaMCPCore
import AdaMCPPlugin
import AdaSpine
import Foundation
import MCP

/// Runs the production Spine render systems in a native window, with AdaMCP GPU capture.
@main
struct SpineNativeApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(SpinePlugin(), SpineDemoPlugin())
            .window(with: UIWindow.Configuration(
                title: "AdaEngine · Spine 4.2 · native GPU",
                frame: Rect(x: 100, y: 80, width: 1000, height: 760)
            ))
    }
}

private struct SpineDemoPlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.addSystem(StartupSpineDemoSystem.self, on: .startup)
        let worlds = copy app
        app.addPlugin(MCPPlugin(configuration: .init(
            port: 2511,
            serverName: "AdaEngine Spine native demo",
            additionalTools: {
                [Tool(
                    name: "spine.pose",
                    description: "Select a Spine animation and exact time, optionally continuing playback.",
                    inputSchema: .object([
                        "type": "object",
                        "properties": .object([
                            "animation": .object(["type": "string"]),
                            "time": .object(["type": "number", "minimum": 0]),
                            "playing": .object(["type": "boolean"]),
                        ]),
                        "required": ["animation"],
                    ])
                )]
            },
            additionalToolHandler: { name, arguments in
                guard name == "spine.pose" else { return nil }
                do {
                    let message = try await worlds.withWorldAccess {
                        try selectSpinePose(in: worlds.main, arguments: arguments)
                    }
                    return .init(content: [.text(text: message, annotations: nil, _meta: nil)])
                } catch {
                    return .init(content: [.text(text: String(describing: error), annotations: nil, _meta: nil)], isError: true)
                }
            },
            enableDiscovery: false
        )))
    }
}

@MainActor
private func selectSpinePose(in world: World, arguments: [String: Value]) throws -> String {
    guard case let .string(clip)? = arguments["animation"],
          let entity = world.getEntities().first(where: { $0.components[SpineAnimation.self] != nil }),
          var animation = entity.components[SpineAnimation.self] else {
        throw SpineError.invalidData("Spine character is not ready.")
    }
    let time: Float
    switch arguments["time"] {
    case let .double(value): time = Float(value)
    case let .int(value): time = Float(value)
    default: time = 0
    }
    guard time.isFinite, time >= 0, animation.player.animationNames.contains(clip) else {
        throw SpineError.invalidData("Select an existing animation and a finite, non-negative time.")
    }
    animation.player.resetToSetupPose()
    try animation.player.play(clip, repeats: clip != "jump", transitionDuration: 0)
    animation.player.advance(by: time)
    animation.isPaused = arguments["playing"] != .bool(true)
    entity.components[SpineAnimation.self] = animation
    let vertices = animation.player.snapshot().flatMap(\.vertices)
    if let minX = vertices.map(\.x).min(), let maxX = vertices.map(\.x).max(),
       let minY = vertices.map(\.y).min(), let maxY = vertices.map(\.y).max(),
       let owner = entity.components[Transform.self],
       let cameraEntity = world.getEntities().first(where: { $0.components[Camera.self] != nil }),
       var camera = cameraEntity.components[Camera.self] {
        camera.projection = .custom(SpineDemoProjection(center: [
            owner.position.x + (minX + maxX) / 2, owner.position.y + (minY + maxY) / 2,
        ]))
        cameraEntity.components[Camera.self] = camera
    }
    return "\(clip) at \(time)s; bones=\(animation.player.boneSnapshot().count)"
}

@System
@MainActor
func StartupSpineDemo(_ context: WorldUpdateContext) async {
    do {
        let demoDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let assets = demoDirectory.appendingPathComponent("../SpinePreview/Assets").standardizedFileURL
        let image = try await AssetsManager.load(Image.self, at: assets.appendingPathComponent("spineboy.png").path)
        guard let sourceImage = image.asset else { throw SpineError.invalidData("Atlas image is not loaded.") }
        let texture = AssetHandle(Texture2D(image: sourceImage, samplerDescription: .init(minFilter: .linear, magFilter: .linear)))
        let skeleton = try SpineSkeleton(
            skeleton: Data(contentsOf: assets.appendingPathComponent("spineboy-pro.skel")),
            atlas: String(contentsOf: assets.appendingPathComponent("spineboy.atlas"), encoding: .utf8),
            textures: [texture],
            format: .binary
        )
        let animation = try SpineAnimation(skeleton: skeleton)
        try animation.player.play("walk", transitionDuration: 0)
        context.world.spawn("Spineboy") {
            animation
            Transform(position: [-50, -280, 0])
            NoFrustumCulling()
        }
        var camera = Camera()
        camera.projection = .custom(SpineDemoProjection())
        camera.backgroundColor = Color(0.035, 0.055, 0.10, 1)
        context.world.spawn("Spine Camera") {
            camera
            Transform()
            GlobalViewUniform()
            VisibleEntities()
            Visibility.visible
            CameraRenderGraph(subgraphLabel: .main2D, inputSlot: Main2DRenderNode.InputNode.view)
        }
        print("[SpineNative] Ready: native renderer; AdaMCP http://127.0.0.1:2511/mcp")
    } catch {
        print("[SpineNative] Failed to load character: \(error)")
    }
}

private struct SpineDemoProjection: CameraProjection {
    var center: Vector2 = [15, 60]
    var near: Float { -1 }
    var far: Float { 1000 }
    func makeClipView() -> Transform3D {
        Transform3D(scale: [2 / 1000, 2 / 760, 0.001]) * Transform3D(translation: [-center.x, -center.y, 0])
    }
    mutating func updateView(width: Float, height: Float) {}
}
