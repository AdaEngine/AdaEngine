//
//  OverlayModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.07.2024.
//

public extension View {
    func overlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        self.modifier(OverlayViewModifier(overlayContent: content()))
    }
}

struct OverlayViewModifier<OverlayContent: View>: ViewModifier {

    let overlayContent: OverlayContent

    func body(content: Content) -> some View {
        ZStack {
            content
            self.overlayContent
        }
    }
}
