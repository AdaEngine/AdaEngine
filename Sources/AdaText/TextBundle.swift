//
//  TextBundle.swift
//
//
//  Created by v.prusakov on 5/2/24.
//

import AdaECS
import AdaRender

@Bundle
public struct TextBundle {
    public var textComponent = TextComponent(text: AttributedText(""))
    let noFrustumCulling: NoFrustumCulling

    public init(
        textComponent: TextComponent = TextComponent(text: AttributedText("")),
        noFrustumCulling: NoFrustumCulling
    ) {
        self.textComponent = textComponent
        self.noFrustumCulling = noFrustumCulling
    }
}
