@_spi(Internal) @testable import AdaInput
@testable import AdaUI
import Math
import Testing

@MainActor
@Suite("Window hover input batching", .serialized)
struct EditorWindowHoverInputTests {
    @Test("Hover batching preserves raw events, picking blocks and input boundaries")
    func preservesInputBoundaries() {
        let manager = HoverInputWindowManager()
        let frame = Rect(x: 0, y: 0, width: 200, height: 200)
        let window = UIWindow(frame: frame, configuration: .init(frame: frame), windowManager: manager)
        let receiver = HoverInputReceiver(frame: frame)
        window.addSubview(receiver)
        window.layoutSubviews()
        var input = Input(gameControllerEngine: nil)
        let events = [
            mouse(window, time: 0), mouse(window, time: 1),
            mouse(window, time: 2, phase: .began, button: .left),
            mouse(window, time: 3, button: .left), mouse(window, time: 4, button: .left),
            mouse(window, time: 5, phase: .ended, button: .left),
            mouse(window, time: 6), mouse(window, time: 7),
            mouse(window, time: 8, button: .scrollWheel),
            mouse(window, time: 9), mouse(window, time: 10, modifiers: .shift),
            mouse(window, time: 11, modifiers: .shift)
        ]
        events.forEach { input.receiveEvent($0) }
        input.flushPendingEvents()
        window.sendPendingInput(&input)
        #expect(receiver.times == [1, 2, 3, 4, 5, 7, 8, 9, 11])
        #expect(input.getInputEvents().map(\.id) == events.map(\.id))
        for event in events { #expect(input.isScenePickingBlocked(eventID: event.id)) }
    }

    @Test("Keyboard events and other windows separate hover batches")
    func keyboardAndWindowBoundaries() {
        let manager = HoverInputWindowManager()
        let frame = Rect(x: 0, y: 0, width: 200, height: 200)
        let first = UIWindow(frame: frame, configuration: .init(frame: frame), windowManager: manager)
        let second = UIWindow(frame: frame, configuration: .init(frame: frame), windowManager: manager)
        let receiver = HoverInputReceiver(frame: frame)
        let other = HoverInputReceiver(frame: frame)
        first.addSubview(receiver)
        second.addSubview(other)
        first.layoutSubviews()
        second.layoutSubviews()
        var input = Input(gameControllerEngine: nil)
        input.receiveEvent(mouse(first, time: 0))
        input.receiveEvent(KeyEvent(window: first.id, keyCode: .space, modifiers: [], status: .down, time: 1, isRepeated: false))
        input.receiveEvent(mouse(first, time: 2))
        input.receiveEvent(mouse(second, time: 3))
        input.receiveEvent(mouse(first, time: 4))
        input.flushPendingEvents()
        first.sendPendingInput(&input)
        second.sendPendingInput(&input)
        #expect(receiver.times == [0, 1, 2, 4])
        #expect(other.times == [3])
    }

    private func mouse(
        _ window: UIWindow, time: Float, phase: MouseEvent.Phase = .changed,
        button: MouseButton = .none, modifiers: KeyModifier = []
    ) -> MouseEvent {
        MouseEvent(window: window.id, button: button, scrollDelta: button == .scrollWheel ? [0, 1] : .zero,
                   mousePosition: [10, 10], phase: phase, modifierKeys: modifiers, time: time)
    }
}

@MainActor
private final class HoverInputReceiver: UIView {
    var times: [Float] = []
    override func onMouseEvent(_ event: MouseEvent) { times.append(event.time) }
    override func onKeyEvent(_ event: KeyEvent) { times.append(event.time) }
}

@MainActor
private final class HoverInputWindowManager: UIWindowManager {
    override func resizeWindow(_: UIWindow, size _: Size) {}
    override func getScreen(for _: UIWindow) -> Screen? { nil }
}
