import AdaInput
@_spi(Internal) @testable import AdaUI
import Math
import Testing

@testable import AdaPlatform

@MainActor
struct TextEditorTouchTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test("Long press on existing selection presents editing/source actions once and preserves its range")
    func selectedLongPressMenu() throws {
        var presentations: [ContextMenuPresentation] = []
        var chatText: String?
        var sourceAction = false
        let previous = ContextMenuPresentationCenter.present
        ContextMenuPresentationCenter.present = { presentations.append($0) }
        defer { ContextMenuPresentationCenter.present = previous }
        let tester = ViewTester {
            TextEditor(text: .constant("alpha beta gamma"), sourceInteraction: .init(
                onChatSelection: { _, text in chatText = text },
                contextMenuItems: { _ in [TextEditorContextMenuItem(title: "Source Action") { sourceAction = true }] }
            )).font(.system(size: 12)).frame(width: 360, height: 160)
        }.setSize(Size(width: 380, height: 180)).performLayout()
        let node = try #require(tester.hitTest(Point(40, 16), event: TouchEvent(window: .empty, location: Point(40, 16), phase: .began, time: 0)) as? TextEditorViewNode)
        node.selectionAnchor = 0
        node.selectionHead = 10
        let caret = node.selectionCaretRect(at: 3)
        let frame = node.visualAbsoluteFrame()
        let point = Point(frame.minX + caret.minX + 1, frame.minY + caret.midY)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .began, time: 1)])
        for _ in 0..<10 { node.update(0.1) }
        #expect(presentations.count == 1)
        #expect(node.selectionRange == 0..<10)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .ended, time: 2)])
        #expect(node.selectionRange == 0..<10)
        let menu = try #require(presentations.first)
        #expect(menu.items.map(\.title) == ["Copy", "Cut", "Paste", "Select All", "Chat About Selection", "Source Action"])
        menu.items.first { $0.title == "Chat About Selection" }?.action?()
        #expect(chatText == "alpha beta")
        menu.items.first { $0.title == "Source Action" }?.action?()
        #expect(sourceAction)
    }

    @Test("Cancelled hold and swipe on existing selection do not open a menu")
    func selectedCancelledHold() throws {
        var menus = 0
        let previous = ContextMenuPresentationCenter.present
        ContextMenuPresentationCenter.present = { _ in menus += 1 }
        defer { ContextMenuPresentationCenter.present = previous }
        let (tester, node) = try makeScrollableEditor()
        node.selectionAnchor = 0
        node.selectionHead = 10
        let caret = node.selectionCaretRect(at: 3)
        let frame = node.visualAbsoluteFrame()
        let point = Point(frame.minX + caret.minX + 1, frame.minY + caret.midY)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .began, time: 1)])
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .cancelled, time: 1.1)])
        for _ in 0..<10 { node.update(0.1) }
        #expect(menus == 0)
        #expect(node.selectionRange == 0..<10)
    }

    @Test("A swipe scrolls code without focus, caret movement or selection")
    func swipeScrolls() throws {
        let (tester, node) = try makeScrollableEditor()
        let start = Point(150, 110)
        let caret = node.caretOffset
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: start, phase: .began, time: 0)])
        #expect(!node.isFocused)
        #expect(!node.isSelectingWithTouch)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 45), phase: .moved, time: 0.1)])
        let scroll = try #require(node.nearestScrollView())
        #expect(scroll.contentOffset.y > 40)
        node.update(0.1)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 30), phase: .ended, time: 0.2)])
        #expect(!node.isFocused)
        #expect(!node.hasSelection)
        #expect(node.caretOffset == caret)
    }

    @Test("Stationary long press arms selection; dragging selects without scrolling")
    func longPressThenDrag() throws {
        let (tester, node) = try makeScrollableEditor()
        let start = Point(110, 48)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: start, phase: .began, time: 0)])
        for _ in 0..<5 { node.update(0.1) }
        #expect(node.isFocused)
        #expect(node.isSelectingWithTouch)
        #expect(node.hasSelection)
        let scroll = try #require(node.nearestScrollView())
        let before = scroll.contentOffset
        let anchor = node.selectionAnchor
        let destination = Point(230, 85)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: destination, phase: .moved, time: 0.6)])
        #expect(node.selectionAnchor == anchor)
        #expect(node.selectionHead != anchor)
        #expect(scroll.contentOffset == before)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: destination, phase: .ended, time: 0.7)])
        #expect(node.hasSelection)
        #expect(!node.isSelectingWithTouch)
    }

    @Test("Swiping an already focused editor preserves the current selection")
    func focusedSwipePreservesSelection() throws {
        let (tester, node) = try makeScrollableEditor()
        let tap = Point(110, 48)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: tap, phase: .began, time: 0)])
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: tap, phase: .ended, time: 0.01)])
        node.selectionAnchor = 1
        node.selectionHead = 8
        let selection = node.selectionRange
        let scroll = try #require(node.nearestScrollView())
        let before = scroll.contentOffset.y
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 110), phase: .began, time: 1)])
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 45), phase: .moved, time: 1.1)])
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 30), phase: .ended, time: 1.2)])
        #expect(node.isFocused)
        #expect(node.selectionRange == selection)
        #expect(scroll.contentOffset.y > before + 40)
    }

    @Test("A drag cannot become a selection when the finger later pauses")
    func pauseDuringScroll() throws {
        let (tester, node) = try makeScrollableEditor()
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 110), phase: .began, time: 0)])
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 60), phase: .moved, time: 0.1)])
        for _ in 0..<10 { node.update(0.1) }
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 40), phase: .moved, time: 1.2)])
        #expect(!node.isFocused)
        #expect(!node.hasSelection)
        #expect(try #require(node.nearestScrollView()).contentOffset.y > 50)
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 40), phase: .cancelled, time: 1.3)])
    }

    @Test("A cancelled touch never activates editing after the hold delay")
    func cancellationClearsHold() throws {
        let (tester, node) = try makeScrollableEditor()
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 90), phase: .began, time: 0)])
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(150, 90), phase: .cancelled, time: 0.1)])
        for _ in 0..<5 { node.update(0.1) }
        #expect(!node.isFocused)
        #expect(!node.hasSelection)
        #expect(node.touchSession == nil)
    }

    private func makeScrollableEditor() throws -> (ViewTester<TextEditorFixture>, TextEditorViewNode) {
        let text = (0..<80).map { "line \($0): alpha beta gamma delta epsilon" }.joined(separator: "\n")
        let tester = ViewTester { TextEditorFixture(text: text) }
            .setSize(Size(width: 380, height: 180)).performLayout()
        let event = TouchEvent(window: .empty, location: Point(150, 110), phase: .began, time: 0)
        let node = try #require(tester.hitTest(event.location, event: event) as? TextEditorViewNode)
        return (tester, node)
    }

    @Test
    func textEditor_touchMovesCaretToTappedPosition() throws {
        final class Model {
            var text = "alpha\nbeta"
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

        let touchPoint = Point(110, 48)
        let began = TouchEvent(window: .empty, location: touchPoint, phase: .began, time: 0)
        let node = try #require(tester.hitTest(touchPoint, event: began) as? TextEditorViewNode)
        let expectedOffset = node.closestOffset(to: node.convertPointFromRoot(touchPoint))

        tester.containerView.onTouchesEvent([began])
        tester.containerView.onTouchesEvent([
            TouchEvent(window: .empty, location: touchPoint, phase: .ended, time: 0.01)
        ])

        #expect(expectedOffset > 0)
        #expect(node.isFocused)
        #expect(node.caretOffset == expectedOffset)
        #expect(!node.hasSelection)
    }
}

private struct TextEditorFixture: View {
    let text: String
    var body: some View {
        TextEditor(text: .constant(text))
            .font(.system(size: 12))
            .frame(width: 360, height: 160)
    }
}
