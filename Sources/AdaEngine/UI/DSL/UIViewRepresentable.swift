//
//  UIViewRepresentable.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.06.2024.
//

public struct UIViewRepresentableContext<View: UIViewRepresentable> {
    public internal(set) var environment: WidgetEnvironmentValues
    public internal(set) var coordinator: View.Coordinator
}

public protocol UIViewRepresentable: Widget {
    
    associatedtype ViewType: UIView
    associatedtype Coordinator = Void
    
    typealias Context = UIViewRepresentableContext<Self>
    
    func makeUIView(in context: Context) -> ViewType
    
    func updateUIView(_ view: ViewType, in context: Context)
    
    func makeCoordinator() -> Coordinator
}

public extension UIViewRepresentable where Coordinator == Void {
    func makeCoordinator() {
        return
    }
}

extension UIViewRepresentable {
    public var body: some Widget {
        UIViewRepresentableWidget(repsentable: self)
    }
}

struct UIViewRepresentableWidget<View: UIViewRepresentable>: Widget, WidgetNodeBuilder {
    typealias Body = Never
    let repsentable: View
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        let node = UIViewWidgetNode(
            representable: repsentable,
            content: self
        )
        
        node.updateEnvironment(context.environment)

        return node
    }
}
