//
//  WidgetBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@resultBuilder
@MainActor public enum WidgetBuilder {
    
    public static func buildBlock<Content>(_ content: Content) -> Content where Content : Widget {
        return content
    }
    
    public static func buildBlock<each Content>(_ content: repeat each Content) -> WidgetTuple<(repeat each Content)> where repeat each Content : Widget {
        return WidgetTuple(value: (repeat each content))
    }
}
