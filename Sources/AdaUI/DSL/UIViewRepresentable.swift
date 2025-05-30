//
//  UIViewRepresentable.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.06.2024.
//

import AdaUtils
import Math

public struct UIViewRepresentableContext<View: UIViewRepresentable> {
    public internal(set) var environment: EnvironmentValues
    public internal(set) var coordinator: View.Coordinator
}

@MainActor
public protocol UIViewRepresentable: View {

    associatedtype ViewType: UIView
    associatedtype Coordinator = Void

    typealias Context = UIViewRepresentableContext<Self>

    func makeUIView(in context: Context) -> ViewType

    func updateUIView(_ view: ViewType, in context: Context)

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        view: ViewType,
        context: Context
    ) -> Size

    func makeCoordinator() -> Coordinator
}

public extension UIViewRepresentable where Coordinator == Void {
    func makeCoordinator() {
        return
    }
}

public extension UIViewRepresentable {
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        view: ViewType,
        context: Context
    ) -> Size {
        return view.sizeThatFits(proposal)
    }
}

extension UIViewRepresentable {
    public var body: some View {
        UIViewRepresentableView(repsentable: self)
    }
}

struct UIViewRepresentableView<Representable: UIViewRepresentable>: View, ViewNodeBuilder {
    typealias Body = Never
    let repsentable: Representable

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let node = UIViewRepresentableNode(
            representable: repsentable,
            content: self
        )

        node.updateEnvironment(context.environment)

        return node
    }
}
