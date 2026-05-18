//
//  TextEditorTests.swift
//  AdaEngine
//
//  Created by Codex on 18.05.2026.
//

import AdaInput
import Math
import Testing
@testable import AdaPlatform
@testable import AdaUI

@MainActor
struct TextEditorTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func textEditor_supportsMultilineEditingAndUndoRedo() {
        final class Model {
            var text = "alpha"
        }

        let model = Model()
        let tester = ViewTester {
            TextEditor(
                "Write code",
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .font(.system(size: 12))
            .frame(width: 360, height: 160)
        }
        .setSize(Size(width: 380, height: 180))
        .performLayout()

        tester.sendMouseEvent(at: Point(100, 28), phase: .began, time: 0)
        tester.sendMouseEvent(at: Point(100, 28), phase: .ended, time: 0.01)
        tester.sendKeyEvent(.a, modifiers: [.control], time: 0.02)
        tester.sendTextInput("one", time: 0.03)
        tester.sendKeyEvent(.enter, time: 0.04)
        tester.sendTextInput("two", time: 0.05)

        #expect(model.text == "one\ntwo")

        tester.sendKeyEvent(.z, modifiers: [.control], time: 0.06)
        #expect(model.text == "one\n")

        tester.sendKeyEvent(.y, modifiers: [.control], time: 0.07)
        #expect(model.text == "one\ntwo")
    }

    @Test
    func textEditor_movesCaretAcrossLines() {
        final class Model {
            var text = "abc\ndefg\nhi"
        }

        let model = Model()
        let tester = ViewTester {
            TextEditor(
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .font(.system(size: 12))
            .frame(width: 360, height: 160)
        }
        .setSize(Size(width: 380, height: 180))
        .performLayout()

        tester.sendMouseEvent(at: Point(100, 28), phase: .began, time: 0)
        tester.sendMouseEvent(at: Point(100, 28), phase: .ended, time: 0.01)
        tester.sendKeyEvent(.a, modifiers: [.control], time: 0.02)
        tester.sendTextInput(model.text, time: 0.03)
        tester.sendKeyEvent(.arrowUp, time: 0.04)
        tester.sendTextInput("X", time: 0.05)

        #expect(model.text == "abc\ndeXfg\nhi")
    }

    @Test
    func textEditor_supportsCopyPasteAndTabInsertion() {
        final class Model {
            var text = "value"
        }

        let model = Model()
        let tester = ViewTester {
            TextEditor(
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .font(.system(size: 12))
            .frame(width: 360, height: 160)
        }
        .setSize(Size(width: 380, height: 180))
        .performLayout()

        tester.sendMouseEvent(at: Point(100, 28), phase: .began, time: 0)
        tester.sendMouseEvent(at: Point(100, 28), phase: .ended, time: 0.01)
        tester.sendKeyEvent(.a, modifiers: [.control], time: 0.02)
        tester.sendKeyEvent(.c, modifiers: [.control], time: 0.03)
        tester.sendKeyEvent(.pageDown, time: 0.04)
        tester.sendKeyEvent(.enter, time: 0.05)
        tester.sendKeyEvent(.tab, time: 0.06)
        tester.sendKeyEvent(.v, modifiers: [.control], time: 0.07)

        #expect(model.text == "value\n    value")
    }
}
