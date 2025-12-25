//
//  ViewTree.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaInput
import AdaUtils
import Foundation
import Math

@MainActor
final class ViewTree<Content: View> {

    let rootView: Content
    private(set) var rootNode: ViewRootNode

    init(rootView: Content) {
        self.rootView = rootView
        
        let inputs = _ViewInputs(
            parentNode: nil,
            environment: EnvironmentValues()
        )

        let contentNode = Content._makeView(_ViewGraphNode(value: rootView), inputs: inputs)
        self.rootNode = ViewRootNode(contentNode: contentNode.node, content: rootView)
    }

    func setViewOwner(_ owner: ViewOwner) {
        self.rootNode.updateViewOwner(owner)
    }

    func renderGraph(renderContext: UIGraphicsContext) {
        self.rootNode.draw(with: renderContext)
    }
}

/// The root node that holds user view.
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

    override func updateEnvironment(_ environment: EnvironmentValues) {
        contentNode.updateEnvironment(environment)
    }

    override func update(_ deltaTime: AdaUtils.TimeInterval) {
        contentNode.update(deltaTime)
    }
    
    override func draw(with context: UIGraphicsContext) {
        contentNode.draw(with: context)
        super.draw(with: context)
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        let newPoint = contentNode.convert(point, from: self)
        return contentNode.hitTest(newPoint, with: event)
    }

    override func point(inside point: Point, with event: any InputEvent) -> Bool {
        contentNode.point(inside: point, with: event)
    }

    override func onMouseEvent(_ event: MouseEvent) {
        contentNode.onMouseEvent(event)
    }

    override func updateViewOwner(_ owner: ViewOwner) {
        contentNode.updateViewOwner(owner)
    }

    override func onReceiveEvent(_ event: any InputEvent) {
        contentNode.onReceiveEvent(event)
    }

    override func findNodyByAccessibilityIdentifier(_ identifier: String) -> ViewNode? {
        self.contentNode.findNodyByAccessibilityIdentifier(identifier)
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        self.contentNode.findNodeById(id)
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
        contentNode.buildMenu(with: builder)
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        contentNode.onTouchesEvent(touches)
    }
}
