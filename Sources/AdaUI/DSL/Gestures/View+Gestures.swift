//
//  View+Gestures.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

public extension View {

    func gesture<G: Gesture>(_ gesture: G) -> some View {
        self.modifier(GestureViewModifier(gesture: gesture, content: self))
    }

    @inlinable
    func onTap(count: Int = 1, perform: @escaping () -> Void) -> some View {
        onTapGesture(count: count, perform: perform)
    }
    
    @inlinable
    func onTapGesture(count: Int = 1, perform: @escaping () -> Void) -> some View {
        self.gesture(
            TapGesture(count: count)
                .onEnded(perform)
        )
    }
}
