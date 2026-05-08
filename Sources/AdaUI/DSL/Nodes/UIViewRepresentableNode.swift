//
//  UIViewRepresentableNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaUtils
import AdaInput
import Math

final class UIViewRepresentableNode<Representable: UIViewRepresentable>: ViewNode {

    private(set) var view: Representable.ViewType?
    private var coordinator: Representable.Coordinator
    let representable: Representable

    init<Content: View>(
        representable: Representable,
        content: Content
    ) {
        self.representable = representable
        self.coordinator = representable.makeCoordinator()
        super.init(content: content)
    }
    
    override func performLayout() {
        let context = Representable.Context(environment: self.environment, coordinator: coordinator)

        if view == nil {
            self.view = representable.makeUIView(in: context)
        }

        guard let view else {
            return
        }

        view.frame = self.frame
        view.safeAreaInsets = self.environment.safeAreaInsets
        view.userInterfaceIdiom = self.environment.userInterfaceIdiom
        view.colorScheme = self.environment.colorScheme
        self.representable.updateUIView(view, in: context)
        view.layoutSubviews()
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        if let view = self.view, view.hitTest(point, with: event) != nil {
            return self
        }

        return super.hitTest(point, with: event)
    }

    override func point(inside point: Point, with event: any InputEvent) -> Bool {
        if let view = self.view, view.point(inside: point, with: event) {
            return true
        }

        return super.point(inside: point, with: event)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        guard let view else {
            return proposal.replacingUnspecifiedDimensions()
        }

        let context = Representable.Context(environment: self.environment, coordinator: coordinator)
        return representable.sizeThatFits(proposal, view: view, context: context)
    }

    override func draw(with context: UIGraphicsContext) {
        view?.draw(with: context)
    }

    override func onReceiveEvent(_ event: any InputEvent) {
        view?.onEvent(event)
    }

    override func onKeyEvent(_ event: KeyEvent) {
        view?.onKeyEvent(event)
    }

    override func onTextInputEvent(_ event: TextInputEvent) {
        view?.onTextInputEvent(event)
    }

    override func onMouseEvent(_ event: MouseEvent) {
        view?.onMouseEvent(event)
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        view?.onTouchesEvent(touches)
    }

    override func update(_ deltaTime: TimeInterval) {
        guard let view else {
            return
        }

        view.updateHierarchy(deltaTime)
        if view.consumeNeedsDisplayInHierarchy() {
            owner?.containerView?.setNeedsDisplay(in: absoluteFrame())
        }
    }
}
