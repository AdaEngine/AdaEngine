//
//  BackgroundModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

public extension View {
    func background(_ color: Color) -> some View {
        self.modifier(BackgroundView(backgroundContent: color))
    }

    func background<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        self.modifier(BackgroundView(backgroundContent: content()))
    }
}

struct BackgroundView<BackgroundContent: View>: ViewModifier {

    let backgroundContent: BackgroundContent

    init(backgroundContent: BackgroundContent) {
        self.backgroundContent = backgroundContent
    }

    func body(content: Content) -> some View {
        ZStack {
            self.backgroundContent
            content
        }
    }
}
