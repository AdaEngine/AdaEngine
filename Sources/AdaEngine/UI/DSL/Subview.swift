//
//  Subview.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 15.07.2024.
//

@MainActor
@preconcurrency
public struct Subview: View {
    
    let view: AnyView
    
    init<V: View>(_ view: V) {
        self.view = AnyView(view)
    }
    
    public var body: some View {
        self.view
    }
}
