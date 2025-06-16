//
//  Text2DEntity.swift
//
//
//  Created by v.prusakov on 5/2/24.
//

import AdaECS
import AdaRender

@Bundle
public struct Text2DBundle {
    public var textComponent = Text2DComponent(text: AttributedText(""))
    let noFrustumCulling: NoFrustumCulling

    public init(
        textComponent: Text2DComponent = Text2DComponent(text: AttributedText("")),
        noFrustumCulling: NoFrustumCulling
    ) {
        self.textComponent = textComponent
        self.noFrustumCulling = noFrustumCulling
    }
}
