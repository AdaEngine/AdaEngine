//
//  TextBundle.swift
//
//
//  Created by v.prusakov on 5/2/24.
//

import AdaECS
import AdaRender
import AdaTransform

@Bundle
public struct Text2D {
    public var textComponent = TextComponent(text: AttributedText(""))
    public var transform: Transform
    public var visibility: Visibility
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
