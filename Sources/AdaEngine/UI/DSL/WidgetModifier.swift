//
//  WidgetModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct WidgetModifierContent: Widget, WidgetModifier {
    
    public func body(content: Content) -> Never {
        fatalError()
    }
    
    public var body: Never {
        fatalError()
    }
}

@MainActor
public protocol WidgetModifier {
    associatedtype Body: Widget
    
    typealias Content = WidgetModifierContent
    
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

extension ModifiedContent : Widget where Content : Widget, Modifier : WidgetModifier {
    
    @MainActor public var body: Modifier.Body {
        self.modifier.body(content: self.content as! Modifier.Content)
    }
    
}

//extension ModifiedWidget : WidgetModifier where Content : WidgetModifier, Modifier : WidgetModifier {
//    public func body(content: Content) -> Never {
//        fatalError()
//    }
//    
//    public typealias Body = Never
//    
//    
//}
