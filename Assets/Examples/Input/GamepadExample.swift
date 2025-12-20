import AdaEngine

// Define a simple component to mark our player entity
@Component
struct PlayerComponent {}

@main
struct GamepadExampleApp: App {
    var body: some AppScene {
        EmptyWindow()
            .transformAppWorlds { appWorld in
                appWorld.spawn(
                    "Camera",
                    bundle: Camera2D(
                        camera: Camera(),
                        transform: Transform(position: [0, 0, 0])
                    )
                )

                // Create a simple player entity
                appWorld.spawn("Player") {
                    PlayerComponent()
                    Transform(scale: .init(0.5))
                    Sprite(tintColor: .red)
                }

                // Add a system to process gamepad input
                appWorld.addSystem(GamepadInputSystem.self)
            }
            .addPlugins(DefaultPlugins())
            .windowMode(.windowed)
    }
}

// Define a system to handle gamepad inputs
@PlainSystem
struct GamepadInputSystem {

    @FilterQuery<Ref<Transform>, With<PlayerComponent>>
    private var playerQuery

    @Res<Input>
    private var input

    @Res<DeltaTime>
    private var deltaTime

    init(world: World) { }

    func update(context: UpdateContext) {
        // Get all connected gamepad IDs
        let gamepads = input.getConnectedGamepads()

        if gamepads.isEmpty {
            // print("No gamepads connected.") // This might be too verbose for every frame
            return
        }

        for gamepad in gamepads {
            if let info = gamepad.info {
                // Only print connection info once or less frequently if needed
                // For this example, printing it can be helpful for debugging.
                print("Gamepad \(gamepad.gamepadId) (\(info.name ) - \(info.type ?? "N/A")) is connected.")
            }

            // Check some common buttons
            if gamepad.isGamepadButtonPressed(.a) {
                print("Gamepad \(gamepad.gamepadId): Button A Pressed")
            }
            if gamepad.isGamepadButtonPressed(.b) {
                print("Gamepad \(gamepad.gamepadId): Button B Pressed")
            }
            if gamepad.isGamepadButtonPressed(.leftShoulder) {
                print("Gamepad \(gamepad.gamepadId): Left Shoulder Pressed")
            }

            // Read some common axes
            let leftStickX = gamepad.getAxisValue(.leftStickX)
            let leftStickY = gamepad.getAxisValue(.leftStickY)

            if abs(leftStickX) > 0.1 || abs(leftStickY) > 0.1 { // Add a deadzone to avoid spam
                print("Gamepad \(gamepad.gamepadId): Left Stick X: \(leftStickX.format(.fixed(precision: 2))), Y: \(leftStickY.format(.fixed(precision: 2)))")
            }

            // Example of using axis value to move the player entity
            playerQuery.forEach { transform in
                // Assuming Y-axis from gamepad is inverted for typical 2D top-down movement (positive Y up)
                transform.position.x += leftStickX * Float(deltaTime.deltaTime) * 2.0 // Adjust speed factor as needed
                transform.position.y -= leftStickY * Float(deltaTime.deltaTime) * 2.0 // Inverted Y
            }

            // Check for a specific button to trigger rumble (e.g., X button)
            if gamepad.isGamepadButtonPressed(.x) {
                print("Gamepad \(gamepad.gamepadId): Button X Pressed - Requesting Rumble")
                gamepad.rumble(lowFrequency: 0.5, highFrequency: 0.75, duration: 0.5)
            }
        }
    }
}

// Helper for formatting float values in print statements
extension Float {
    enum FormatStyle { // Renamed to avoid conflict with Foundation.FormatStyle if ever imported
        case fixed(precision: Int)
    }

    func format(_ style: FormatStyle) -> String {
        switch style {
        case .fixed(let precision):
            return String(format: "%.\(precision)f", self)
        }
    }
}
