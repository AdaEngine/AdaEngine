//
//  ViewModifierNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.06.2024.
//

import AdaApp
import AdaInput
import AdaUtils
import Math

class ViewModifierNode: ViewNode {

    var contentNode: ViewNode

    init<Content: View>(contentNode: ViewNode, content: Content) {
        self.contentNode = contentNode
        super.init(content: content)
        self.contentNode.parent = self
    }

    override func update(from newNode: ViewNode) {
        guard let otherNode = newNode as? Self else {
            return
        }

        super.update(from: otherNode)
        self.contentNode.update(from: otherNode.contentNode)
    }

    override func performLayout() {
        let proposal = ProposedViewSize(self.frame.size)
        // Child layout must use local coordinates of the modifier node.
        // Using frame.midX/midY leaks parent origin into child placement and
        // accumulates offsets through modifier chains.
        let origin = Point(x: self.frame.width * 0.5, y: self.frame.height * 0.5)

        self.contentNode.place(
            in: origin,
            anchor: .center,
            proposal: proposal
        )
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        return contentNode.findNodeById(id)
    }

    override func findNodyByAccessibilityIdentifier(_ identifier: String) -> ViewNode? {
        if let node = super.findNodyByAccessibilityIdentifier(identifier) {
            return node
        }

        return contentNode.findNodyByAccessibilityIdentifier(identifier)
    }

    override func invalidateContent() {
        contentNode.invalidateContent()
        self.invalidateNearestLayer()
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
       contentNode.buildMenu(with: builder)
    }

    override func update(_ deltaTime: TimeInterval) {
        contentNode.update(deltaTime)
    }

    override func updateLayoutProperties(_ props: LayoutProperties) {
        contentNode.updateLayoutProperties(props)
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        contentNode.updateEnvironment(environment)
        super.updateEnvironment(environment)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        contentNode.draw(with: context)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        contentNode.sizeThatFits(proposal)
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else {
            return nil
        }

        let newPoint = contentNode.convert(point, from: self)
        return contentNode.hitTest(newPoint, with: event)
    }

    override func updateViewOwner(_ owner: ViewOwner) {
        super.updateViewOwner(owner)
        contentNode.updateViewOwner(owner)
    }

    override func point(inside point: Point, with event: any InputEvent) -> Bool {
        if super.point(inside: point, with: event) {
            return true
        }

        let newPoint = contentNode.convert(point, from: self)
        return contentNode.point(inside: newPoint, with: event)
    }

    override func onMouseEvent(_ event: MouseEvent) {
        contentNode.onMouseEvent(event)
    }

    override func onReceiveEvent(_ event: any InputEvent) {
        contentNode.onReceiveEvent(event)
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        contentNode.onTouchesEvent(touches)
    }

    override func debugDescription(hierarchy: Int = 0, identation: Int = 2) -> String {
        let identationStr = String(repeating: " ", count: hierarchy * identation)
        let value = super.debugDescription(hierarchy: hierarchy, identation: identation)
        return """
        \(identationStr)-\(value)
        \(identationStr)\(identationStr) - contentNode:
        \(identationStr)\(identationStr) - \(contentNode.debugDescription(hierarchy: hierarchy, identation: identation + 1))
        """
    }
}
