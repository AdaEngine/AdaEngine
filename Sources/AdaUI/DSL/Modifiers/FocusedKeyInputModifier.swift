import AdaInput
import Math

private final class FocusedKeyInputNode: ViewModifierNode {
    var handler: @MainActor (KeyEvent) -> Void

    init(contentNode: ViewNode, content: some View, handler: @escaping @MainActor (KeyEvent) -> Void) {
        self.handler = handler
        super.init(contentNode: contentNode, content: content)
    }

    override var canBecomeFocused: Bool { environment.isEnabled }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard environment.isEnabled, self.point(inside: point, with: event) else {
            return nil
        }
        return super.hitTest(point, with: event) ?? self
    }

    override func update(from newNode: ViewNode) {
        guard let other = newNode as? FocusedKeyInputNode else {
            return
        }
        handler = other.handler
        super.update(from: other)
    }

    override func onKeyEvent(_ event: KeyEvent) { if environment.isEnabled { handler(event) } }
}

private struct FocusedKeyInputModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never
    let content: Content
    let handler: @MainActor (KeyEvent) -> Void

    func buildViewNode(in context: BuildContext) -> ViewNode { FocusedKeyInputNode(contentNode: context.makeNode(from: content), content: content, handler: handler) }
}

extension View {
    /// Makes this surface focusable and receives keys only while it owns keyboard focus.
    /// Unlike global shortcuts, this does not intercept typing in sibling text controls.
    public func onFocusedKeyEvent(_ handler: @escaping @MainActor (KeyEvent) -> Void) -> some View { modifier(FocusedKeyInputModifier(content: self, handler: handler)) }
}
