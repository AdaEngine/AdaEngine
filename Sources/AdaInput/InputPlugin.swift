//
//  InputPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaECS
import AdaApp
import Logging

public struct InputPlugin: Plugin {

    @Local private var controllerEngine: GameControllerEngine?

    public init() { }

    public func setup(in app: AppWorlds) {
        #if canImport(Darwin)
        let appleGameControllerManager = AppleGameControllerManager()
        controllerEngine = appleGameControllerManager
        #else
        controllerEngine = nil
        #endif

        app
            .insertResource(Input(gameControllerEngine: controllerEngine))
            .addSystem(InputStartupSystem.self, on: .startup)
            .addSystem(InputEventParseSystem.self, on: .preUpdate)
    }

    public func finish(for app: borrowing AppWorlds) {
        controllerEngine?.stopMonitoring()
    }
}

@PlainSystem
struct InputEventParseSystem {

    @ResMut<Input>
    private var input

    private let logger = Logger(label: "org.adaengine.AdaInput")

    init(world: World) {}

    @MainActor
    func update(context: UpdateContext) async {
        for event in input.eventsPool {
            switch event {
            case let keyEvent as KeyEvent:
                if keyEvent.keyCode == .none && keyEvent.isRepeated {
                    return
                }

                if keyEvent.status == .down {
                    input.keyEvents.insert(keyEvent.keyCode)
                } else {
                    input.keyEvents.remove(keyEvent.keyCode)
                }
            case let mouseEvent as MouseEvent:
                input.mouseEvents[mouseEvent.button] = mouseEvent
            case let touchEvent as TouchEvent:
                input.touches.insert(touchEvent)
            case let gamepadConnectionEvent as GamepadConnectionEvent:
                print("Parse event", gamepadConnectionEvent.id)
                if gamepadConnectionEvent.isConnected {
                    let controllerType = gamepadConnectionEvent.gamepadInfo?.type ?? "Unknown"
                    let controllerName = gamepadConnectionEvent.gamepadInfo?.name ?? "Unknown"

                    input.gamepads[gamepadConnectionEvent.gamepadId] = Gamepad(
                        gamepadId: gamepadConnectionEvent.gamepadId,
                        info: gamepadConnectionEvent.gamepadInfo,
                        gameControllerEngine: input.gameControllerEngine
                    )

                    logger.info("Gamepad connected: ID \(gamepadConnectionEvent.gamepadId), Name: \(controllerName), Type: \(controllerType)")
                } else {
                    input.gamepads.removeValue(forKey: gamepadConnectionEvent.gamepadId)
                    logger.info("Gamepad disconnected: ID \(gamepadConnectionEvent.gamepadId)")
                }
            case let gamepadButtonEvent as GamepadButtonEvent:
                guard var gamepadState = input.gamepads[gamepadButtonEvent.gamepadId] else {
                    return
                }

                if gamepadButtonEvent.isPressed {
                    gamepadState.buttonsPressed.insert(gamepadButtonEvent.button)
                } else {
                    gamepadState.buttonsPressed.remove(gamepadButtonEvent.button)
                }
                input.gamepads[gamepadButtonEvent.gamepadId] = gamepadState
            case let gamepadAxisEvent as GamepadAxisEvent:
                guard var gamepadState = input.gamepads[gamepadAxisEvent.gamepadId] else {
                    return
                }

                gamepadState.axisValues[gamepadAxisEvent.axis] = gamepadAxisEvent.value
                input.gamepads[gamepadAxisEvent.gamepadId] = gamepadState
            default:
                break
            }
        }
        input.removeEvents()
    }
}

@System
@inline(__always)
func InputStartup(
    _ input: ResMut<Input>
) async {
    input.wrappedValue.gameControllerEngine?.startMonitoring()

    guard let stream = input.wrappedValue.gameControllerEngine?.makeEventStream() else {
        return
    }
    Task { @MainActor in
        for await event in stream {
            input.wrappedValue.receiveEvent(event)
        }
    }
}
