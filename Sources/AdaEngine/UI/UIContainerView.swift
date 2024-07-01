//
//  UIContainerView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Math

public class UIContainerView<Content: View>: UIView {

    private let viewTree: ViewTree<Content>

    public init(rootView: Content) {
        self.viewTree = ViewTree(rootView: rootView)
        super.init()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        viewTree.rootNode.place(in: .zero, anchor: .zero, proposal: ProposedViewSize(self.frame.size))
    }
    
    public required init(frame: Rect) {
        fatalError("init(frame:) has not been implemented")
    }

    public override func hitTest(_ point: Point, with event: InputEvent) -> UIView? {
        if self.viewTree.rootNode.hitTest(point, with: event) != nil {
            return self
        }

        return self
    }

    public override func onMouseEvent(_ event: MouseEvent) {
        if let viewNode = self.viewTree.rootNode.hitTest(event.mousePosition, with: event) {
            viewNode.onMouseEvent(event)
        }
    }

    public override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        if touches.isEmpty {
            return
        }

        let firstTouch = touches.first!
        if let viewNode = self.viewTree.rootNode.hitTest(firstTouch.location, with: firstTouch) {
            viewNode.onTouchesEvent(touches)
        }
    }

    public override func point(inside point: Point, with event: InputEvent) -> Bool {
        return self.viewTree.rootNode.point(inside: point, with: event)
    }
    
    override public func draw(in rect: Rect, with context: GUIRenderContext) {
        viewTree.renderGraph(renderContext: context)
    }

    public override func update(_ deltaTime: TimeInterval) async {
        await super.update(deltaTime)

        self.viewTree.rootNode.update(deltaTime)
    }
}
