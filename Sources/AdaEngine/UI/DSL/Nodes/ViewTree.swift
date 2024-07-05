//
//  ViewTree.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Math

@MainActor
class ViewTree<Content: View> {
    
    let rootView: Content
    private(set) var rootNode: ViewRootNode

    init(rootView: Content) {
        self.rootView = rootView
        
        let inputs = _ViewInputs(
            environment: ViewEnvironmentValues()
        )
        
        let contentNode = Content._makeView(_ViewGraphNode(value: rootView), inputs: inputs)
        self.rootNode = ViewRootNode(contentNode: contentNode.node, content: rootView)
    }
    
    func renderGraph(renderContext: inout GUIRenderContext) {
        self.rootNode.draw(with: &renderContext)
    }
}

final class ViewRootNode: ViewNode {

    let contentNode: ViewNode

    static let rootCoordinateSpace = NamedViewCoordinateSpace(UUID().uuidString)

    init<Root: View>(contentNode: ViewNode, content: Root) {
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
    }

    override func update(_ deltaTime: TimeInterval) {
        contentNode.update(deltaTime)
    }

    override func draw(with context: inout GUIRenderContext) {
        contentNode.draw(with: &context)
    }

    override func hitTest(_ point: Point, with event: InputEvent) -> ViewNode? {
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
