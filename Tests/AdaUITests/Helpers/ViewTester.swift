//
//  ViewTester.swift
//  AdaEngineTests
//
//  Created by vladislav.prusakov on 09.08.2024.
//

import Math
@testable import AdaUI
@testable import AdaPlatform
import AdaInput

/// Object that test view
@MainActor
class ViewTester<Content: View> {

    let containerView: UIContainerView<Content>
    var size: Size = .zero

    init(rootView: Content) {
        self.containerView = UIContainerView(rootView: rootView)
        self.containerView.frame.size = Size(width: 800, height: 600)
        self.containerView.layoutSubviews()
    }

    convenience init(@ViewBuilder rootView: () -> Content) {
        self.init(rootView: rootView())
    }

    @discardableResult
    func setSize(_ size: Size) -> Self {
        self.size = size
        self.containerView.frame.size = size
        return self
    }

    @discardableResult
    func performLayout() -> Self {
        self.containerView.layoutSubviews()
        return self
    }

    @discardableResult
    func invalidateContent() -> Self {
        self.containerView.viewTree.rootNode.invalidateContent()
        return self
    }

    func findNodeById<H: Hashable>(_ id: H) -> ViewNode? {
        return self.containerView.viewTree.rootNode.findNodeById(id)
    }

    func findNodeByAccessibilityIdentifier(_ id: String) -> ViewNode? {
        return self.containerView.viewTree.rootNode.findNodyByAccessibilityIdentifier(id)
    }

    // MARK: Interaction

    func click(at point: Point, phase: MouseEvent.Phase = .began) -> ViewNode? {
        let event = MouseEvent(
            window: .empty,
            button: .left,
            scrollDelta: .zero,
            mousePosition: point,
            phase: phase,
            modifierKeys: [],
            time: 0
        )

        return self.hitTest(point, event: event)
    }

    func hitTest(_ point: Point, event: any InputEvent) -> ViewNode? {
        self.containerView.viewTree.rootNode.hitTest(point, with: event)
    }

    // MARK: Simulations

    @discardableResult
    func simulateRenderOneFrame() -> Self {
        let context = UIGraphicsContext(window: UIWindow())
        self.containerView.draw(in: Rect(origin: .zero, size: self.size), with: context)
        return self
    }
}
