//
//  InputManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/2/21.
//

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

// - TODO: (Vlad) Add actions list and method like `isActionPressed`

/// An object that contains inputs from keyboards, mouse, touch screens and etc.
public final class Input {

    nonisolated(unsafe) internal static let shared = Input()

    internal var mousePosition: Point = .zero

    private static let lock = NSLock()

    internal private(set) var eventsPool: [InputEvent] = []

    // FIXME: (Vlad) Should think about capacity. We should store ~256 keycode events
    internal private(set) var keyEvents: Set<KeyCode> = []
    internal private(set) var mouseEvents: [MouseButton: MouseEvent] = [:]
    internal private(set) var touches: Set<TouchEvent> = []

    // Gamepad state
    /// Contains information about a connected gamepad.
    public struct GamepadInfo: Sendable {
        /// The name of the gamepad, often provided by the system or manufacturer.
        public let name: String
        /// An optional string describing the type or category of the gamepad (e.g., "Xbox Controller", "DualShock 4").
        public let type: String?

        internal init(name: String, type: String? = nil) {
            self.name = name
            self.type = type
        }
    }

    internal struct GamepadState {
        let gamepadId: Int
        var buttonsPressed: Set<GamepadButton> = []
        var axisValues: [GamepadAxis: Float] = [:]
        var info: GamepadInfo? // TODO: Populate this later

        init(gamepadId: Int, info: GamepadInfo? = nil) {
            self.gamepadId = gamepadId
            self.info = info
            // Initialize all axes to 0.0
            for axis in [GamepadAxis.leftStickX, .leftStickY, .rightStickX, .rightStickY, .leftTrigger, .rightTrigger] {
                axisValues[axis] = 0.0
            }
        }
    }

    internal var gamepads: [Int: GamepadState] = [:]

    private init() {}

    // MARK: - Public Methods

    /// Returns set of touches on screens.
    public static func getTouches() -> Set<TouchEvent> {
        lock.lock()
        defer { lock.unlock() }

        return self.shared.touches
    }

    public static func getInputEvents() -> Set<InputEvent> {
        lock.lock()
        defer { lock.unlock() }

        return Set(self.shared.eventsPool)
    }

    /// Returns `true` if you are pressing the Latin key in the current keyboard layout.
    public static func isKeyPressed(_ keyCode: KeyCode) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return self.shared.keyEvents.contains(keyCode)
    }

    /// Returns true if you are pressing the mouse button specified with MouseButton.
    public static func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let phase = self.shared.mouseEvents[button]?.phase else {
            return false
        }

        return phase == .began || phase == .changed
    }

    /// Returns `true` if you are released the mouse button.
    public static func isMouseButtonRelease(_ button: MouseButton) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return self.shared.mouseEvents[button]?.phase == .ended
    }

    /// Get mouse position on window.
    public static func getMousePosition() -> Vector2 {
        lock.lock()
        defer { lock.unlock() }

        return self.shared.mousePosition
    }

    /// Get mouse mode for active window.
    @MainActor
    public static func getMouseMode() -> MouseMode {
        Application.shared.windowManager.getMouseMode()
    }

    /// Set mouse mode for active window.
    @MainActor
    public static func setMouseMode(_ mode: MouseMode) {
        Application.shared.windowManager.setMouseMode(mode)
    }

    /// Set current cursor shape.
    @MainActor
    public static func setCursorShape(_ shape: CursorShape) {
        self.shared.cursorStates = [shape]
        Application.shared.windowManager.setCursorShape(shape)
    }

    var cursorStates: [CursorShape] = [.arrow]

    @MainActor
    public static func pushCursorShape(_ shape: CursorShape) {
        self.shared.cursorStates.append(shape)
        Application.shared.windowManager.setCursorShape(shape)
    }

    @MainActor
    public static func popCursorShape() {
        if self.shared.cursorStates.count > 2 {
            self.shared.cursorStates.removeLast()
        }

        let shape = self.shared.cursorStates.last!
        Application.shared.windowManager.setCursorShape(shape)
    }

    /// Set custom image for cursor.
    /// - Parameter shape: What cursor shape will update the texture.
    /// - Parameter texture: Texture for cursor, also available ``TextureAtlas``. If you pass nil, then we remove saved image.
    /// - Parameter hotSpot: The point to set as the cursor's hot spot.
    @MainActor
    public static func setCursorImage(for shape: Input.CursorShape, texture: Texture2D?, hotSpot: Vector2 = .zero) {
        Application.shared.windowManager.setCursorImage(for: shape, texture: texture, hotspot: hotSpot)
    }
    
    /// Get current cursor shape.
    @MainActor
    public static func getCurrentCursorShape() -> CursorShape {
        Application.shared.windowManager.getCursorShape()
    }
    
    // MARK: Internal
    
    @MainActor
    func removeEvents() {
        self.eventsPool.removeAll()
    }
    
    @MainActor
    func receiveEvent(_ event: InputEvent) {
        self.eventsPool.append(event)
        self.parseInputEvent(event)
    }

    // MARK: - Private

    private func parseInputEvent(_ event: InputEvent) {
        switch event {
        case let keyEvent as KeyEvent:
            if keyEvent.keyCode == .none && keyEvent.isRepeated {
                return
            }

            if keyEvent.status == .down {
                self.keyEvents.insert(keyEvent.keyCode)
            } else {
                self.keyEvents.remove(keyEvent.keyCode)
            }
        case let mouseEvent as MouseEvent:
            self.mouseEvents[mouseEvent.button] = mouseEvent
        case let touchEvent as TouchEvent:
            self.touches.insert(touchEvent)
        case let gamepadConnectionEvent as GamepadConnectionEvent:
            if gamepadConnectionEvent.isConnected {
                // GamepadInfo is now primarily set by the platform-specific manager after connection.
                // We initialize with a generic name and no type, expecting it to be updated.
                if self.gamepads[gamepadConnectionEvent.gamepadId] == nil {
                    self.gamepads[gamepadConnectionEvent.gamepadId] = GamepadState(
                        gamepadId: gamepadConnectionEvent.gamepadId,
                        info: GamepadInfo(name: "Connected Gamepad", type: nil)
                    )
                }
            } else {
                self.gamepads.removeValue(forKey: gamepadConnectionEvent.gamepadId)
            }
        case let gamepadButtonEvent as GamepadButtonEvent:
            guard var gamepadState = self.gamepads[gamepadButtonEvent.gamepadId] else {
                return
            }
            
            if gamepadButtonEvent.isPressed {
                gamepadState.buttonsPressed.insert(gamepadButtonEvent.button)
            } else {
                gamepadState.buttonsPressed.remove(gamepadButtonEvent.button)
            }
            self.gamepads[gamepadButtonEvent.gamepadId] = gamepadState
        case let gamepadAxisEvent as GamepadAxisEvent:
            guard var gamepadState = self.gamepads[gamepadAxisEvent.gamepadId] else {
                return
            }
            
            gamepadState.axisValues[gamepadAxisEvent.axis] = gamepadAxisEvent.value
            self.gamepads[gamepadAxisEvent.gamepadId] = gamepadState
        default:
            break
        }
    }
    
    // MARK: - Gamepad Public Methods
    
    /// Checks if a gamepad with the specified `gamepadId` is currently connected.
    ///
    /// Gamepad IDs are typically assigned by the system when a controller is connected.
    /// - Parameter gamepadId: The unique identifier of the gamepad.
    /// - Returns: `true` if the gamepad is connected, `false` otherwise.
    public static func isGamepadConnected(gamepadId: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return self.shared.gamepads[gamepadId] != nil
    }
    
    /// Retrieves an array of IDs for all currently connected gamepads.
    ///
    /// Gamepad IDs are typically assigned by the system.
    /// - Returns: An array of `Int` values representing the IDs of connected gamepads.
    public static func getConnectedGamepadIds() -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return Array(self.shared.gamepads.keys)
    }
    
    /// Checks if the specified button is currently pressed on the given gamepad.
    ///
    /// Gamepad IDs are typically assigned by the system.
    /// - Parameters:
    ///   - gamepadId: The unique identifier of the gamepad.
    ///   - button: The `GamepadButton` to check.
    /// - Returns: `true` if the button is pressed, `false` otherwise or if the gamepad is not connected.
    public static func isGamepadButtonPressed(_ gamepadId: Int, button: GamepadButton) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let gamepadState = self.shared.gamepads[gamepadId] else {
            return false
        }
        
        return gamepadState.buttonsPressed.contains(button)
    }
    
    /// Retrieves the current value of the specified axis on the given gamepad.
    ///
    /// Axis values are typically in the range of -1.0 to 1.0 for sticks, and 0.0 to 1.0 for triggers.
    /// Gamepad IDs are typically assigned by the system.
    /// - Parameters:
    ///   - gamepadId: The unique identifier of the gamepad.
    ///   - axis: The `GamepadAxis` to query.
    /// - Returns: The current value of the axis as a `Float`, or 0.0 if the gamepad is not connected or the axis is not found.
    public static func getGamepadAxisValue(_ gamepadId: Int, axis: GamepadAxis) -> Float {
        lock.lock()
        defer { lock.unlock() }
        
        guard let gamepadState = self.shared.gamepads[gamepadId] else {
            return 0.0
        }
        
        return gamepadState.axisValues[axis] ?? 0.0
    }
    
    /// Retrieves information about the specified gamepad, such as its name and type.
    ///
    /// Gamepad IDs are typically assigned by the system.
    /// - Parameter gamepadId: The unique identifier of the gamepad.
    /// - Returns: A `GamepadInfo` struct containing details about the gamepad, or `nil` if the gamepad is not connected.
    public static func getGamepadInfo(gamepadId: Int) -> GamepadInfo? {
        lock.lock()
        defer { lock.unlock() }
        
        return self.shared.gamepads[gamepadId]?.info
    }
    
    /// Triggers haptic feedback on the specified gamepad.
    ///
    /// This function will attempt to trigger rumble on the connected gamepad.
    /// The behavior and availability of haptics depend on the platform and the specific gamepad hardware.
    /// - Parameters:
    ///   - gamepadId: The identifier of the gamepad to rumble.
    ///   - lowFrequency: The intensity of the low-frequency motor (typically 0.0 to 1.0).
    ///   - highFrequency: The intensity of the high-frequency motor (typically 0.0 to 1.0).
    ///   - duration: The duration of the rumble effect in seconds.
    @MainActor
    public static func rumbleGamepad(gamepadId: Int, lowFrequency: Float, highFrequency: Float, duration: Float) {
        #if APPLE
        // On Apple platforms, AppleGameControllerManager needs to be imported or available in this scope.
        // Assuming AppleGameControllerManager is accessible via a shared instance or similar.
        // If AppleGameControllerManager is in a different module, ensure it's imported.
        // For now, we'll directly call it, assuming it's part of the same target or module with appropriate access.
        // This will require `import GameController` in this file or ensuring AppleGameControllerManager handles its own imports.
        // To avoid adding `import GameController` directly in `InputManager.swift` if it's not already there for other reasons,
        // it's better if the platform-specific call is more abstracted or handled within AppleGameControllerManager itself
        // without exposing GameController types here.
        // However, given the current structure, this is the most direct way.
        // We might need to ensure AppleGameControllerManager is public or the method is accessible.
        // Let's assume AppleGameControllerManager and its rumbleGamepad method are accessible.
        AppleGameControllerManager.shared.rumbleGamepad(gamepadId: gamepadId, lowFrequency: lowFrequency, highFrequency: highFrequency, duration: duration)
        #else
        // Placeholder for other platforms or if no platform supports it
        print("Gamepad rumble not supported on this platform or for this gamepad ID \(gamepadId).")
        #endif
    }
}

public extension Input {
    // GamepadInfo is now defined inside the Input class.
    // No need to redefine it here.

    /// Available list of mouse modes.
    enum MouseMode {
        
        /// Captures the mouse. The mouse will be hidden and its position locked at the center of the window manager's window.
        /// - WARNING: Not supported.
        case captured
        
        /// Makes the mouse cursor visible if it is hidden.
        case visible
        
        /// Makes the mouse cursor hidden if it is visible.
        case hidden
        
        /// Confines the mouse cursor to the game window, and make it hidden.
        /// - WARNING: Not supported.
        case confinedHidden
        
        /// Confines the mouse cursor to the game window, and make it visible.
        /// - WARNING: Not supported.
        case confined
    }
    
    /// Available list of cursor shapes.
    enum CursorShape {
        
        /// Standard cursor.
        case arrow
        
        /// Ussually used to show a link or other interactive item.
        case pointingHand
        
        /// Usually used to show where the text cursor will appear.
        case iBeam
        
        /// Usually used to show that application is busy and performing some operation. Also automatically shown when something blocking the main thread.
        case wait
        
        /// Typically appears over regions in which a drawing operation can be performed or for selections.
        case cross
        
        /// Busy cursor. Indicates that the application is busy performing an operation.
        case busy
        
        /// Drag cursor. Usually displayed when dragging something.
        case drag
        
        /// Can drop cursor. Usually displayed when dragging something to indicate that it can be dropped at the current position.
        case drop
        
        /// Used to indicate resizing to left.
        case resizeLeft
        
        /// Used to indicate resizing to right.
        case resizeRight
        
        /// Used to indicate horizontal resizing.
        case resizeLeftRight
        
        /// Used to indicate resizing to up.
        case resizeUp
        
        /// Used to indicate resizing to down.
        case resizeDown
        
        /// Used to indicate vertical resizing.
        case resizeUpDown
        
        /// Move cursor. Indicates that something can be moved.
        case move
        
        /// Forbidden cursor. Indicates that the current action is forbidden (for example, when dragging something) or that the control at a position is disabled.
        case forbidden
        
        /// Usually a question mark indicate some help.
        case help
    }
}
