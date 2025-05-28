//
//  GamepadButtonEvent.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

/// An event that represents a gamepad button press or release.
///
/// This event is dispatched when a button on a connected gamepad changes its state.
public final class GamepadButtonEvent: InputEvent, @unchecked Sendable {
    
    /// The unique identifier of the gamepad that triggered the event.
    /// Gamepad IDs are typically assigned by the system.
    public let gamepadId: Int
    
    /// The specific `GamepadButton` that was pressed or released.
    public let button: GamepadButton
    
    /// A Boolean value indicating whether the button was pressed (`true`) or released (`false`).
    public let isPressed: Bool
    
    /// An optional `Float` value representing the pressure applied to an analog button (e.g., triggers).
    ///
    /// This value is typically between 0.0 (not pressed) and 1.0 (fully pressed).
    /// For digital buttons, this might be `nil`, or always 0.0 or 1.0.
    public let pressure: Float?
    
    public init(gamepadId: Int, button: GamepadButton, isPressed: Bool, pressure: Float?, window: UIWindow.ID, time: TimeInterval) {
        self.gamepadId = gamepadId
        self.button = button
        self.isPressed = isPressed
        self.pressure = pressure
        super.init(window: window, time: time)
    }
    
    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(gamepadId)
        hasher.combine(button)
        hasher.combine(isPressed)
        hasher.combine(pressure)
    }
    
    public static func == (lhs: GamepadButtonEvent, rhs: GamepadButtonEvent) -> Bool {
        return lhs.gamepadId == rhs.gamepadId && lhs.button == rhs.button && lhs.isPressed == rhs.isPressed && lhs.pressure == rhs.pressure && lhs as InputEvent == rhs as InputEvent
    }
}
