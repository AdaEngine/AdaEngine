//
//  UIViewRepresentableNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

final class UIViewRepresentableNode<Representable: UIViewRepresentable>: ViewNode {

    private var view: Representable.ViewType?
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

        self.representable.updateUIView(view!, in: context)
    }

    override func hitTest(_ point: Point, with event: InputEvent) -> ViewNode? {
        if let view = self.view, view.hitTest(point, with: event) != nil {
            return self
        }

        return super.hitTest(point, with: event)
    }

    override func point(inside point: Point, with event: InputEvent) -> Bool {
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

    override func draw(with context: GUIRenderContext) {
        view?.draw(with: context)
    }
}
