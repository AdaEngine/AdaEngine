//
//  TextBundle.swift
//
//
//  Created by v.prusakov on 5/2/24.
//

import AdaECS
import AdaRender
import AdaTransform

/// Bundle for 2D text.
@Bundle
public struct Text2D {
    /// Text component.
    public var textComponent = TextComponent(text: AttributedText(""))
    /// Transform component.
    public var transform: Transform
    /// Visibility component.
    public var visibility: Visibility
    /// No frustum culling component.
    public let noFrustumCulling: NoFrustumCulling

    public init(
        textComponent: TextComponent = TextComponent(text: AttributedText("")),
        transform: Transform = Transform(),
        noFrustumCulling: NoFrustumCulling = NoFrustumCulling(),
        visibility: Visibility = .visible
    ) {
        self.textComponent = textComponent
        self.transform = transform
        self.visibility = visibility
        self.noFrustumCulling = noFrustumCulling
    }
}
