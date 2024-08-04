//
//  ViewModifierNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.06.2024.
//

import Math

class ViewModifierNode: ViewNode {

    var contentNode: ViewNode

    init<Content: View>(contentNode: ViewNode, content: Content) {
        self.contentNode = contentNode
        super.init(content: content)
        self.contentNode.parent = self
    }

    override func update(from newNode: ViewNode) {
        guard let otherNode = newNode as? ViewModifierNode else {
            return
        }

        super.update(from: otherNode)
        self.contentNode.update(from: otherNode.contentNode)
    }

    override func performLayout() {
        let proposal = ProposedViewSize(self.frame.size)
        let origin = Point(x: self.frame.midX, y: self.frame.midY)

        self.contentNode.place(
            in: origin,
            anchor: .center,
            proposal: proposal
        )
    }

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        return contentNode.findNodeById(id)
    }

    override func invalidateContent() {
        contentNode.invalidateContent()
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
       contentNode.buildMenu(with: builder)
    }

    override func update(_ deltaTime: TimeInterval) async {
        await contentNode.update(deltaTime)
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
        contentNode.draw(with: context)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        contentNode.sizeThatFits(proposal)
    }

    override func hitTest(_ point: Point, with event: InputEvent) -> ViewNode? {
        if super.point(inside: point, with: event) {
            let newPoint = contentNode.convert(point, from: self)
            return contentNode.hitTest(newPoint, with: event)
        }

        return nil
    }

    override func updateViewOwner(_ owner: ViewOwner) {
        super.updateViewOwner(owner)
        contentNode.updateViewOwner(owner)
    }

    override func point(inside point: Point, with event: InputEvent) -> Bool {
        if super.point(inside: point, with: event) {
            let newPoint = contentNode.convert(point, from: self)
            return contentNode.point(inside: newPoint, with: event)
        }
        
        return false
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
