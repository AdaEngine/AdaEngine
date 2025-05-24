//
//  GamepadConnectionEvent.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

/// An event that represents a gamepad connection or disconnection.
///
/// This event is dispatched when a gamepad is connected to or disconnected from the system.
public class GamepadConnectionEvent: InputEvent {
    
    /// The unique identifier of the gamepad that triggered the event.
    /// Gamepad IDs are typically assigned by the system.
    public let gamepadId: Int
    
    /// A Boolean value indicating whether the gamepad was connected (`true`) or disconnected (`false`).
    public let isConnected: Bool
    
    public init(gamepadId: Int, isConnected: Bool, window: UIWindow.ID, time: TimeInterval) {
        self.gamepadId = gamepadId
        self.isConnected = isConnected
        super.init(window: window, time: time)
    }
    
    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(gamepadId)
        hasher.combine(isConnected)
    }
    
    public static func == (lhs: GamepadConnectionEvent, rhs: GamepadConnectionEvent) -> Bool {
        return lhs.gamepadId == rhs.gamepadId && lhs.isConnected == rhs.isConnected && lhs as InputEvent == rhs as InputEvent
    }
}
