//
//  AppleGameControllerManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

#if canImport(Darwin)
import AdaUtils
import CoreHaptics
import GameController

public final class AppleGameControllerManager: RumbleGameControllerEngine, @unchecked Sendable {

    private var knownGamepadIds: [GCController: Int] = [:]
    private var nextGamepadId: Int = 0
    private var receiveInputEvents: @Sendable (any InputEvent) -> Void

    public init(receiveInputEvents: @escaping @Sendable (any InputEvent) -> Void) {
        self.receiveInputEvents = receiveInputEvents
    }

    // MARK: - Button and Axis Mapping Helpers

    private func mapGCButtonToGamepadButton(_ input: GCControllerButtonInput, controller: GCController) -> GamepadButton? {
        guard let gamepad = controller.extendedGamepad else { return .unknown } // Or handle other profiles

        switch input {
        case gamepad.buttonA: return .a
        case gamepad.buttonB: return .b
        case gamepad.buttonX: return .x
        case gamepad.buttonY: return .y
        case gamepad.leftShoulder: return .leftShoulder
        case gamepad.rightShoulder: return .rightShoulder
        case gamepad.leftTrigger: return .leftTriggerButton // For digital press
        case gamepad.rightTrigger: return .rightTriggerButton // For digital press
        case gamepad.leftThumbstickButton: return .leftStickButton
        case gamepad.rightThumbstickButton: return .rightStickButton
        case gamepad.dpad.up: return .dPadUp
        case gamepad.dpad.down: return .dPadDown
        case gamepad.dpad.left: return .dPadLeft
        case gamepad.dpad.right: return .dPadRight
        case gamepad.buttonMenu: return .start // Or .select depending on convention
        case gamepad.buttonOptions: return .select // Or .start, often Xbox "View" or PS "Share/Create"
        // GCController doesn't directly map to a single "select" button in the way older gamepads did.
        // buttonOptions or buttonHome might be candidates depending on desired mapping.
        // For now, mapping buttonOptions to select.
        default:
            // MicroGamepad specific buttons if needed
            if let microGamepad = controller.microGamepad {
                switch input {
                case microGamepad.buttonA: return .a
                case microGamepad.buttonX: return .x
                case microGamepad.buttonMenu: return .start // Or select
                default: break
                }
            }
            return .unknown
        }
    }

    private func mapGCAxisToGamepadAxis(_ input: GCControllerAxisInput, controller: GCController) -> GamepadAxis? {
        guard let gamepad = controller.extendedGamepad else { return .unknown }

        switch input {
        case gamepad.leftThumbstick.xAxis: return .leftStickX
        case gamepad.leftThumbstick.yAxis: return .leftStickY
        case gamepad.rightThumbstick.xAxis: return .rightStickX
        case gamepad.rightThumbstick.yAxis: return .rightStickY
        default:
            return .unknown
        }
    }

    private func mapGCTriggerToGamepadAxis(_ input: GCControllerButtonInput, controller: GCController) -> GamepadAxis? {
        guard let gamepad = controller.extendedGamepad else { return nil }

        switch input {
        case gamepad.leftTrigger: return .leftTrigger
        case gamepad.rightTrigger: return .rightTrigger
        default:
            return nil
        }
    }
    
    public func startMonitoring() {
        // Process initially connected controllers
        for controller in GCController.controllers() {
            self.handleControllerConnected(controller: controller)
        }
        
        // Register for connection notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        // Register for disconnection notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }
    
    public func stopMonitoring() {
        NotificationCenter.default.removeObserver(
            self,
            name: .GCControllerDidConnect,
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }
    
    @objc private func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }
        // Ensure this runs on the main thread as it interacts with InputManager
        self.handleControllerConnected(controller: controller)
    }
    
    private func handleControllerConnected(controller: GCController) {
        guard self.knownGamepadIds[controller] == nil else {
            return
        }
        
        let gamepadId = self.nextGamepadId
        self.nextGamepadId += 1
        
        self.knownGamepadIds[controller] = gamepadId
        
        // Placeholder for input element setup
        // Will set up input element handlers for buttons and axes here.
        self.setupInputElementHandlers(for: controller, gamepadId: gamepadId)
        
        // Extract controller info and update GamepadState
        let gamepadName = controller.vendorName ?? "Connected Gamepad"
        let controllerType = controller.productCategory
        let info = GamepadInfo(name: gamepadName, type: controllerType)

        let event = GamepadConnectionEvent(
            gamepadId: gamepadId,
            isConnected: true,
            gamepadInfo: info,
            window: .empty,
            time: TimeInterval(Date().timeIntervalSince1970)
        )

        Task { @MainActor [receiveInputEvents] in
            receiveInputEvents(event)
        }
    }

    private func setupInputElementHandlers(for controller: GCController, gamepadId: Int) {
        guard let gamepad = controller.extendedGamepad else {
            // TODO: Add support for other controller types like microGamepad if necessary
            print("Connected controller is not an ExtendedGamepad, input handling not fully set up.")
            if let microGamepad = controller.microGamepad { // Basic support for microGamepad
                 microGamepad.buttonA.pressedChangedHandler = { [weak self] button, pressure, pressed in
                    self?.handleButtonChange(button: button, controller: controller, gamepadId: gamepadId, pressure: pressure, pressed: pressed)
                }
                microGamepad.buttonX.pressedChangedHandler = { [weak self] button, pressure, pressed in
                    self?.handleButtonChange(button: button, controller: controller, gamepadId: gamepadId, pressure: pressure, pressed: pressed)
                }
                microGamepad.buttonMenu.pressedChangedHandler = { [weak self] button, pressure, pressed in
                    self?.handleButtonChange(button: button, controller: controller, gamepadId: gamepadId, pressure: pressure, pressed: pressed)
                }
                microGamepad.dpad.xAxis.valueChangedHandler = { [weak self, receiveInputEvents] axis, value in
                     // Dpad X on microGamepad could be mapped to left/right buttons or an axis
                     // For simplicity, sending as axis event first, then potentially button events.
                    if let mappedAxis = self?.mapGCAxisToGamepadAxis(axis, controller: controller) {
                        let event = GamepadAxisEvent(
                            gamepadId: gamepadId,
                            axis: mappedAxis,
                            value: value,
                            window: .empty,
                            time: TimeInterval(Date().timeIntervalSince1970)
                        )
                        Task { @MainActor in
                            receiveInputEvents(event)
                        }
                    }
                    // Optionally, also simulate dpad left/right button presses based on value
                    // This part can be complex due to thresholds and state management.
                }
                 microGamepad.dpad.yAxis.valueChangedHandler = { [weak self, receiveInputEvents] axis, value in
                    // Similar for Dpad Y
                    if let mappedAxis = self?.mapGCAxisToGamepadAxis(axis, controller: controller) {
                        let event = GamepadAxisEvent(
                            gamepadId: gamepadId,
                            axis: mappedAxis,
                            value: value,
                            window: .empty,
                            time: TimeInterval(Date().timeIntervalSince1970)
                        )

                        Task { @MainActor in
                            receiveInputEvents(event)
                        }
                    }
                }
            }
            return
        }

        // Buttons
        let allButtons: [GCControllerButtonInput] = [
            gamepad.buttonA, gamepad.buttonB, gamepad.buttonX, gamepad.buttonY,
            gamepad.leftShoulder, gamepad.rightShoulder,
            gamepad.leftTrigger, gamepad.rightTrigger, // These are also axes, handled below for axis value
            gamepad.leftThumbstickButton, gamepad.rightThumbstickButton,
            gamepad.buttonMenu, gamepad.buttonOptions, // Or buttonHome
            gamepad.dpad.up, gamepad.dpad.down, gamepad.dpad.left, gamepad.dpad.right
        ].compactMap { $0 } // Filter out nil buttons (e.g. thumbstick buttons if not present)

        for button in allButtons {
            button.pressedChangedHandler = { [weak self] button, pressure, pressed in
                self?.handleButtonChange(
                    button: button,
                    controller: controller,
                    gamepadId: gamepadId,
                    pressure: pressure,
                    pressed: pressed
                )
            }
            // For triggers, also set valueChangedHandler to capture axis value
            if button == gamepad.leftTrigger || button == gamepad.rightTrigger {
                button.valueChangedHandler = { [weak self] triggerButton, pressure, pressed in // `pressure` here is the axis value
                    self?.handleTriggerAxisChange(
                        button: triggerButton,
                        controller: controller,
                        gamepadId: gamepadId,
                        value: pressure
                    )
                }
            }
        }

        // Axes (Analog Sticks)
        let allAxes: [GCControllerAxisInput] = [
            gamepad.leftThumbstick.xAxis, gamepad.leftThumbstick.yAxis,
            gamepad.rightThumbstick.xAxis, gamepad.rightThumbstick.yAxis
        ]

        for axis in allAxes {
            axis.valueChangedHandler = { [weak self] axis, value in
                self?.handleAxisChange(
                    axis: axis,
                    controller: controller,
                    gamepadId: gamepadId,
                    value: value
                )
            }
        }
    }

    private func handleButtonChange(
        button: GCControllerButtonInput,
        controller: GCController,
        gamepadId: Int,
        pressure: Float,
        pressed: Bool
    ) {
        guard let mappedButton = self.mapGCButtonToGamepadButton(button, controller: controller) else {
            print("Unknown button pressed on gamepad \(gamepadId)")
            return
        }

        if mappedButton == .unknown {
            print("Unknown button pressed (mapped to .unknown) on gamepad \(gamepadId)")
            return
        }

        let event = GamepadButtonEvent(
            gamepadId: gamepadId,
            button: mappedButton,
            isPressed: pressed,
            pressure: button.isAnalog ? pressure : (pressed ? 1.0 : 0.0), // Use pressure if analog, else 0/1
            window: .empty,
            time: TimeInterval(Date().timeIntervalSince1970)
        )

        Task { @MainActor [receiveInputEvents] in
            receiveInputEvents(event)
        }
    }

    private func handleAxisChange(axis: GCControllerAxisInput, controller: GCController, gamepadId: Int, value: Float) {
        guard let mappedAxis = self.mapGCAxisToGamepadAxis(axis, controller: controller) else {
            print("Unknown axis changed on gamepad \(gamepadId)")
            return
        }

        if mappedAxis == .unknown {
            print("Unknown axis changed (mapped to .unknown) on gamepad \(gamepadId)")
            return
        }

        let event = GamepadAxisEvent(
            gamepadId: gamepadId,
            axis: mappedAxis,
            value: value,
            window: .empty,
            time: TimeInterval(Date().timeIntervalSince1970)
        )

        Task { @MainActor [receiveInputEvents] in
            receiveInputEvents(event)
        }
    }

    private func handleTriggerAxisChange(button: GCControllerButtonInput, controller: GCController, gamepadId: Int, value: Float) {
        guard let mappedAxis = self.mapGCTriggerToGamepadAxis(button, controller: controller) else {
            // This trigger is not mapped as an axis (or shouldn't be)
            return
        }

        let event = GamepadAxisEvent(
            gamepadId: gamepadId,
            axis: mappedAxis,
            value: value, // Value from valueChangedHandler IS the axis value
            window: .empty,
            time: TimeInterval(Date().timeIntervalSince1970)
        )

        Task { @MainActor [receiveInputEvents] in
            receiveInputEvents(event)
        }
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }
        
        // Ensure this runs on the main thread
        guard let gamepadId = self.knownGamepadIds[controller] else {
            // Unknown controller
            return
        }

        let event = GamepadConnectionEvent(
            gamepadId: gamepadId,
            isConnected: false,
            gamepadInfo: nil,
            window: .empty,
            time: TimeInterval(Date().timeIntervalSince1970)
        )
        Task { @MainActor [receiveInputEvents] in
            receiveInputEvents(event)
        }

        self.knownGamepadIds.removeValue(forKey: controller)
        print("Gamepad disconnected: ID \(gamepadId)")
    }

    // MARK: - Haptics

    public func rumbleGamepad(
        gamepadId: Int,
        lowFrequency: Float,
        highFrequency: Float,
        duration: Float
    ) {
        guard let controller = knownGamepadIds.first(where: { $0.value == gamepadId })?.key else {
            print("Cannot rumble: Gamepad with ID \(gamepadId) not found.")
            return
        }

        guard let haptics = controller.haptics else {
            print("Cannot rumble: Gamepad \(gamepadId) does not support haptics.")
            return
        }

//        haptics.createEngine(withLocality: GCHapticsLocality.default)
//
//        // Find a suitable engine. Prefer one that supports CHHapticEvent.ParameterID.hapticIntensity and .hapticSharpness
//        // For simplicity, let's try to find the first available engine that supports general event parameters.
//        guard let engine = haptics.engines.first(where: { $0.supportsEventParameters }) else {
//             // Fallback: try any engine if the preferred one is not found
//            guard let anyEngine = haptics.engines.first else {
//                print("Cannot rumble: No haptic engines found for gamepad \(gamepadId).")
//                return
//            }
//            // This engine might not support complex events, but try a simple transient event.
//            let simpleHapticEvent = CHHapticEvent(eventType: .hapticTransient, parameters: [
//                CHHapticEventParameter(parameterID: .hapticIntensity, value: (lowFrequency + highFrequency) / 2), // Average intensity
//            ], relativeTime: 0, duration: Foundation.TimeInterval(duration))
//
//            do {
//                try anyEngine.sendEvents([CHHapticEventRequest(event: simpleHapticEvent, parameters: [], relativeTime: 0, duration: duration)])
//                print("Sent simple haptic event to gamepad \(gamepadId)")
//            } catch {
//                print("Error sending simple haptic event to gamepad \(gamepadId): \(error)")
//            }
//            return
//        }
//
//
//        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: highFrequency) // Use highFrequency for main intensity
//        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: lowFrequency)  // Use lowFrequency for sharpness/feel
//
//        let continuousEvent = CHHapticEvent(
//            eventType: .hapticContinuous,
//            parameters: [intensityParam, sharpnessParam],
//            relativeTime: 0,
//            duration: Foundation.TimeInterval(duration)
//        )
//        
//        let eventRequest = CHHapticEventRequest(event: continuousEvent, parameters: [intensityParam, sharpnessParam], relativeTime: 0, duration: duration)
//
//        do {
//            try engine.sendEvents([eventRequest])
//            print("Sent haptic event to gamepad \(gamepadId): Intensity \(highFrequency), Sharpness \(lowFrequency), Duration \(duration)")
//        } catch {
//            print("Error sending haptic event to gamepad \(gamepadId): \(error)")
//        }
    }
}

#endif
