//
//  GamepadInputTests.swift
//  AdaEngineTests
//
//  Created by v.prusakov on 7/12/22.
//

import Testing
@testable import AdaEngine

@Suite("Gamepad Input Tests")
final class GamepadInputTests: Sendable {

    let input: Input

    init() async {
        // Clear gamepad states and events before each test
        self.input = Input()
        self.input._removeAllStates()
        await self.input.removeEvents()
    }

    deinit {
        self.input._removeAllStates()
    }

    @Test("Gamepad Connection and Disconnection")
    func testGamepadConnectionAndDisconnection() async {
        #expect(Input.getConnectedGamepads().count == 0, "Gamepads should be empty.")

        let gamepadId = 0
        let windowId = UIWindow.ID.empty
        var time = TimeInterval(Date().timeIntervalSince1970)

        // Connect gamepad
        let connectEvent = GamepadConnectionEvent(
            gamepadId: gamepadId,
            isConnected: true,
            gamepadInfo: nil,
            window: windowId,
            time: time
        )

        await input.receiveEvent(connectEvent)

        #expect(Input.getConnectedGamepads().count == 1, "Gamepad \(gamepadId) should be connected.")
        #expect(Input.getConnectedGamepads().contains { $0.gamepadId == gamepadId }, "Connected gamepads list should contain \(gamepadId).")

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

        #expect(Input.getConnectedGamepads().count == 0, "Gamepad \(gamepadId) should be disconnected.")
    }

    @Test("Gamepad Button Press and Release")
    func testGamepadButtonPressAndRelease() async throws {
        #expect(Input.getConnectedGamepads().count == 0, "Gamepads should be empty.")
        
        let gamepadId = 1
        let windowId = UIWindow.ID.empty
        var time = TimeInterval(Date().timeIntervalSince1970)

        // Connect gamepad
        let connectEvent = GamepadConnectionEvent(
            gamepadId: gamepadId,
            isConnected: true,
            gamepadInfo: nil,
            window: windowId,
            time: time
        )

        await self.input.receiveEvent(connectEvent)
        #expect(Input.getConnectedGamepads().count == 1)

        // Press button A
        time = TimeInterval(Date().timeIntervalSince1970)
        let buttonAPressEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .a, isPressed: true, pressure: 1.0, window: windowId, time: time)
        await self.input.receiveEvent(buttonAPressEvent)
        #expect(Input.getConnectedGamepads().first?.isGamepadButtonPressed(.a) == true, "Button A should be pressed.")

        // Release button A
        time = TimeInterval(Date().timeIntervalSince1970)
        let buttonAReleaseEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .a, isPressed: false, pressure: 0.0, window: windowId, time: time)
        await self.input.receiveEvent(buttonAReleaseEvent)
        #expect(Input.getConnectedGamepads().first?.isGamepadButtonPressed(.a) == false, "Button A should be released.")

        // Press Left Shoulder
        time = TimeInterval(Date().timeIntervalSince1970)
        let leftShoulderPressEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .leftShoulder, isPressed: true, pressure: 1.0, window: windowId, time: time)
        await self.input.receiveEvent(leftShoulderPressEvent)
        #expect(Input.getConnectedGamepads().first?.isGamepadButtonPressed(.leftShoulder) == true, "Left Shoulder should be pressed.")

        // Release Left Shoulder
        time = TimeInterval(Date().timeIntervalSince1970)
        let leftShoulderReleaseEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .leftShoulder, isPressed: false, pressure: 0.0, window: windowId, time: time)
        await self.input.receiveEvent(leftShoulderReleaseEvent)
        #expect(Input.getConnectedGamepads().first?.isGamepadButtonPressed(.leftShoulder) == false, "Left Shoulder should be released.")
    }

//    @Test("Gamepad Axis Value")
//    func testGamepadAxisValue() async {
//        let gamepadId = 2
//        let windowId = UIWindow.ID.empty
//        var time = TimeInterval(Date().timeIntervalSince1970)
//        let accuracy: Float = 0.0001
//
//        // Connect gamepad
//        let connectEvent = GamepadConnectionEvent(gamepadId: gamepadId, isConnected: true, gamepadInfo: nil, window: windowId, time: time)
//        await self.input.receiveEvent(connectEvent)
//
//        // Move Left Stick X
//        var axisValue: Float = 0.75
//        time = Date().timeIntervalSince1970
//        let leftStickXEvent = GamepadAxisEvent(gamepadId: gamepadId, axis: .leftStickX, value: axisValue, window: windowId, time: time)
//        self.input.receiveEvent(leftStickXEvent)
//        #expect(Input.getGamepadAxisValue(gamepadId, axis: .leftStickX)).toBeCloseTo(axisValue, within: accuracy, "Left Stick X value should be \(axisValue).")
//
//        // Move Left Stick X again
//        axisValue = -0.5
//        time = Date().timeIntervalSince1970
//        let leftStickXEvent2 = GamepadAxisEvent(gamepadId: gamepadId, axis: .leftStickX, value: axisValue, window: windowId, time: time)
//        self.input.receiveEvent(leftStickXEvent2)
//        #expect(Input.getGamepadAxisValue(gamepadId, axis: .leftStickX)).toBeCloseTo(axisValue, within: accuracy, "Left Stick X value should be \(axisValue).")
//
//        // Move Right Trigger
//        axisValue = 0.9
//        time = Date().timeIntervalSince1970
//        let rightTriggerEvent = GamepadAxisEvent(gamepadId: gamepadId, axis: .rightTrigger, value: axisValue, window: windowId, time: time)
//        self.input.receiveEvent(rightTriggerEvent)
//        #expect(Input.getGamepadAxisValue(gamepadId, axis: .rightTrigger)).toBeCloseTo(axisValue, within: accuracy, "Right Trigger value should be \(axisValue).")
//    }

//    @Test("Get Gamepad Info")
//    func testGetGamepadInfo() async {
//        let gamepadId = 3
//        let windowId = UIWindow.ID.empty.id
//        let time = Date().timeIntervalSince1970
//
//        // Connect gamepad (InputManager will create a GamepadState with default GamepadInfo)
//        let connectEvent = GamepadConnectionEvent(gamepadId: gamepadId, isConnected: true, window: windowId, time: time)
//        self.input.receiveEvent(connectEvent)
//        expect(Input.isGamepadConnected(gamepadId: gamepadId)).toBeTrue()
//
//        // Simulate platform manager setting the GamepadInfo
//        let testControllerName = "TestController"
//        let testControllerType = "TestType"
//        self.input.gamepads[gamepadId]?.info = Input.GamepadInfo(name: testControllerName, type: testControllerType)
//
//        let info = Input.getGamepadInfo(gamepadId: gamepadId)
//        expect(info).notToBeNil("GamepadInfo should not be nil for connected gamepad \(gamepadId).")
//        expect(info?.name).toBe(testControllerName, "Gamepad name should be \(testControllerName).")
//        expect(info?.type).toBe(testControllerType, "Gamepad type should be \(testControllerType).")
//
//        // Test non-existent gamepad
//        expect(Input.getGamepadInfo(gamepadId: 99)).toBeNil("GamepadInfo for a non-existent gamepad (ID 99) should be nil.")
//    }
//
//    @Test("Multiple Gamepads")
//    func testMultipleGamepads() async {
//        let gamepadId0 = 0
//        let gamepadId1 = 1
//        let windowId = UIWindow.empty.id
//        var time = Date().timeIntervalSince1970
//        let accuracy: Float = 0.0001
//
//        // Connect gamepad 0
//        let connectEvent0 = GamepadConnectionEvent(gamepadId: gamepadId0, isConnected: true, window: windowId, time: time)
//        self.input.receiveEvent(connectEvent0)
//        expect(Input.isGamepadConnected(gamepadId: gamepadId0)).toBeTrue()
//
//        // Connect gamepad 1
//        time = Date().timeIntervalSince1970
//        let connectEvent1 = GamepadConnectionEvent(gamepadId: gamepadId1, isConnected: true, window: windowId, time: time)
//        self.input.receiveEvent(connectEvent1)
//        expect(Input.isGamepadConnected(gamepadId: gamepadId1)).toBeTrue()
//
//        // Press button B on gamepad 0
//        time = Date().timeIntervalSince1970
//        let buttonBPress0 = GamepadButtonEvent(gamepadId: gamepadId0, button: .b, isPressed: true, pressure: 1.0, window: windowId, time: time)
//        self.input.receiveEvent(buttonBPress0)
//
//        expect(Input.isGamepadButtonPressed(gamepadId0, button: .b)).toBeTrue("Gamepad 0 Button B should be pressed.")
//        expect(Input.isGamepadButtonPressed(gamepadId1, button: .b)).toBeFalse("Gamepad 1 Button B should NOT be pressed.")
//
//        // Move axis Left Stick Y on gamepad 1
//        let axisValue1: Float = 0.65
//        time = Date().timeIntervalSince1970
//        let leftStickYEvent1 = GamepadAxisEvent(gamepadId: gamepadId1, axis: .leftStickY, value: axisValue1, window: windowId, time: time)
//        self.input.receiveEvent(leftStickYEvent1)
//
//        expect(Input.getGamepadAxisValue(gamepadId1, axis: .leftStickY)).toBeCloseTo(axisValue1, within: accuracy, "Gamepad 1 Left Stick Y should be \(axisValue1).")
//        expect(Input.getGamepadAxisValue(gamepadId0, axis: .leftStickY)).toBeCloseTo(0.0, within: accuracy, "Gamepad 0 Left Stick Y should be 0.0 (initial).")
//
//        // Disconnect gamepad 0
//        time = Date().timeIntervalSince1970
//        let disconnectEvent0 = GamepadConnectionEvent(gamepadId: gamepadId0, isConnected: false, window: windowId, time: time)
//        self.input.receiveEvent(disconnectEvent0)
//
//        expect(Input.isGamepadConnected(gamepadId: gamepadId0)).toBeFalse("Gamepad 0 should be disconnected.")
//        expect(Input.isGamepadConnected(gamepadId: gamepadId1)).toBeTrue("Gamepad 1 should still be connected.")
//        expect(Input.getConnectedGamepadIds().contains(gamepadId0)).toBeFalse("Connected list should not contain Gamepad 0.")
//        expect(Input.getConnectedGamepadIds().contains(gamepadId1)).toBeTrue("Connected list should still contain Gamepad 1.")
//    }
}
