//
//  WidgetTree.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Math

@MainActor
class WidgetTree<Content: Widget> {
    
    let rootView: Content
    private(set) var rootNode: WidgetRootNode

    init(rootView: Content) {
        self.rootView = rootView
        
        let inputs = _WidgetInputs(
            environment: WidgetEnvironmentValues()
        )
        
        let contentNode = Content._makeView(_WidgetGraphNode(value: rootView), inputs: inputs)
        self.rootNode = WidgetRootNode(contentNode: contentNode.node, content: rootView)
    }
    
    func renderGraph(renderContext: GUIRenderContext) {
        self.rootNode.draw(with: renderContext)
    }
}

final class WidgetRootNode: WidgetNode {

    let contentNode: WidgetNode

    static let rootCoordinateSpace = NamedWidgetCoordinateSpace(UUID().uuidString)

    init<Root: Widget>(contentNode: WidgetNode, content: Root) {
        self.contentNode = contentNode
        super.init(content: content)
        
        self.contentNode.parent = self
        self.environment.coordinateSpaces.containers[Self.rootCoordinateSpace.name] = self
    }

    override func performLayout() {
        let proposal = ProposedViewSize(width: self.frame.width, height: self.frame.height)

        self.contentNode.place(
            in: Point(self.frame.midX, self.frame.midY),
            anchor: .center,
            proposal: proposal
        )

        self.contentNode._printDebugNode()
    }

    override func update(_ deltaTime: TimeInterval) {
        contentNode.update(deltaTime)
    }

    override func draw(with context: GUIRenderContext) {
        contentNode.draw(with: context)
    }

    override func hitTest(_ point: Point, with event: InputEvent) -> WidgetNode? {
        contentNode.hitTest(point, with: event)
    }

    override func point(inside point: Point, with event: InputEvent) -> Bool {
        contentNode.point(inside: point, with: event)
    }

    override func onMouseEvent(_ event: MouseEvent) {
        contentNode.onMouseEvent(event)
    }

    override func onReceiveEvent(_ event: InputEvent) {
        contentNode.onReceiveEvent(event)
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        contentNode.onTouchesEvent(touches)
    }
}
