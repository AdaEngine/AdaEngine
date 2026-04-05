//
//  AnimationTests.swift
//
//
//  Created by Codex on 04.04.2026.
//

import Testing
@testable import AdaPlatform
@testable import AdaUI
import AdaUtils
import Math

@MainActor
struct AnimationTests {

    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func opacityAnimationProgressesAndCompletes() {
        let state = BindingBox(false)
        let tester = ViewTester(rootView: AnimatedOpacityView(isDimmed: state.binding))
            .setSize(Size(width: 200, height: 200))
            .performLayout()

        guard let node = tester.findNodeByAccessibilityIdentifier("opacity") as? OpacityViewNodeModifier else {
            Issue.record("Failed to locate opacity node.")
            return
        }

        #expect(abs(node.opacity - 1) < 0.001)

        state.value = true
        tester.invalidateContent()

        #expect(abs(node.opacity - 1) < 0.001)

        tester.advanceFrame(deltaTime: 0.5)
        #expect(abs(node.opacity - 0.625) < 0.01)

        tester.advanceFrame(deltaTime: 0.5)
        #expect(abs(node.opacity - 0.25) < 0.001)
    }

    @Test
    func scaleAndRotationAnimateThroughTransformPresentationValue() {
        let scaleState = BindingBox(false)
        let scaleTester = ViewTester(rootView: AnimatedScaleView(isScaled: scaleState.binding))
            .setSize(Size(width: 200, height: 200))
            .performLayout()

        guard let scaleNode = scaleTester.findNodeByAccessibilityIdentifier("scale") as? TransformEffectViewNode<Vector2> else {
            Issue.record("Failed to locate scale transform node.")
            return
        }

        scaleState.value = true
        scaleTester.invalidateContent()
        scaleTester.advanceFrame(deltaTime: 0.5)
        #expect(abs(scaleNode.value.x - 1.5) < 0.01)
        #expect(abs(scaleNode.value.y - 1.5) < 0.01)

        let rotationState = BindingBox(false)
        let rotationTester = ViewTester(rootView: AnimatedRotationView(isRotated: rotationState.binding))
            .setSize(Size(width: 200, height: 200))
            .performLayout()

        guard let rotationNode = rotationTester.findNodeByAccessibilityIdentifier("rotation") as? TransformEffectViewNode<Float> else {
            Issue.record("Failed to locate rotation transform node.")
            return
        }

        rotationState.value = true
        rotationTester.invalidateContent()
        rotationTester.advanceFrame(deltaTime: 0.5)
        #expect(abs(rotationNode.value - Angle.degrees(45).radians) < 0.01)
    }

    @Test
    func animationRetargetsFromCurrentPresentationValue() {
        let state = BindingBox(false)
        let tester = ViewTester(rootView: AnimatedOffsetCard(isShifted: state.binding))
            .setSize(Size(width: 260, height: 120))
            .performLayout()

        guard let node = tester.findNodeByAccessibilityIdentifier("offset-card") else {
            Issue.record("Failed to locate animated offset node.")
            return
        }

        let initialX = node.absoluteFrame().origin.x

        state.value = true
        tester.invalidateContent()
        tester.advanceFrame(deltaTime: 0.4)
        let halfwayX = node.absoluteFrame().origin.x
        #expect(abs((halfwayX - initialX) - 40) < 0.01)

        state.value = false
        tester.invalidateContent()
        tester.advanceFrame(deltaTime: 0.2)
        let retargetedX = node.absoluteFrame().origin.x
        #expect(retargetedX < halfwayX)
        #expect(retargetedX > initialX)

        tester.advanceFrame(deltaTime: 0.8)
        #expect(abs(node.absoluteFrame().origin.x - initialX) < 0.001)
    }

    @Test
    func frameSizeAnimationRelayoutsSubtree() {
        let state = BindingBox(false)
        let tester = ViewTester(rootView: AnimatedFrameContainer(isExpanded: state.binding))
            .setSize(Size(width: 240, height: 120))
            .performLayout()

        guard
            let frameNode = tester.findNodeByAccessibilityIdentifier("frame-container"),
            let contentNode = tester.findNodeByAccessibilityIdentifier("frame-content")
        else {
            Issue.record("Failed to locate frame animation nodes.")
            return
        }

        state.value = true
        tester.invalidateContent()
        tester.advanceFrame(deltaTime: 0.5)

        #expect(abs(frameNode.absoluteFrame().width - 80) < 0.01)
        #expect(abs(contentNode.absoluteFrame().width - 80) < 0.01)

        tester.advanceFrame(deltaTime: 0.5)
        #expect(abs(frameNode.absoluteFrame().width - 120) < 0.01)
        #expect(abs(contentNode.absoluteFrame().width - 120) < 0.01)
    }

    @Test
    func hstackReflowAnimatesRetainedSiblingPlacement() {
        let state = BindingBox(false)
        let tester = ViewTester(rootView: AnimatedReflowView(isExpanded: state.binding))
            .setSize(Size(width: 260, height: 120))
            .performLayout()

        guard let siblingNode = tester.findNodeByAccessibilityIdentifier("reflow-sibling") else {
            Issue.record("Failed to locate reflow sibling.")
            return
        }

        let initialX = siblingNode.absoluteFrame().origin.x

        state.value = true
        tester.invalidateContent()

        #expect(abs(siblingNode.absoluteFrame().origin.x - initialX) < 0.01)

        tester.advanceFrame(deltaTime: 0.5)
        #expect(abs((siblingNode.absoluteFrame().origin.x - initialX) - 40) < 0.01)

        tester.advanceFrame(deltaTime: 0.5)
        #expect(abs((siblingNode.absoluteFrame().origin.x - initialX) - 80) < 0.01)
    }

    @Test
    func hitTestingUsesPresentationGeometryDuringAnimation() {
        let state = BindingBox(false)
        let tester = ViewTester(rootView: AnimatedButtonOffsetView(isShifted: state.binding))
            .setSize(Size(width: 260, height: 120))
            .performLayout()

        guard let buttonNode = tester.findNodeByAccessibilityIdentifier("moving-button") else {
            Issue.record("Failed to locate moving button.")
            return
        }

        let originalCenter = Point(x: buttonNode.absoluteFrame().midX, y: buttonNode.absoluteFrame().midY)

        state.value = true
        tester.invalidateContent()
        tester.advanceFrame(deltaTime: 0.5)

        let presentedFrame = buttonNode.absoluteFrame()
        let presentedCenter = Point(x: presentedFrame.midX, y: presentedFrame.midY)

        #expect(tester.click(at: originalCenter) == nil)
        #expect(tester.click(at: presentedCenter)?.id == buttonNode.id)
    }

    @Test
    func disableAnimationSnapsImmediately() {
        let state = BindingBox(false)
        let tester = ViewTester(rootView: DisabledAnimationOffsetView(isShifted: state.binding))
            .setSize(Size(width: 260, height: 120))
            .performLayout()

        guard let node = tester.findNodeByAccessibilityIdentifier("disabled-offset") else {
            Issue.record("Failed to locate disabled animation node.")
            return
        }

        let initialX = node.absoluteFrame().origin.x

        state.value = true
        tester.invalidateContent()

        #expect(abs((node.absoluteFrame().origin.x - initialX) - 100) < 0.001)

        tester.advanceFrame(deltaTime: 0.5)
        #expect(abs((node.absoluteFrame().origin.x - initialX) - 100) < 0.001)
    }

    @Test
    func insertionAndRemovalStillSnapWithoutTransitions() {
        let state = BindingBox(false)
        let tester = ViewTester(rootView: ConditionalInsertionView(isPresented: state.binding))
            .setSize(Size(width: 240, height: 120))
            .performLayout()

        #expect(tester.findNodeByAccessibilityIdentifier("inserted-card") == nil)

        state.value = true
        tester.invalidateContent()

        guard let insertedNode = tester.findNodeByAccessibilityIdentifier("inserted-card") else {
            Issue.record("Inserted node should appear immediately.")
            return
        }

        #expect(abs(insertedNode.absoluteFrame().origin.x) < 0.001)

        state.value = false
        tester.invalidateContent()
        #expect(tester.findNodeByAccessibilityIdentifier("inserted-card") == nil)
    }
}

@MainActor
private final class BindingBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }

    var binding: Binding<Value> {
        Binding(
            get: { self.value },
            set: { self.value = $0 }
        )
    }
}

private struct AnimatedOpacityView: View {
    let isDimmed: Binding<Bool>

    var body: some View {
        Color.red
            .frame(width: 40, height: 40)
            .opacity(isDimmed.wrappedValue ? 0.25 : 1)
            .accessibilityIdentifier("opacity")
            .animation(Animation.linear(duration: 1), value: isDimmed.wrappedValue)
    }
}

private struct AnimatedScaleView: View {
    let isScaled: Binding<Bool>

    var body: some View {
        Color.blue
            .frame(width: 40, height: 40)
            .scaleEffect(isScaled.wrappedValue ? Vector2(2, 2) : Vector2.one)
            .accessibilityIdentifier("scale")
            .animation(Animation.linear(duration: 1), value: isScaled.wrappedValue)
    }
}

private struct AnimatedRotationView: View {
    let isRotated: Binding<Bool>

    var body: some View {
        Color.green
            .frame(width: 40, height: 40)
            .rotationEffect(isRotated.wrappedValue ? Angle.degrees(90) : .zero)
            .accessibilityIdentifier("rotation")
            .animation(Animation.linear(duration: 1), value: isRotated.wrappedValue)
    }
}

private struct AnimatedOffsetCard: View {
    let isShifted: Binding<Bool>

    var body: some View {
        Color.orange
            .frame(width: 40, height: 40)
            .accessibilityIdentifier("offset-card")
            .offset(x: isShifted.wrappedValue ? 100 : 0)
            .animation(Animation.linear(duration: 1), value: isShifted.wrappedValue)
    }
}

private struct AnimatedFrameContainer: View {
    let isExpanded: Binding<Bool>

    var body: some View {
        Color.purple
            .accessibilityIdentifier("frame-content")
            .frame(width: isExpanded.wrappedValue ? 120 : 40, height: 40)
            .accessibilityIdentifier("frame-container")
            .animation(Animation.linear(duration: 1), value: isExpanded.wrappedValue)
    }
}

private struct AnimatedReflowView: View {
    let isExpanded: Binding<Bool>

    var body: some View {
        HStack(spacing: 0) {
            Color.red
                .frame(width: isExpanded.wrappedValue ? 120 : 40, height: 40)
                .accessibilityIdentifier("reflow-driver")

            Color.blue
                .frame(width: 40, height: 40)
                .accessibilityIdentifier("reflow-sibling")
        }
        .animation(Animation.linear(duration: 1), value: isExpanded.wrappedValue)
    }
}

private struct AnimatedButtonOffsetView: View {
    let isShifted: Binding<Bool>

    var body: some View {
        Button(action: { }) {
            Color.accentColor
                .frame(width: 40, height: 40)
        }
        .accessibilityIdentifier("moving-button")
        .offset(x: isShifted.wrappedValue ? 100 : 0)
        .animation(Animation.linear(duration: 1), value: isShifted.wrappedValue)
    }
}

private struct DisabledAnimationOffsetView: View {
    let isShifted: Binding<Bool>

    var body: some View {
        Color.red
            .frame(width: 40, height: 40)
            .accessibilityIdentifier("disabled-offset")
            .offset(x: isShifted.wrappedValue ? 100 : 0)
            .animation(Animation.linear(duration: 1), value: isShifted.wrappedValue)
            .disableAnimation()
    }
}

private struct ConditionalInsertionView: View {
    let isPresented: Binding<Bool>

    var body: some View {
        HStack(spacing: 0) {
            if isPresented.wrappedValue {
                Color.yellow
                    .frame(width: 40, height: 40)
                    .accessibilityIdentifier("inserted-card")
            }

            Color.gray
                .frame(width: 40, height: 40)
                .accessibilityIdentifier("persistent-card")
        }
        .animation(Animation.linear(duration: 1), value: isPresented.wrappedValue)
    }
}
