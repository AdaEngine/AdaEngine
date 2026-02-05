import AdaEngine

@Component
struct PlayerComponent {}

@main
struct GamepadInputApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .transformAppWorlds { appWorld in
                appWorld.spawn(
                    "Camera",
                    bundle: Camera2D(
                        camera: Camera(),
                        transform: Transform(position: [0, 0, 0])
                    )
                )

                appWorld.spawn("Player") {
                    PlayerComponent()
                    Transform(scale: .init(0.5))
                    Sprite(tintColor: .red)
                }
            }
            .windowMode(.windowed)
            .windowTitle("Gamepad Input")
    }
}
