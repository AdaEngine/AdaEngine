//
//  UIViewWidgetNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

final class UIViewWidgetNode: WidgetNode {
    
    private let makeUIView: () -> UIView
    private let updateUIView: (UIView) -> Void
    
    private var view: UIView?
    
    init(
        makeUIView: @escaping () -> UIView,
        updateUIView: @escaping (UIView) -> Void,
        content: any Widget
    ) {
        self.makeUIView = makeUIView
        self.updateUIView = updateUIView
        
        super.init(content: content)
    }
    
    override func performLayout() {
        precondition(self.view != nil)
        self.updateUIView(self.view!)
    }
    
    override func invalidateContent() {
        self.view = self.makeUIView()
        
        super.invalidateContent()
    }

    override func hitTest(_ point: Point, with event: InputEvent) -> WidgetNode? {
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

    override func sizeThatFits(_ proposal: ProposedViewSize, usedByParent: Bool = false) -> Size {
        guard let view else {
            return .zero
        }

        if usedByParent {
            return view.sizeThatFits(proposal)
        } else {
            return super.sizeThatFits(proposal)
        }
    }

    override func draw(with context: GUIRenderContext) {
        view?.draw(with: context)
    }
}
