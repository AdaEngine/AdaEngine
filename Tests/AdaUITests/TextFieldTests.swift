//
//  TextFieldTests.swift
//  AdaEngine
//
//  Created by Codex on 19.02.2026.
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
import AdaInput
import Math

@MainActor
struct TextFieldTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func textField_supportsSelectionCopyPasteAndUndoRedo() {
        final class Model {
            var text: String = "hello"
        }

        let model = Model()

        let tester = ViewTester {
            TextField(
                "Type here",
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .frame(width: 240, height: 36)
        }
        .setSize(Size(width: 260, height: 80))
        .performLayout()

        // Focus text field.
        let focusPoint = Point(130, 40)
        tester.sendMouseEvent(at: focusPoint, phase: .began, time: 0)
        tester.sendMouseEvent(at: focusPoint, phase: .ended, time: 0.01)

        // Select all and replace by typed text.
        tester.sendKeyEvent(.a, modifiers: [.control], time: 0.02)
        tester.sendTextInput("world", time: 0.03)
        #expect(model.text == "world")

        // Undo and redo.
        tester.sendKeyEvent(.z, modifiers: [.control], time: 0.04)
        #expect(model.text == "hello")

        tester.sendKeyEvent(.y, modifiers: [.control], time: 0.05)
        #expect(model.text == "world")

        // Copy selected text, clear field, then paste back.
        tester.sendKeyEvent(.a, modifiers: [.control], time: 0.06)
        tester.sendKeyEvent(.c, modifiers: [.control], time: 0.07)
        tester.sendKeyEvent(.delete, time: 0.08)
        #expect(model.text == "")

        tester.sendKeyEvent(.v, modifiers: [.control], time: 0.09)
        #expect(model.text == "world")

        // Backspace should delete exactly one symbol when platform emits both
        // key event and text input delete event.
        tester.sendKeyEvent(.backspace, time: 0.10)
        tester.sendDeleteBackward(time: 0.11)
        #expect(model.text == "worl")
    }

    @Test
    func textField_updatesSelectionInteractivelyOnMouseDragChanged() {
        final class Model {
            var text: String = "hello world"
        }

        let model = Model()
        let originalText = model.text

        let tester = ViewTester {
            TextField(
                "Type here",
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .frame(width: 240, height: 36)
        }
        .setSize(Size(width: 260, height: 80))
        .performLayout()

        // Focus text field.
        let focusPoint = Point(130, 40)
        tester.sendMouseEvent(at: focusPoint, phase: .began, time: 0)
        tester.sendMouseEvent(at: focusPoint, phase: .ended, time: 0.01)

        // Drag-selection: `.changed` from platform can come with `button = .none`.
        tester.sendMouseEvent(
            at: Point(12, 40),
            button: .left,
            phase: .began,
            time: 0.02
        )
        tester.sendMouseEvent(
            at: Point(500, 40),
            button: .none,
            phase: .changed,
            time: 0.03
        )
        tester.sendMouseEvent(
            at: Point(500, 40),
            button: .left,
            phase: .ended,
            time: 0.04
        )

        // Replacement confirms selection was updated during drag.
        tester.sendTextInput("X", time: 0.05)
        #expect(model.text != originalText)
        #expect(model.text.count < originalText.count)
    }

    @Test
    func textField_mainArrowLeftMovesCaretToPreviousWordBoundary() {
        final class Model {
            var text: String = "hello world test"
        }

        let model = Model()

        let tester = ViewTester {
            TextField(
                "Type here",
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .frame(width: 240, height: 36)
        }
        .setSize(Size(width: 260, height: 80))
        .performLayout()

        let focusPoint = Point(130, 40)
        tester.sendMouseEvent(at: focusPoint, phase: .began, time: 0)
        tester.sendMouseEvent(at: focusPoint, phase: .ended, time: 0.01)

        tester.sendKeyEvent(.pageDown, time: 0.02)
        tester.sendKeyEvent(.arrowLeft, modifiers: [.main], time: 0.03)
        tester.sendTextInput("X", time: 0.04)

        #expect(model.text == "hello world Xtest")
    }

    @Test
    func textField_mainArrowRightMovesCaretToNextWordBoundary() {
        final class Model {
            var text: String = "hello world test"
        }

        let model = Model()

        let tester = ViewTester {
            TextField(
                "Type here",
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .frame(width: 240, height: 36)
        }
        .setSize(Size(width: 260, height: 80))
        .performLayout()

        let focusPoint = Point(130, 40)
        tester.sendMouseEvent(at: focusPoint, phase: .began, time: 0)
        tester.sendMouseEvent(at: focusPoint, phase: .ended, time: 0.01)

        tester.sendKeyEvent(.home, time: 0.02)
        tester.sendKeyEvent(.arrowRight, modifiers: [.main], time: 0.03)
        tester.sendTextInput("X", time: 0.04)

        #expect(model.text == "helloX world test")
    }

    @Test
    func textField_doubleClickSelectsWord() {
        final class Model {
            var text: String = "hello world"
        }

        let model = Model()

        let tester = ViewTester {
            TextField(
                "Type here",
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .frame(width: 240, height: 36)
        }
        .setSize(Size(width: 260, height: 80))
        .performLayout()

        let worldPoint = Point(70, 40)

        tester.sendMouseEvent(at: worldPoint, phase: .began, time: 0)
        tester.sendMouseEvent(at: worldPoint, phase: .ended, time: 0.05)
        tester.sendMouseEvent(at: worldPoint, phase: .began, time: 0.15)
        tester.sendMouseEvent(at: worldPoint, phase: .ended, time: 0.20)

        tester.sendTextInput("X", time: 0.25)
        #expect(model.text == "hello X")
    }
}
