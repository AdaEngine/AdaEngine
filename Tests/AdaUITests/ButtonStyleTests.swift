//
//  ButtonStyleTests.swift
//  AdaEngine
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
import AdaInput
import AdaUtils
import Math

@MainActor
struct ButtonStyleTests {

    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func buttonStyle_focusStateSurvivesHoverLeave() {
        let recorder = ButtonStyleStateRecorder()

        let tester = ViewTester {
            Button(action: {}) {
                Text("Tap")
                    .frame(width: 100, height: 44)
            }
            .buttonStyle(RecordingButtonStyle(recorder: recorder))
        }
        .setSize(Size(width: 200, height: 100))
        .performLayout()

        tester.sendMouseEvent(at: Point(100, 50), button: .left, phase: .began)
        tester.sendMouseEvent(at: Point(100, 50), button: .left, phase: .ended)
        tester.sendMouseEvent(at: Point(100, 50), button: .none, phase: .changed)
        tester.sendMouseEvent(at: Point(10, 10), button: .none, phase: .changed)

        #expect(recorder.states.last?.contains(.focused) == true)
        #expect(recorder.states.last?.contains(.highlighted) == false)
        #expect(recorder.states.last?.contains(.selected) == false)
    }

    @Test
    func navigationBarButtonStyleSurvivesEnvironmentUpdatesAndHover() throws {
        let tester = ViewTester {
            NavigationStack {
                Color.clear
                    .navigationTitle("Title")
                    .navigationBarTrailingItems {
                        Button("Edit") {}
                    }
            }
        }
        .setSize(Size(width: 300, height: 200))
        .performLayout()

        let button = try #require(buttonNodes(in: tester.containerView.viewTree.rootNode).first)
        #expect(button.environment.buttonStyle is NavigationBarButtonStyle)

        let buttonFrame = button.absoluteFrame()
        let buttonCenter = Point(
            x: buttonFrame.origin.x + buttonFrame.width * 0.5,
            y: buttonFrame.origin.y + buttonFrame.height * 0.5
        )
        tester.sendMouseEvent(at: buttonCenter, button: .none, phase: .changed)
        tester.sendMouseEvent(at: Point(10, 180), button: .none, phase: .changed)

        let updatedButton = try #require(buttonNodes(in: tester.containerView.viewTree.rootNode).first)
        #expect(updatedButton.environment.buttonStyle is NavigationBarButtonStyle)
    }

    @Test
    func buttonHoverInvalidationMarksContainerForRedraw() throws {
        let tester = ViewTester {
            Button(action: {}) {
                Text("Hover")
                    .frame(width: 100, height: 44)
            }
        }
        .setSize(Size(width: 200, height: 100))
        .performLayout()

        _ = tester.containerView.consumeNeedsDisplay()
        #expect(!tester.containerView.needsDisplay)

        tester.sendMouseEvent(at: Point(100, 50), button: .none, phase: .changed)

        #expect(tester.containerView.needsDisplay)
    }
}

private final class ButtonStyleStateRecorder: @unchecked Sendable {
    var states: [Button.State] = []
}

private struct RecordingButtonStyle: ButtonStyle {
    let recorder: ButtonStyleStateRecorder

    func makeBody(configuration: Configuration) -> some View {
        recorder.states.append(configuration.state)
        return configuration.label
    }
}

@MainActor
private func buttonNodes(in node: ViewNode) -> [ButtonViewNode] {
    var result: [ButtonViewNode] = []

    if let button = node as? ButtonViewNode {
        result.append(button)
    }

    if let root = node as? ViewRootNode {
        result += buttonNodes(in: root.contentNode)
    } else if let modifier = node as? ViewModifierNode {
        result += buttonNodes(in: modifier.contentNode)
    } else if let container = node as? ViewContainerNode {
        for child in container.nodes {
            result += buttonNodes(in: child)
        }
    } else {
        for child in reflectedButtonChildNodes(of: node) {
            result += buttonNodes(in: child)
        }
    }

    return result
}

@MainActor
private func reflectedButtonChildNodes(of node: ViewNode) -> [ViewNode] {
    Mirror(reflecting: node).children.flatMap { child -> [ViewNode] in
        if let node = child.value as? ViewNode {
            return [node]
        }
        if let node = child.value as? ViewNode? {
            return node.map { [$0] } ?? []
        }
        return []
    }
}
