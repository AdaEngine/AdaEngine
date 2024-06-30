//
//  ViewModifierNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.06.2024.
//

class ViewModifierNode: ViewNode {

    let contentNode: ViewNode

    init<Content: View>(contentNode: ViewNode, content: Content) {
        self.contentNode = contentNode
        super.init(content: content)
    }

    override func merge(_ otherNode: ViewNode) {
        guard let otherNode = otherNode as? ViewModifierNode else {
            return
        }

        super.merge(otherNode)
        self.contentNode.merge(otherNode.contentNode)
    }

    override func performLayout() {
        let proposal = ProposedViewSize(self.frame.size)
        self.contentNode.place(
            in: .zero,
            anchor: .zero,
            proposal: proposal
        )
    }

    override func invalidateContent() {
        contentNode.invalidateContent()
    }

    override func update(_ deltaTime: TimeInterval) {
        contentNode.update(deltaTime)
    }

    override func updateLayoutProperties(_ props: LayoutProperties) {
        contentNode.updateLayoutProperties(props)
    }

    override func updateEnvironment(_ environment: ViewEnvironmentValues) {
        contentNode.updateEnvironment(environment)
        super.updateEnvironment(environment)
    }

    override func draw(with context: GUIRenderContext) {
        contentNode.draw(with: context)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        contentNode.sizeThatFits(proposal)
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
