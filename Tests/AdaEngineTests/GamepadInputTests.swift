//
//  GamepadInputTests.swift
//  AdaEngineTests
//
//  Created by v.prusakov on 7/12/22.
//

import XCTest
@testable import AdaEngine

final class GamepadInputTests: XCTestCase {

    @MainActor
    override func setUp() {
        super.setUp()
        // Clear gamepad states and events before each test
        Input.shared.gamepads.removeAll()
        Input.shared.removeEvents() // Assuming removeEvents clears the eventsPool
    }

    @MainActor
    override func tearDown() {
        // Clear gamepad states and events after each test
        Input.shared.gamepads.removeAll()
        Input.shared.removeEvents()
        super.tearDown()
    }

    // Test cases will be implemented here
    @MainActor
    func testGamepadConnectionAndDisconnection() {
        let gamepadId = 0
        let windowId = UIWindow.empty.id
        var time = Date().timeIntervalSince1970

        // Connect gamepad
        let connectEvent = GamepadConnectionEvent(gamepadId: gamepadId, isConnected: true, window: windowId, time: time)
        Input.shared.receiveEvent(connectEvent)

        XCTAssertTrue(Input.isGamepadConnected(gamepadId: gamepadId), "Gamepad \(gamepadId) should be connected.")
        XCTAssertTrue(Input.getConnectedGamepadIds().contains(gamepadId), "Connected gamepads list should contain \(gamepadId).")

        // Disconnect gamepad
        time = Date().timeIntervalSince1970 // Update time for new event
        let disconnectEvent = GamepadConnectionEvent(gamepadId: gamepadId, isConnected: false, window: windowId, time: time)
        Input.shared.receiveEvent(disconnectEvent)

        XCTAssertFalse(Input.isGamepadConnected(gamepadId: gamepadId), "Gamepad \(gamepadId) should be disconnected.")
        XCTAssertFalse(Input.getConnectedGamepadIds().contains(gamepadId), "Connected gamepads list should not contain \(gamepadId).")
    }

    @MainActor
    func testGamepadButtonPressAndRelease() {
        let gamepadId = 1
        let windowId = UIWindow.empty.id
        var time = Date().timeIntervalSince1970

        // Connect gamepad
        let connectEvent = GamepadConnectionEvent(gamepadId: gamepadId, isConnected: true, window: windowId, time: time)
        Input.shared.receiveEvent(connectEvent)
        XCTAssertTrue(Input.isGamepadConnected(gamepadId: gamepadId))

        // Press button A
        time = Date().timeIntervalSince1970
        let buttonA onPressEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .a, isPressed: true, pressure: 1.0, window: windowId, time: time)
        Input.shared.receiveEvent(buttonA onPressEvent)
        XCTAssertTrue(Input.isGamepadButtonPressed(gamepadId, button: .a), "Button A should be pressed.")

        // Release button A
        time = Date().timeIntervalSince1970
        let buttonA onReleaseEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .a, isPressed: false, pressure: 0.0, window: windowId, time: time)
        Input.shared.receiveEvent(buttonA onReleaseEvent)
        XCTAssertFalse(Input.isGamepadButtonPressed(gamepadId, button: .a), "Button A should be released.")

        // Press Left Shoulder
        time = Date().timeIntervalSince1970
        let leftShoulderPressEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .leftShoulder, isPressed: true, pressure: 1.0, window: windowId, time: time)
        Input.shared.receiveEvent(leftShoulderPressEvent)
        XCTAssertTrue(Input.isGamepadButtonPressed(gamepadId, button: .leftShoulder), "Left Shoulder should be pressed.")

        // Release Left Shoulder
        time = Date().timeIntervalSince1970
        let leftShoulderReleaseEvent = GamepadButtonEvent(gamepadId: gamepadId, button: .leftShoulder, isPressed: false, pressure: 0.0, window: windowId, time: time)
        Input.shared.receiveEvent(leftShoulderReleaseEvent)
        XCTAssertFalse(Input.isGamepadButtonPressed(gamepadId, button: .leftShoulder), "Left Shoulder should be released.")
    }

    @MainActor
    func testGamepadAxisValue() {
        let gamepadId = 2
        let windowId = UIWindow.empty.id
        var time = Date().timeIntervalSince1970
        let accuracy: Float = 0.0001

        // Connect gamepad
        let connectEvent = GamepadConnectionEvent(gamepadId: gamepadId, isConnected: true, window: windowId, time: time)
        Input.shared.receiveEvent(connectEvent)
        XCTAssertTrue(Input.isGamepadConnected(gamepadId: gamepadId))

        // Move Left Stick X
        var axisValue: Float = 0.75
        time = Date().timeIntervalSince1970
        let leftStickXEvent = GamepadAxisEvent(gamepadId: gamepadId, axis: .leftStickX, value: axisValue, window: windowId, time: time)
        Input.shared.receiveEvent(leftStickXEvent)
        XCTAssertEqual(Input.getGamepadAxisValue(gamepadId, axis: .leftStickX), axisValue, accuracy: accuracy, "Left Stick X value should be \(axisValue).")

        // Move Left Stick X again
        axisValue = -0.5
        time = Date().timeIntervalSince1970
        let leftStickXEvent2 = GamepadAxisEvent(gamepadId: gamepadId, axis: .leftStickX, value: axisValue, window: windowId, time: time)
        Input.shared.receiveEvent(leftStickXEvent2)
        XCTAssertEqual(Input.getGamepadAxisValue(gamepadId, axis: .leftStickX), axisValue, accuracy: accuracy, "Left Stick X value should be \(axisValue).")

        // Move Right Trigger
        axisValue = 0.9
        time = Date().timeIntervalSince1970
        let rightTriggerEvent = GamepadAxisEvent(gamepadId: gamepadId, axis: .rightTrigger, value: axisValue, window: windowId, time: time)
        Input.shared.receiveEvent(rightTriggerEvent)
        XCTAssertEqual(Input.getGamepadAxisValue(gamepadId, axis: .rightTrigger), axisValue, accuracy: accuracy, "Right Trigger value should be \(axisValue).")
    }

    @MainActor
    func testGetGamepadInfo() {
        let gamepadId = 3
        let windowId = UIWindow.empty.id
        let time = Date().timeIntervalSince1970

        // Connect gamepad (InputManager will create a GamepadState with default GamepadInfo)
        let connectEvent = GamepadConnectionEvent(gamepadId: gamepadId, isConnected: true, window: windowId, time: time)
        Input.shared.receiveEvent(connectEvent)
        XCTAssertTrue(Input.isGamepadConnected(gamepadId: gamepadId))

        // Simulate platform manager setting the GamepadInfo
        let testControllerName = "TestController"
        let testControllerType = "TestType"
        Input.shared.gamepads[gamepadId]?.info = Input.GamepadInfo(name: testControllerName, type: testControllerType)

        let info = Input.getGamepadInfo(gamepadId: gamepadId)
        XCTAssertNotNil(info, "GamepadInfo should not be nil for connected gamepad \(gamepadId).")
        XCTAssertEqual(info?.name, testControllerName, "Gamepad name should be \(testControllerName).")
        XCTAssertEqual(info?.type, testControllerType, "Gamepad type should be \(testControllerType).")

        // Test non-existent gamepad
        XCTAssertNil(Input.getGamepadInfo(gamepadId: 99), "GamepadInfo for a non-existent gamepad (ID 99) should be nil.")
    }

    @MainActor
    func testMultipleGamepads() {
        let gamepadId0 = 0
        let gamepadId1 = 1
        let windowId = UIWindow.empty.id
        var time = Date().timeIntervalSince1970
        let accuracy: Float = 0.0001

        // Connect gamepad 0
        let connectEvent0 = GamepadConnectionEvent(gamepadId: gamepadId0, isConnected: true, window: windowId, time: time)
        Input.shared.receiveEvent(connectEvent0)
        XCTAssertTrue(Input.isGamepadConnected(gamepadId: gamepadId0))

        // Connect gamepad 1
        time = Date().timeIntervalSince1970
        let connectEvent1 = GamepadConnectionEvent(gamepadId: gamepadId1, isConnected: true, window: windowId, time: time)
        Input.shared.receiveEvent(connectEvent1)
        XCTAssertTrue(Input.isGamepadConnected(gamepadId: gamepadId1))

        // Press button B on gamepad 0
        time = Date().timeIntervalSince1970
        let buttonBPress0 = GamepadButtonEvent(gamepadId: gamepadId0, button: .b, isPressed: true, pressure: 1.0, window: windowId, time: time)
        Input.shared.receiveEvent(buttonBPress0)

        XCTAssertTrue(Input.isGamepadButtonPressed(gamepadId0, button: .b), "Gamepad 0 Button B should be pressed.")
        XCTAssertFalse(Input.isGamepadButtonPressed(gamepadId1, button: .b), "Gamepad 1 Button B should NOT be pressed.")

        // Move axis Left Stick Y on gamepad 1
        let axisValue1: Float = 0.65
        time = Date().timeIntervalSince1970
        let leftStickYEvent1 = GamepadAxisEvent(gamepadId: gamepadId1, axis: .leftStickY, value: axisValue1, window: windowId, time: time)
        Input.shared.receiveEvent(leftStickYEvent1)

        XCTAssertEqual(Input.getGamepadAxisValue(gamepadId1, axis: .leftStickY), axisValue1, accuracy: accuracy, "Gamepad 1 Left Stick Y should be \(axisValue1).")
        XCTAssertEqual(Input.getGamepadAxisValue(gamepadId0, axis: .leftStickY), 0.0, accuracy: accuracy, "Gamepad 0 Left Stick Y should be 0.0 (initial).")

        // Disconnect gamepad 0
        time = Date().timeIntervalSince1970
        let disconnectEvent0 = GamepadConnectionEvent(gamepadId: gamepadId0, isConnected: false, window: windowId, time: time)
        Input.shared.receiveEvent(disconnectEvent0)

        XCTAssertFalse(Input.isGamepadConnected(gamepadId: gamepadId0), "Gamepad 0 should be disconnected.")
        XCTAssertTrue(Input.isGamepadConnected(gamepadId: gamepadId1), "Gamepad 1 should still be connected.")
        XCTAssertFalse(Input.getConnectedGamepadIds().contains(gamepadId0), "Connected list should not contain Gamepad 0.")
        XCTAssertTrue(Input.getConnectedGamepadIds().contains(gamepadId1), "Connected list should still contain Gamepad 1.")
    }
}
