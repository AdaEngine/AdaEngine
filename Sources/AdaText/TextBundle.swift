//
//  TextBundle.swift
//
//
//  Created by v.prusakov on 5/2/24.
//

import AdaECS
import AdaRender

@Bundle
public struct Text2D {
    public var textComponent = TextComponent(text: AttributedText(""))
    public let noFrustumCulling: NoFrustumCulling
    public var visibility: Visibility


    public init(
        textComponent: TextComponent = TextComponent(text: AttributedText("")),
        noFrustumCulling: NoFrustumCulling = NoFrustumCulling(),
        visibility: Visibility = .visible
    ) {
        self.textComponent = textComponent
        self.visibility = visibility
        self.noFrustumCulling = noFrustumCulling
    }
}
