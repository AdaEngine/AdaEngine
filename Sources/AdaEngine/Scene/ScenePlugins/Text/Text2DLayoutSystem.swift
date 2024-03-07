//
//  Text2DLayoutSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/7/23.
//

/// An object that store text layout manager
@Component
struct TextLayoutComponent {
    let textLayout: TextLayoutManager
}

/// System for layout text from ``Text2DComponent``.
public struct Text2DLayoutSystem: System {
    
    public static var dependencies: [SystemDependency] = [.before(VisibilitySystem.self)]
    
    static let textComponents = EntityQuery(where: .has(Text2DComponent.self) && .has(Transform.self) && .has(Visibility.self))
    
    public init(scene: Scene) {}
    
    public func update(context: UpdateContext) {
        context.scene.performQuery(Self.textComponents).concurrentIterator.forEach { entity in
            let (text, visibility) = entity.components[Text2DComponent.self, Visibility.self]
            
            if !visibility.isVisible {
                return
            }
            
            let textLayout = entity.components[TextLayoutComponent.self] ?? TextLayoutComponent(textLayout: TextLayoutManager())
            
            let textContainer = TextContainer(
                text: text.text,
                bounds: text.bounds,
                textAlignment: text.textAlignment,
                lineBreakMode: text.lineBreakMode,
                lineSpacing: text.lineSpacing
            )
            
            textLayout.textLayout.setTextContainer(textContainer)
            
            entity.components += textLayout
        }
    }
}
