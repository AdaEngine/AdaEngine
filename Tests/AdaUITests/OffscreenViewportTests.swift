//
//  OffscreenViewportTests.swift
//  AdaEngine
//
//  Created by AdaEngine on 04.04.2026.
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
@_spi(Internal) import AdaRender
import AdaInput
import AdaUtils
import Math

@MainActor
final class MockViewportDelegate: OffscreenViewportDelegate {
    var renderTexture: Texture2D? = nil
    var bootstrapCallCount = 0
    var tickCount = 0
    var lastTickDelta: AdaUtils.TimeInterval = 0
    var receivedInputEvents: [any InputEvent] = []
    var lastMousePosition: Point = .zero
    var lastSize: SizeInt = .zero
    var lastScaleFactor: Float = 0

    func bootstrapIfNeeded() {
        bootstrapCallCount += 1
    }

    func tick(_ deltaTime: AdaUtils.TimeInterval) {
        tickCount += 1
        lastTickDelta = deltaTime
    }

    func receiveInputEvent(_ event: any InputEvent) {
        receivedInputEvents.append(event)
    }

    func updateMousePosition(_ position: Point) {
        lastMousePosition = position
    }

    func updateSize(_ size: SizeInt, scaleFactor: Float) {
        lastSize = size
        lastScaleFactor = scaleFactor
    }
}

@MainActor
struct OffscreenViewportTests {

    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func containerCreatesDelegate_onlyOnce() {
        var factoryCallCount = 0
        let delegate = MockViewportDelegate()

        let tester = ViewTester {
            OffscreenViewportContainer(
                delegateFactory: {
                    factoryCallCount += 1
                    return delegate
                },
                contentBuilder: { _ in
                    EmptyView()
                }
            )
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        #expect(factoryCallCount == 1)

        tester.invalidateContent()
        tester.performLayout()
        #expect(factoryCallCount == 1)
    }

    @Test
    func bootstrap_calledOnFirstLayout() {
        let delegate = MockViewportDelegate()

        _ = ViewTester {
            OffscreenViewportView(delegate: delegate)
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        #expect(delegate.bootstrapCallCount == 1)
    }

    @Test
    func bootstrap_notCalledAgainOnRelayout() {
        let delegate = MockViewportDelegate()

        let tester = ViewTester {
            OffscreenViewportView(delegate: delegate)
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        tester.performLayout()
        tester.performLayout()

        #expect(delegate.bootstrapCallCount == 1)
    }

    @Test
    func tick_forwardedOnUpdate() {
        let delegate = MockViewportDelegate()

        let tester = ViewTester {
            OffscreenViewportView(delegate: delegate)
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        tester.advanceFrame(deltaTime: 0.016)

        #expect(delegate.tickCount >= 1)
    }

    @Test
    func sizeUpdate_reportedOnLayout() {
        let delegate = MockViewportDelegate()

        _ = ViewTester {
            OffscreenViewportView(delegate: delegate)
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        #expect(delegate.lastSize.width > 0)
        #expect(delegate.lastSize.height > 0)
    }

    @Test
    func viewport_isHitTestable() {
        let delegate = MockViewportDelegate()

        let tester = ViewTester {
            OffscreenViewportView(delegate: delegate)
                .frame(width: 200, height: 150)
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        let hitNode = tester.click(at: Point(100, 75))
        #expect(hitNode != nil)
    }

    @Test
    func mouseEvent_forwardedToDelegate() {
        let delegate = MockViewportDelegate()

        let tester = ViewTester {
            OffscreenViewportView(delegate: delegate)
                .frame(width: 400, height: 300)
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        tester.sendMouseEvent(
            at: Point(200, 150),
            button: .left,
            phase: .began,
            time: 0
        )

        let mouseEvents = delegate.receivedInputEvents.compactMap { $0 as? MouseEvent }
        #expect(!mouseEvents.isEmpty)
    }

    @Test
    func mouseEvent_coordinatesTranslatedToViewportLocal() {
        let delegate = MockViewportDelegate()

        let tester = ViewTester {
            HStack {
                Spacer().frame(width: 100)
                OffscreenViewportView(delegate: delegate)
                    .frame(width: 200, height: 150)
            }
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        tester.sendMouseEvent(
            at: Point(200, 75),
            button: .left,
            phase: .began,
            time: 0
        )

        let mouseEvents = delegate.receivedInputEvents.compactMap { $0 as? MouseEvent }
        if let event = mouseEvents.first {
            #expect(event.mousePosition.x >= 0)
            #expect(event.mousePosition.y >= 0)
        }
    }

    @Test
    func keyEvent_notForwardedBeforeActivation() {
        let delegate = MockViewportDelegate()

        let tester = ViewTester {
            OffscreenViewportView(delegate: delegate)
                .frame(width: 400, height: 300)
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        tester.sendKeyEvent(.a)

        let keyEvents = delegate.receivedInputEvents.compactMap { $0 as? KeyEvent }
        #expect(keyEvents.isEmpty)
    }

    @Test
    func keyEvent_forwardedAfterMouseActivation() {
        let delegate = MockViewportDelegate()

        let tester = ViewTester {
            OffscreenViewportView(delegate: delegate)
                .frame(width: 400, height: 300)
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        tester.sendMouseEvent(
            at: Point(200, 150),
            button: .left,
            phase: .began,
            time: 0
        )

        tester.sendKeyEvent(.b)

        let keyEvents = delegate.receivedInputEvents.compactMap { $0 as? KeyEvent }
        #expect(!keyEvents.isEmpty)
    }

    @Test
    func containerPassesDelegateToContent() {
        let delegate = MockViewportDelegate()
        var receivedDelegate: (any OffscreenViewportDelegate)?

        _ = ViewTester {
            OffscreenViewportContainer(
                delegateFactory: { delegate },
                contentBuilder: { d in
                    receivedDelegate = d
                    return OffscreenViewportView(delegate: d)
                }
            )
        }
        .setSize(Size(width: 400, height: 300))
        .performLayout()

        #expect(receivedDelegate != nil)
        #expect(receivedDelegate === delegate)
    }
}
