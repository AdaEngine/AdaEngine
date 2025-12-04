//
//  InputManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/2/21.
//

import AdaECS
import AdaUtils
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Math

// - TODO: (Vlad) Add actions list and method like `isActionPressed`

/// An object that contains inputs from keyboards, mouse, touch screens and etc.
public struct Input: Resource, Sendable {

    @_spi(Internal)
    public var mousePosition: Point = .zero
    private let lock = NSRecursiveLock()

    @_spi(Internal)
    public private(set) var eventsPool: [any InputEvent] = []
    // FIXME: (Vlad) Should think about capacity. We should store ~256 keycode events
    @_spi(Internal)
    public private(set) var keyEvents: Set<KeyCode> = []
    @_spi(Internal)
    public private(set) var mouseEvents: [MouseButton: MouseEvent] = [:]
    @_spi(Internal)
    public private(set) var touches: Set<TouchEvent> = []
    private(set) var gamepads: [Int: Gamepad] = [:]
    var cursorStates: [CursorShape] = [.arrow]

    public var rumbleGameControllerEngine: RumbleGameControllerEngine?

    init() {}

    // MARK: - Public Methods

    /// Returns set of touches on screens.
    public func getTouches() -> Set<TouchEvent> {
        return self.touches
    }

    /// Returns a set of input events.
    public func getInputEvents() -> Array<any InputEvent> {
        return self.eventsPool
    }

    /// Returns `true` if you are pressing the Latin key in the current keyboard layout.
    public func isKeyPressed(_ keyCode: KeyCode) -> Bool {
        return self.keyEvents.contains(keyCode)
    }

    /// Returns true if you are pressing the mouse button specified with MouseButton.
    public func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let phase = self.mouseEvents[button]?.phase else {
            return false
        }

        return phase == .began || phase == .changed
    }

    /// Returns `true` if you are released the mouse button.
    public func isMouseButtonRelease(_ button: MouseButton) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return self.mouseEvents[button]?.phase == .ended
    }

    /// Get mouse position on window.
    public func getMousePosition() -> Vector2 {
        lock.lock()
        defer { lock.unlock() }

        return self.mousePosition
    }

    /// Get mouse mode for active window.
    @MainActor
    public func getMouseMode() -> MouseMode {
//        Application.shared.windowManager.getMouseMode()
        return .visible
    }

    /// Set mouse mode for active window.
    @MainActor
    public mutating func setMouseMode(_ mode: MouseMode) {
//        Application.shared.windowManager.setMouseMode(mode)
    }

    /// Set current cursor shape.
    @MainActor
    public mutating func setCursorShape(_ shape: CursorShape) {
        self.cursorStates = [shape]
//        Application.shared.windowManager.setCursorShape(shape)
    }

    /// Pushes a new cursor shape onto the stack and sets it as the current cursor shape.
    @MainActor
    public mutating func pushCursorShape(_ shape: CursorShape) {
        self.cursorStates.append(shape)
//        Application.shared.windowManager.setCursorShape(shape)
    }

    /// Pops the last cursor shape from the stack and sets it as the current cursor shape.
    @MainActor
    public mutating func popCursorShape() {
        if self.cursorStates.count > 2 {
            self.cursorStates.removeLast()
        }

        let shape = self.cursorStates.last!
//        Application.shared.windowManager.setCursorShape(shape)
    }

    /// Set custom image for cursor.
    /// - Parameter shape: What cursor shape will update the texture.
    /// - Parameter texture: Texture for cursor, also available ``TextureAtlas``. If you pass nil, then we remove saved image.
    /// - Parameter hotSpot: The point to set as the cursor's hot spot.
//    @MainActor
//    public static func setCursorImage(for shape: Input.CursorShape, texture: Texture2D?, hotSpot: Vector2 = .zero) {
//        Application.shared.windowManager.setCursorImage(for: shape, texture: texture, hotspot: hotSpot)
//    }

    /// Get current cursor shape.
//    @MainActor
//    public static func getCurrentCursorShape() -> CursorShape {
//        Application.shared.windowManager.getCursorShape()
//    }

    // MARK: Internal

    @MainActor
    @_spi(Internal) public mutating func removeEvents() {
        self.eventsPool.removeAll()
    }

    @MainActor
    @_spi(Internal) public mutating func receiveEvent<T: InputEvent>(_ event: T) {
        self.eventsPool.append(event)
        self.parseInputEvent(event)
    }

    // MARK: - Private

    @MainActor
    private mutating func parseInputEvent<T: InputEvent>(_ event: T) {
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
                let controllerType = gamepadConnectionEvent.gamepadInfo?.type ?? "Unknown"
                let controllerName = gamepadConnectionEvent.gamepadInfo?.name ?? "Unknown"

                self.gamepads[gamepadConnectionEvent.gamepadId] = Gamepad(
                    gamepadId: gamepadConnectionEvent.gamepadId,
                    info: gamepadConnectionEvent.gamepadInfo,
                    rumbleGameControllerEngine: self.rumbleGameControllerEngine
                )

                print("Gamepad connected: ID \(gamepadConnectionEvent.gamepadId), Name: \(controllerName), Type: \(controllerType)")
            } else {
                self.gamepads.removeValue(forKey: gamepadConnectionEvent.gamepadId)
                print("Gamepad disconnected: ID \(gamepadConnectionEvent.gamepadId)")
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

    /// Retrieves an array of IDs for all currently connected gamepads.
    ///
    /// Gamepad IDs are typically assigned by the system.
    /// - Returns: An array of ``Input.Gamepad`` values representing the IDs of connected gamepads.
    public func getConnectedGamepads() -> [Gamepad] {
        return Array(self.gamepads.values)
    }

    /// Retrieves a gamepad by its ID.
    ///
    /// Gamepad IDs are typically assigned by the system.
    /// - Parameter gamepadId: The unique identifier of the gamepad.
    /// - Returns: A ``Gamepad`` value representing the gamepad, or `nil` if the gamepad is not connected.
    public func getConnectedGamepad(for gamepadId: Gamepad.ID) -> Gamepad? {
        return self.gamepads[gamepadId]
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
    enum CursorShape: Sendable {

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

extension Input {
    /// For test
    mutating func _removeAllStates() {
        self.gamepads.removeAll()
        self.cursorStates.removeAll()
        self.eventsPool.removeAll()
        self.keyEvents.removeAll()
        self.touches.removeAll()
        self.mouseEvents.removeAll()
        self.mousePosition = .zero
    }
}

/// Contains information about a connected gamepad.
public struct GamepadInfo: Hashable, Sendable {
    /// The name of the gamepad, often provided by the system or manufacturer.
    public let name: String
    /// An optional string describing the type or category of the gamepad (e.g., "Xbox Controller", "DualShock 4").
    public let type: String?

    internal init(name: String, type: String? = nil) {
        self.name = name
        self.type = type
    }
}

/// Represents a connected gamepad.
public struct Gamepad: Sendable {

    /// The type alias for the gamepad ID.
    public typealias ID = Int

    /// The unique identifier of the gamepad.
    public let gamepadId: ID

    /// The buttons currently pressed on the gamepad.
    var buttonsPressed: Set<GamepadButton> = []

    /// The current values of the gamepad's axes.
    var axisValues: [GamepadAxis: Float] = [:]

    /// Retrieves information about the specified gamepad, such as its name and type.
    ///
    /// Gamepad IDs are typically assigned by the system.
    /// - Parameter gamepadId: The unique identifier of the gamepad.
    /// - Returns: A `GamepadInfo` struct containing details about the gamepad, or `nil` if the gamepad is not connected.
    public internal(set) var info: GamepadInfo? // TODO: Populate this later

    private var rumbleGameControllerEngine: RumbleGameControllerEngine?

    init(
        gamepadId: ID,
        info: GamepadInfo? = nil,
        rumbleGameControllerEngine: RumbleGameControllerEngine?
    ) {
        self.gamepadId = gamepadId
        self.info = info
        // Initialize all axes to 0.0
        for axis in [GamepadAxis.leftStickX, .leftStickY, .rightStickX, .rightStickY, .leftTrigger, .rightTrigger] {
            axisValues[axis] = 0.0
        }
    }

    /// Checks if the specified button is currently pressed on the given gamepad.
    ///
    /// Gamepad IDs are typically assigned by the system.
    /// - Parameters:
    ///   - button: The `GamepadButton` to check.
    /// - Returns: `true` if the button is pressed, `false` otherwise or if the gamepad is not connected.
    public func isGamepadButtonPressed(_ button: GamepadButton) -> Bool {
        return self.buttonsPressed.contains(button)
    }

    /// Retrieves the current value of the specified axis on the given gamepad.
    ///
    /// Axis values are typically in the range of -1.0 to 1.0 for sticks, and 0.0 to 1.0 for triggers.
    /// Gamepad IDs are typically assigned by the system.
    /// - Parameters:
    ///   - axis: The `GamepadAxis` to query.
    /// - Returns: The current value of the axis as a `Float`, or 0.0 if the gamepad is not connected or the axis is not found.
    public func getAxisValue(_ axis: GamepadAxis) -> Float {
        return self.axisValues[axis] ?? 0.0
    }

    /// Triggers haptic feedback on the specified gamepad.
    ///
    /// This function will attempt to trigger rumble on the connected gamepad.
    /// The behavior and availability of haptics depend on the platform and the specific gamepad hardware.
    /// - Parameters:
    ///   - lowFrequency: The intensity of the low-frequency motor (typically 0.0 to 1.0).
    ///   - highFrequency: The intensity of the high-frequency motor (typically 0.0 to 1.0).
    ///   - duration: The duration of the rumble effect in seconds.
    public func rumble(
        lowFrequency: Float,
        highFrequency: Float,
        duration: Float
    ) {
        rumbleGameControllerEngine?.rumbleGamepad(
            gamepadId: gamepadId,
            lowFrequency: lowFrequency,
            highFrequency: highFrequency,
            duration: duration
        )
    }
}

public protocol RumbleGameControllerEngine: AnyObject, Sendable {
    func rumbleGamepad(
        gamepadId: Int,
        lowFrequency: Float,
        highFrequency: Float,
        duration: Float
    )
}
