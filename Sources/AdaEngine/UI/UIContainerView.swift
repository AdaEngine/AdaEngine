//
//  UIContainerView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Math

public class UIContainerView<Content: View>: UIView, ViewOwner {

    var containerView: UIView? {
        return self
    }

    let viewTree: ViewTree<Content>

    public init(rootView: Content) {
        self.viewTree = ViewTree(rootView: rootView)
        super.init()
        viewTree.setViewOwner(self)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        viewTree.rootNode.place(in: .zero, anchor: .zero, proposal: ProposedViewSize(self.frame.size))
    }

    public override func buildMenu(with builder: any UIMenuBuilder) {
        viewTree.rootNode.buildMenu(with: builder)
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

    private var lastOnMouseEventNode: ViewNode?
    public override func onMouseEvent(_ event: MouseEvent) {
        if let viewNode = self.viewTree.rootNode.hitTest(event.mousePosition, with: event) {
            viewNode.onMouseEvent(event)

            if lastOnMouseEventNode !== viewNode {
                lastOnMouseEventNode?.onMouseLeave()
                lastOnMouseEventNode = viewNode
            }
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
    
    override public func draw(in rect: Rect, with context: UIGraphicsContext) {
        viewTree.renderGraph(renderContext: context)
    }

    public override func update(_ deltaTime: TimeInterval) async {
        await super.update(deltaTime)
        await self.viewTree.rootNode.update(deltaTime)
    }
}
