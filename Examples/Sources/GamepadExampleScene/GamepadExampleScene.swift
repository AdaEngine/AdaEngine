import AdaEngine

// Define a simple component to mark our player entity
struct PlayerComponent: Component {}

class GamepadExampleScene {

    // Method to create and configure the scene
    static func makeScene() -> Scene {
        let scene = Scene()

        // Setup a camera
        let cameraEntity = Entity(name: "Camera")
        let camera = Camera()
        camera.isOrthographic = true
        camera.projection = .orthographic(size: 10, near: 0.1, far: 100)
        cameraEntity.components.add(camera)
        cameraEntity.components.add(Transform(position: [0, 0, 10]))
        scene.addEntity(cameraEntity)

        // Create a simple player entity
        let playerEntity = Entity(name: "Player")
        playerEntity.components.add(PlayerComponent())
        playerEntity.components.add(Transform(scale: [0.5, 0.5, 0.5])) // So it's visible
        // Add a Sprite or some visual component if easy, otherwise Transform is fine for console output.
        // For simplicity, we'll focus on console output for inputs.
        scene.addEntity(playerEntity)

        // Add a system to process gamepad input
        let system = GamepadInputSystem(scene: scene) // Pass scene to system initializer
        scene.addSystem(system)
        
        print("Gamepad Example Scene Initialized. Connect a gamepad to see input.")

        return scene
    }
}

// Define a system to handle gamepad inputs
struct GamepadInputSystem: System {

    static let playerQuery = EntityQuery(where: .has(PlayerComponent.self) && .has(Transform.self))

    init(scene: Scene) { }

    func update(context: UpdateContext) {
        // Get all connected gamepad IDs
        let gamepadIds = Input.getConnectedGamepadIds()

        if gamepadIds.isEmpty {
            // print("No gamepads connected.") // This might be too verbose for every frame
            return
        }

        for id in gamepadIds {
            if Input.isGamepadConnected(gamepadId: id) {
                if let info = Input.getGamepadInfo(gamepadId: id) {
                    // Only print connection info once or less frequently if needed
                    // For this example, printing it can be helpful for debugging.
                     print("Gamepad \(id) (\(info.name ) - \(info.type ?? "N/A")) is connected.")
                }

                // Check some common buttons
                if Input.isGamepadButtonPressed(id, button: .a) {
                    print("Gamepad \(id): Button A Pressed")
                }
                if Input.isGamepadButtonPressed(id, button: .b) {
                    print("Gamepad \(id): Button B Pressed")
                }
                if Input.isGamepadButtonPressed(id, button: .leftShoulder) {
                    print("Gamepad \(id): Left Shoulder Pressed")
                }

                // Read some common axes
                let leftStickX = Input.getGamepadAxisValue(id, axis: .leftStickX)
                let leftStickY = Input.getGamepadAxisValue(id, axis: .leftStickY)

                if abs(leftStickX) > 0.1 || abs(leftStickY) > 0.1 { // Add a deadzone to avoid spam
                    print("Gamepad \(id): Left Stick X: \(leftStickX.format(.fixed(precision: 2))), Y: \(leftStickY.format(.fixed(precision: 2)))")
                }
                
                // Example of using axis value to move the player entity
                context.scene.performQuery(Self.playerQuery).forEach { entity in
                    var transform = entity.components[Transform.self]!
                    // Assuming Y-axis from gamepad is inverted for typical 2D top-down movement (positive Y up)
                    transform.position.x += leftStickX * Float(context.deltaTime) * 2.0 // Adjust speed factor as needed
                    transform.position.y -= leftStickY * Float(context.deltaTime) * 2.0 // Inverted Y
                    entity.components[Transform.self] = transform
                }

                // Check for a specific button to trigger rumble (e.g., X button)
                if Input.isGamepadButtonPressed(id, button: .x) {
                    print("Gamepad \(id): Button X Pressed - Requesting Rumble")
                    Input.rumbleGamepad(gamepadId: id, lowFrequency: 0.5, highFrequency: 0.75, duration: 0.5)
                }

            } else {
                print("Gamepad \(id) was in list but now reports disconnected.")
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
