//
//  BackgroundModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import AdaUtils
import Math

public extension View {
    /// Layers the color view that you specify behind this view.
    /// - Parameter color: A ``Color`` that you use to declare the views to draw behind this view.
    func background(_ color: Color) -> some View {
        self.modifier(BackgroundViewModifier(anchor: .center, backgroundContent: color))
    }

    /// Layers the views that you specify behind this view.
    /// - Parameter anchor: The alignment that the modifier uses to position the implicit ``ZStack`` that groups the background views. The default is center.
    /// - Parameter content: A ``ViewBuilder`` that you use to declare the views to draw behind this view, 
    /// stacked in a cascading order from bottom to top. The last view that you list appears at the front of the stack.
    func background<Content: View>(anchor: AnchorPoint = .center, @ViewBuilder content: () -> Content) -> some View {
        self.modifier(BackgroundViewModifier(anchor: anchor, backgroundContent: content()))
    }
}

private struct BackgroundViewModifier<BackgroundContent: View>: ViewModifier {

    let anchor: AnchorPoint
    let backgroundContent: BackgroundContent

    func body(content: Content) -> some View {
        ZStack(anchor: self.anchor) {
            self.backgroundContent
            content
        }
    }
}
