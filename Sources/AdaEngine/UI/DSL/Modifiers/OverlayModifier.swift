//
//  OverlayModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.07.2024.
//

public extension View {
    /// Layers the views that you specify in front of this view.
    /// - Parameter anchor: The anchor that the modifier uses to position the implicit ``ZStack`` that groups the foreground views. The default is center.
    /// - Parameter content: A ``ViewBuilder`` that you use to declare the views to draw in front of this view, stacked in the order that you list them. The last view that you list appears at the front of the stack.
    func overlay<Content: View>(
        anchor: AnchorPoint = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        self.modifier(OverlayViewModifier(anchor: anchor, overlayContent: content()))
    }
}

struct OverlayViewModifier<OverlayContent: View>: ViewModifier {

    let anchor: AnchorPoint
    let overlayContent: OverlayContent

    func body(content: Content) -> some View {
        ZStack(anchor: self.anchor) {
            content
            self.overlayContent
        }
    }
}
