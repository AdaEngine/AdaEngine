//
//  UIWidgetView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Math

public class UIWidgetView<Content: Widget>: UIView {
    
    private let widgetTree: WidgetTree<Content>
    
    public init(rootView: Content) {
        self.widgetTree = WidgetTree(rootView: rootView)
        
        super.init()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        widgetTree.rootNode.place(in: .zero, anchor: .zero, proposal: ProposedViewSize(self.frame.size))
    }
    
    public required init(frame: Rect) {
        fatalError("init(frame:) has not been implemented")
    }

    private var lastHittestedNode: WidgetNode?

    public override func hitTest(_ point: Point, with event: InputEvent) -> UIView? {
        if let widgetNode = self.widgetTree.rootNode.hitTest(point, with: event) {
            self.lastHittestedNode = widgetNode
            return self
        }

        return self
    }

    public override func onMouseEvent(_ event: MouseEvent) {
        if let lastHittestedNode {
            lastHittestedNode.onMouseEvent(event)
        }
    }

    public override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        if let lastHittestedNode {
            lastHittestedNode.onTouchesEvent(touches)
        }
    }

    public override func point(inside point: Point, with event: InputEvent) -> Bool {
        return self.widgetTree.rootNode.point(inside: point, with: event)
    }
    
    override public func draw(in rect: Rect, with context: GUIRenderContext) {
        widgetTree.renderGraph(renderContext: context)
    }

    public override func update(_ deltaTime: TimeInterval) async {
        await super.update(deltaTime)

        self.widgetTree.rootNode.update(deltaTime)
    }
}
