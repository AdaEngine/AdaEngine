//
//  UIViewRepresentable.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.06.2024.
//

public struct UIViewRepresentableContext<View: UIViewRepresentable> {
    public internal(set) var widgetContext: WidgetContextValues
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
    
    let repsentable: View
    
    var body: some Widget {
        fatalError()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        let coordinator = repsentable.makeCoordinator()
        
       return UIViewWidgetNode(makeUIView: {
           let context = UIViewRepresentableContext<View>(
                widgetContext: context.widgetContext,
                coordinator: coordinator
            )
            
            return repsentable.makeUIView(in: context)
       }, updateUIView: { view in
           let context = UIViewRepresentableContext<View>(
            widgetContext: context.widgetContext,
            coordinator: coordinator
           )
           repsentable.updateUIView(view as! View.ViewType, in: context)
       }, content: self
       )
    }
}
