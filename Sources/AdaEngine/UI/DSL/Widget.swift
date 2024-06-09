//
//  Widget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@MainActor
public protocol Widget {
    associatedtype Body: Widget
    
    @WidgetBuilder
    var body: Self.Body { get }
}
