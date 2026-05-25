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
@_spi(Internal) @testable import AdaUI

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

    @Test
    func textEditor_visibleLineRangeHandlesBottomOverscroll() throws {
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
            .frame(width: 240, height: 80)
        }
        .setSize(Size(width: 260, height: 100))
        .performLayout()

        let node = try #require(tester.sendMouseEvent(at: Point(40, 40), phase: .began, time: 0) as? TextEditorViewNode)
        tester.sendMouseEvent(at: Point(40, 40), phase: .ended, time: 0.01)
        tester.sendMouseEvent(
            at: Point(40, 40),
            button: .scrollWheel,
            phase: .changed,
            scrollDelta: Point(0, -100),
            time: 0.02
        )

        let lineHeight = node.lineHeight(for: node.resolvedFontPointSize())
        let range = node.visibleLineRange(lineHeight: lineHeight, viewportHeight: 80)

        #expect(node.nearestScrollView()?.contentOffset.y ?? 0 > lineHeight)
        #expect(range == node.lines().count..<node.lines().count)
    }

    @Test
    func textEditor_usesGlyphMetricsForCaretPosition() throws {
        final class Model {
            var text = "iiii"
        }

        let model = Model()
        let tester = ViewTester {
            TextEditor(
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                )
            )
            .font(.system(size: 18))
            .frame(width: 360, height: 160)
        }
        .setSize(Size(width: 380, height: 180))
        .performLayout()

        let node = try #require(tester.sendMouseEvent(at: Point(100, 28), phase: .began, time: 0) as? TextEditorViewNode)
        tester.sendMouseEvent(at: Point(100, 28), phase: .ended, time: 0.01)

        let font = try #require(node.resolvedFontForRendering())
        let pointSize = node.resolvedFontPointSize()
        let narrowEndX = node.caretXOffset(forColumn: 4, in: "iiii", font: font, pointSize: pointSize)
        let wideEndX = node.caretXOffset(forColumn: 4, in: "WWWW", font: font, pointSize: pointSize)

        #expect(wideEndX > narrowEndX)
    }

    @Test
    func textEditor_tokenSpansPreserveInterTokenWhitespace() throws {
        final class Model {
            var text = "import AdaEngine"
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

        let node = try #require(tester.sendMouseEvent(at: Point(100, 28), phase: .began, time: 0) as? TextEditorViewNode)
        let font = try #require(node.resolvedFontForRendering())
        let line = "import AdaEngine"
        let lineSpans = [
            TextEditorTokenSpan(line: 0, startColumn: 0, length: 6, color: .red),
            TextEditorTokenSpan(line: 0, startColumn: 7, length: 9, color: .blue)
        ]

        let attributedText = node.attributedLineText(line, lineSpans: lineSpans, font: font, fallbackColor: .white)
        let spaceIndex = line.index(line.startIndex, offsetBy: 6)
        let typeIndex = line.index(line.startIndex, offsetBy: 7)

        #expect(attributedText.text == line)
        #expect(attributedText.attributes(at: spaceIndex).foregroundColor == .white)
        #expect(attributedText.attributes(at: typeIndex).foregroundColor == .blue)
    }

    @Test
    func textEditor_sourceInteractionReportsCommandHoverAndClick() {
        final class Model {
            var text = "alpha\nbeta"
        }

        let model = Model()
        var hoveredPosition: TextEditorSourcePosition?
        var clickedPosition: TextEditorSourcePosition?
        let tester = ViewTester {
            TextEditor(
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                ),
                sourceInteraction: TextEditorSourceInteraction(
                    onHover: { hoveredPosition = $0 },
                    onPrimaryClick: { clickedPosition = $0 }
                )
            )
            .font(.system(size: 12))
            .frame(width: 360, height: 160)
        }
        .setSize(Size(width: 380, height: 180))
        .performLayout()

        tester.sendMouseEvent(at: Point(82, 16), button: .none, phase: .changed, modifierKeys: [.main], time: 0)
        #expect(hoveredPosition?.line == 0)
        #expect((hoveredPosition?.column ?? -1) >= 0)

        tester.sendMouseEvent(at: Point(82, 16), button: .left, phase: .began, modifierKeys: [.main], time: 0.01)
        #expect(clickedPosition?.line == hoveredPosition?.line)
        #expect(clickedPosition?.column == hoveredPosition?.column)

        tester.sendMouseEvent(at: Point(82, 16), button: .none, phase: .changed, time: 0.02)
        #expect(hoveredPosition == nil)
    }

    @Test
    func textEditor_sourceInteractionPresentsContextMenu() {
        final class Model {
            var text = "alpha"
        }

        let model = Model()
        var menuTitles: [String] = []
        var submenuTitles: [String] = []
        ContextMenuPresentationCenter.present = { presentation in
            menuTitles = presentation.items.map(\.title)
            submenuTitles = presentation.items.first?.submenu.map(\.title) ?? []
        }
        defer { ContextMenuPresentationCenter.present = nil }

        let tester = ViewTester {
            TextEditor(
                text: Binding(
                    get: { model.text },
                    set: { model.text = $0 }
                ),
                sourceInteraction: TextEditorSourceInteraction(
                    contextMenuItems: { _ in
                        [
                            TextEditorContextMenuItem(
                                title: "Go To",
                                submenu: [
                                    TextEditorContextMenuItem(title: "Definition")
                                ]
                            ),
                            TextEditorContextMenuItem(title: "Find References")
                        ]
                    }
                )
            )
            .font(.system(size: 12))
            .frame(width: 360, height: 160)
        }
        .setSize(Size(width: 380, height: 180))
        .performLayout()

        tester.sendMouseEvent(at: Point(82, 16), button: .right, phase: .began, time: 0)

        #expect(menuTitles == ["Go To", "Find References"])
        #expect(submenuTitles == ["Definition"])
    }
}
