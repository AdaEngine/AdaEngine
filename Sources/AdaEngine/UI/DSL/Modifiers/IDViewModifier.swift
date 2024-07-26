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

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        let node = IDViewNodeModifier(contentNode: inputs.makeNode(from: content), content: content)
        node.identifier = id
        return node
    }
}
