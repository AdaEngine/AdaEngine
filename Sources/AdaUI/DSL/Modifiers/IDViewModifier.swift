//
//  IDViewModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.07.2024.
//

public extension View {
    /// Binds a view’s identity to the given proxy value.
    func id<H: Hashable>(_ identifier: H) -> some View {
        IDView(id: identifier, content: self)
    }
}

final class IDViewNodeModifier: ViewModifierNode {

    var identifier: AnyHashable?

    override func findNodeById(_ id: AnyHashable) -> ViewNode? {
        return id == self.identifier ? self : nil
    }
}

struct IDView<V: View>: View, ViewNodeBuilder {

    typealias Body = Never

    let id: AnyHashable
    let content: V

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let node = IDViewNodeModifier(contentNode: context.makeNode(from: content), content: content)
        node.identifier = id
        return node
    }
}

public extension View {
    /// Uses the string you specify to identify the view.
    func accessibilityIdentifier(_ identifier: String) -> some View {
        modifier(AccessibilityAttachmentModifier(identifier: identifier))
    }
}

/// A view modifier that adds accessibility properties to the view
struct AccessibilityAttachmentModifier: ViewModifier, _ViewOutputsViewModifier {
    let identifier: String

    func body(content: Content) -> some View {
        return content
    }

    static func _makeModifier(_ modifier: _ViewGraphNode<AccessibilityAttachmentModifier>, outputs: inout _ViewOutputs) {
        outputs.node.accessibilityIdentifier = modifier[\.identifier].value
    }
}
