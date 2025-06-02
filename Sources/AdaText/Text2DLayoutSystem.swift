//
//  Text2DLayoutSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/7/23.
//

import AdaECS
import AdaRender

/// An object that store text layout manager
@Component
struct TextLayoutComponent {
    let textLayout: TextLayoutManager
}

/// System for layout text from ``Text2DComponent``.
@System()
public struct Text2DLayoutSystem {
    
    @Query<Entity, Ref<Text2DComponent>, Visibility>(filter: [.stored, .added])
    private var textComponents
    
    public init(world: World) { }
    
    public func update(context: inout UpdateContext) {
        self.textComponents.forEach { entity, text, visibility in
            if visibility == .hidden {
                return
            }
            
            let textLayout = entity.components[TextLayoutComponent.self] ?? TextLayoutComponent(textLayout: TextLayoutManager())
            
            let textContainer = TextContainer(
                text: text.text,
                textAlignment: text.textAlignment,
                lineBreakMode: text.lineBreakMode,
                lineSpacing: text.lineSpacing
            )

            textLayout.textLayout.setTextContainer(textContainer)
            textLayout.textLayout.fitToSize(text.bounds.size)

            entity.components += textLayout
        }
    }
}
