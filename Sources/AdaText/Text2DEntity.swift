//
//  Text2DEntity.swift
//
//
//  Created by v.prusakov on 5/2/24.
//

import AdaECS
import AdaRender

/// Create a new entity with Text2DComponent and without frustum culling.
final class Text2DEntity: Entity, @unchecked Sendable {

    public var textComponent: Text2DComponent {
        get {
            guard let component = self.components[Text2DComponent.self] else {
                fatalError("Text2DEntity doesn't contains Text2DComponent")
            }

            return component
        }

        set {
            self.components += newValue
        }
    }

    public override init(name: String = "Text2DEntity") {
        super.init(name: name)

        self.components += Text2DComponent(text: AttributedText(""))
        self.components += NoFrustumCulling()
    }

    public init(name: String = "Text2DEntity", attributedText: AttributedText = AttributedText("")) {
        super.init(name: name)

        self.components += Text2DComponent(text: attributedText)
        self.components += NoFrustumCulling()
    }
}
