//
//  GamepadAxisEvent.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

/// An event that represents a change in a gamepad's analog axis value.
///
/// This event is dispatched when an analog stick or trigger on a connected gamepad moves.
public final class GamepadAxisEvent: InputEvent, @unchecked Sendable {

    /// The unique identifier of the gamepad that triggered the event.
    /// Gamepad IDs are typically assigned by the system.
    public let gamepadId: Int
    
    /// The specific `GamepadAxis` that changed its value.
    public let axis: GamepadAxis
    
    /// The new value of the axis, typically ranging from -1.0 to 1.0 for sticks,
    /// and 0.0 to 1.0 for triggers.
    public let value: Float
    
    public init(gamepadId: Int, axis: GamepadAxis, value: Float, window: UIWindow.ID, time: TimeInterval) {
        self.gamepadId = gamepadId
        self.axis = axis
        self.value = value
        super.init(window: window, time: time)
    }
    
    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(gamepadId)
        hasher.combine(axis)
        hasher.combine(value)
    }
    
    public static func == (lhs: GamepadAxisEvent, rhs: GamepadAxisEvent) -> Bool {
        return lhs.gamepadId == rhs.gamepadId && lhs.axis == rhs.axis && lhs.value == rhs.value && lhs as InputEvent == rhs as InputEvent
    }
}
