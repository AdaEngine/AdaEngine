//
//  WidgetModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct _ModifiedContent<Content: WidgetModifier>: WidgetNodeBuilder {

    let builder: WidgetNodeBuilder

    func makeWidgetNode(context: Context) -> WidgetNode {
        return builder.makeWidgetNode(context: context)
    }
}

extension _ModifiedContent: Widget {
    public var body: Never { fatalError() }
}

@MainActor
public protocol WidgetModifier {
    associatedtype Body: Widget
    typealias Content = _ModifiedContent<Self>

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

public extension WidgetModifier where Body == Never {
    func body(content: Self.Content) -> Never {
        fatalError("We should call body when Body is Never type.")
    }
}

extension ModifiedContent: Widget, WidgetNodeBuilder where Modifier: WidgetModifier, Content: Widget {

    public var body: Never {
        fatalError()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        if let builder = (self.modifier as? WidgetNodeBuilder) {
            return builder.makeWidgetNode(context: context)
        }

        guard let contentBuilder = WidgetNodeBuilderUtils.findNodeBuilder(in: self.content) else {
            fatalError("Can't find builder in content")
        }

        let modifiedContent = modifier.body(content: _ModifiedContent(builder: contentBuilder))

        guard let builder = WidgetNodeBuilderUtils.findNodeBuilder(in: modifiedContent) else {
            fatalError("Can't find builder")
        }

        return builder.makeWidgetNode(context: context)
    }

}

//extension ModifiedWidget : WidgetModifier where Content : WidgetModifier, Modifier : WidgetModifier {
//    public func body(content: Content) -> Never {
//        fatalError()
//    }
//    
//    public typealias Body = Never
//}
