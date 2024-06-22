//
//  WidgetModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@MainActor
public protocol WidgetModifier {
    associatedtype Body: Widget
    typealias Content = AnyWidget

    @WidgetBuilder
    func body(content: Self.Content) -> Body
}

extension WidgetModifier {

    /// Returns a new modifier that is the result of concatenating
    /// `self` with `modifier`.
    @inlinable public func concat<T>(_ modifier: T) -> ModifiedContent<Self, T> {
        ModifiedContent(content: self, modifier: modifier)
    }
}

public extension Widget {
    func modifier<T>(_ modifier: T) -> ModifiedContent<Self, T> {
        return ModifiedContent(content: self, modifier: modifier)
    }
}

public struct ModifiedContent<Content, Modifier> {
    
    public var content: Content
    
    public var modifier: Modifier
    
    @inlinable public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }
}

extension ModifiedContent : Widget where Modifier: WidgetModifier, Content : Widget {

    @MainActor public var body: Modifier.Body {
        self.modifier.body(content: AnyWidget(self.content))
    }
    
}

//extension ModifiedWidget : WidgetModifier where Content : WidgetModifier, Modifier : WidgetModifier {
//    public func body(content: Content) -> Never {
//        fatalError()
//    }
//    
//    public typealias Body = Never
//}

public struct AnyWidget: Widget, WidgetNodeBuilder {

    let content: any Widget

    public init<T: Widget>(_ widget: T) {
        self.content = widget
    }

    public init(_ widget: any Widget) {
        self.content = widget
    }

    public var body: Never {
        fatalError()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        if let builder = WidgetNodeBuilderFinder.findBuilder(in: content) {
            return builder.makeWidgetNode(context: context)
        } else {
            return WidgetNode(content: content)
        }
    }
}
