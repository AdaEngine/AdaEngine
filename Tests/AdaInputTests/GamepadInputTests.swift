//
//  GamepadInputTests.swift
//  AdaEngineTests
//
//  Created by v.prusakov on 7/12/22.
//

import Testing
@testable import AdaUI
import AdaECS
@_spi(Internal) @testable import AdaInput
import AdaUtils
import Foundation
import Math

@Suite("Gamepad Input Tests")
struct GamepadInputTests: Sendable {

    let world: World
    var input: Input {
        get {
            world.getResource(Input.self)!
        }
        set {
            world.getRefResource(Input.self).wrappedValue = newValue
        }
    }

    init() async {
        self.world = World()
        self.world.addSystem(InputStartupSystem.self, on: .startup)
        self.world.addSystem(InputEventParseSystem.self)

        let input = Input(gameControllerEngine: nil)
        self.world.insertResource(input)

        await self.world.runScheduler(.startup)
    }

    @Test("Gamepad Connection and Disconnection")
    mutating func testGamepadConnectionAndDisconnection() async {
        #expect(self.input.getConnectedGamepads().count == 0, "Gamepads should be empty.")

        let gamepadId = 0
        let windowId = UIWindow.ID.empty
        var time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)

        // Connect gamepad
        let connectEvent = GamepadConnectionEvent(
            gamepadId: gamepadId,
            isConnected: true,
            gamepadInfo: nil,
            window: windowId,
            time: time
        )

        await input.receiveEvent(connectEvent)
        await world.runScheduler(.update)

        #expect(input.getConnectedGamepads().count == 1, "Gamepad \(gamepadId) should be connected.")
        #expect(input.getConnectedGamepads().contains { $0.gamepadId == gamepadId }, "Connected gamepads list should contain \(gamepadId).")

        // Disconnect gamepad
        time = TimeInterval(Date().timeIntervalSince1970) // Update time for new event
        let disconnectEvent = GamepadConnectionEvent(
            gamepadId: gamepadId,
            isConnected: false,
            gamepadInfo: nil,
            window: windowId,
            time: time
        )
        await self.input.receiveEvent(disconnectEvent)
        await world.runScheduler(.update)

        #expect(input.getConnectedGamepads().count == 0, "Gamepad \(gamepadId) should be disconnected.")
    }

    @Test("Gamepad Button Press and Release")
    mutating func testGamepadButtonPressAndRelease() async throws {
        #expect(self.input.getConnectedGamepads().count == 0, "Gamepads should be empty.")

        let gamepadId = 1
        let windowId = UIWindow.ID.empty
        var time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)

        // Connect gamepad
        let connectEvent = GamepadConnectionEvent(
            gamepadId: gamepadId,
            isConnected: true,
            gamepadInfo: nil,
            window: windowId,
            time: time
        )

        await self.input.receiveEvent(connectEvent)
        await world.runScheduler(.update)
        #expect(self.input.getConnectedGamepads().count == 1)

        // Press button A
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let buttonAPressEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .a, isPressed: true, pressure: 1.0, window: windowId, time: time)
        await self.input.receiveEvent(buttonAPressEvent)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepads().first?.isGamepadButtonPressed(.a) == true, "Button A should be pressed.")

        // Release button A
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let buttonAReleaseEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .a, isPressed: false, pressure: 0.0, window: windowId, time: time)
        await self.input.receiveEvent(buttonAReleaseEvent)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepads().first?.isGamepadButtonPressed(.a) == false, "Button A should be released.")

        // Press Left Shoulder
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let leftShoulderPressEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .leftShoulder, isPressed: true, pressure: 1.0, window: windowId, time: time)
        await self.input.receiveEvent(leftShoulderPressEvent)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepads().first?.isGamepadButtonPressed(.leftShoulder) == true, "Left Shoulder should be pressed.")

        // Release Left Shoulder
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let leftShoulderReleaseEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .leftShoulder, isPressed: false, pressure: 0.0, window: windowId, time: time)
        await self.input.receiveEvent(leftShoulderReleaseEvent)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepads().first?.isGamepadButtonPressed(.leftShoulder) == false, "Left Shoulder should be released.")
    }

    @Test("Gamepad Axis Value")
    mutating func testGamepadAxisValue() async {
        let gamepadId = 2
        let windowId = UIWindow.ID.empty
        var time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)

        // Connect gamepad
        let connectEvent = GamepadConnectionEvent(gamepadId: gamepadId, isConnected: true, gamepadInfo: nil, window: windowId, time: time)
        await self.input.receiveEvent(connectEvent)

        // Move Left Stick X
        var axisValue: Float = 0.75
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let leftStickXEvent = GamepadAxisEvent(gamepadId: gamepadId, axis: .leftStickX, value: axisValue, window: windowId, time: time)
        await self.input.receiveEvent(leftStickXEvent)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepad(for: gamepadId)?.getAxisValue(.leftStickX) == axisValue, "Left Stick X value should be \(axisValue).")

        // Move Left Stick X again
        axisValue = -0.5
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let leftStickXEvent2 = GamepadAxisEvent(gamepadId: gamepadId, axis: .leftStickX, value: axisValue, window: windowId, time: time)
        await self.input.receiveEvent(leftStickXEvent2)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepad(for: gamepadId)?.getAxisValue(.leftStickX) == axisValue, "Left Stick X value should be \(axisValue).")

        // Move Right Trigger
        axisValue = 0.9
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let rightTriggerEvent = GamepadAxisEvent(gamepadId: gamepadId, axis: .rightTrigger, value: axisValue, window: windowId, time: time)
        await self.input.receiveEvent(rightTriggerEvent)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepad(for: gamepadId)?.getAxisValue(.rightTrigger) == axisValue, "Right Trigger value should be \(axisValue).")
    }

    @Test("Multiple Gamepads")
    mutating func testMultipleGamepads() async {
        let gamepadId0 = 0
        let gamepadId1 = 1
        let windowId = UIWindow.ID.empty
        var time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)

        // Connect gamepad 0
        let connectEvent0 = GamepadConnectionEvent(gamepadId: gamepadId0, isConnected: true, gamepadInfo: nil, window: windowId, time: time)
        await self.input.receiveEvent(connectEvent0)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepad(for: gamepadId0) != nil, "Gamepad \(gamepadId0) should be connected.")

        // Connect gamepad 1
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let connectEvent1 = GamepadConnectionEvent(gamepadId: gamepadId1, isConnected: true, gamepadInfo: nil, window: windowId, time: time)
        await self.input.receiveEvent(connectEvent1)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepad(for: gamepadId1) != nil, "Gamepad \(gamepadId1) should be connected.")

        // Press button B on gamepad 0
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let buttonBPress0 = GamepadButtonEvent(gamepadId: gamepadId0, button: .b, isPressed: true, pressure: 1.0, window: windowId, time: time)
        await self.input.receiveEvent(buttonBPress0)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepad(for: gamepadId0)?.isGamepadButtonPressed(.b) == true, "Gamepad 0 Button B should be pressed.")
        #expect(self.input.getConnectedGamepad(for: gamepadId1)?.isGamepadButtonPressed(.b) == false, "Gamepad 1 Button B should NOT be pressed.")

        // Move axis Left Stick Y on gamepad 1
        let axisValue1: Float = 0.65
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let leftStickYEvent1 = GamepadAxisEvent(gamepadId: gamepadId1, axis: .leftStickY, value: axisValue1, window: windowId, time: time)
        await self.input.receiveEvent(leftStickYEvent1)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepad(for: gamepadId1)?.getAxisValue(.leftStickY) == axisValue1, "Gamepad 1 Left Stick Y should be \(axisValue1).")
        #expect(self.input.getConnectedGamepad(for: gamepadId0)?.getAxisValue(.leftStickY) == 0.0, "Gamepad 0 Left Stick Y should be 0.0 (initial).")

        // Disconnect gamepad 0
        time = AdaUtils.TimeInterval(Date().timeIntervalSince1970)
        let disconnectEvent0 = GamepadConnectionEvent(gamepadId: gamepadId0, isConnected: false, gamepadInfo: nil, window: windowId, time: time)
        await self.input.receiveEvent(disconnectEvent0)
        await world.runScheduler(.update)

        #expect(self.input.getConnectedGamepad(for: gamepadId0) == nil, "Gamepad 0 should be disconnected.")
        #expect(self.input.getConnectedGamepad(for: gamepadId1) != nil, "Gamepad 1 should still be connected.")
        #expect(self.input.getConnectedGamepads().contains { $0.gamepadId == gamepadId0 } == false, "Connected list should not contain Gamepad 0.")
        #expect(self.input.getConnectedGamepads().contains { $0.gamepadId == gamepadId1 } == true, "Connected list should still contain Gamepad 1.")
    }
}

extension Input {
    public func getConnectedGamepads() -> [Gamepad] {
        return Array(self.gamepads.values)
    }

    public func getConnectedGamepad(for gamepadId: Gamepad.ID) -> Gamepad? {
        return self.gamepads[gamepadId]
    }
}
