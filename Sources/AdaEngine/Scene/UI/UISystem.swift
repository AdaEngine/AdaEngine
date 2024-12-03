//
//  UISystem.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import Math

public struct UISystem: System {
    private static let query = EntityQuery(where: .has(UIComponent.self) && .has(GlobalTransform.self))

    public init(scene: Scene) { }

    public func update(context: UpdateContext) {
        let entities = context.scene.performQuery(Self.query)

        for entity in entities {
            let (component, globalTransform) = entity.components[UIComponent.self, GlobalTransform.self]
            let view = component.view
            view.window = context.scene.window

            if let viewOwner = (view as? ViewOwner) {
                var environment = EnvironmentValues()
                environment.scene = context.scene
                environment.entity = entity
                viewOwner.updateEnvironment(environment)
            }

            switch component.behaviour {
            case .overlay:
                guard let window = context.scene.window else {
                    return
                }

                let newSize = component.view.sizeThatFits(ProposedViewSize(window.frame.size))
                if view.frame.size != newSize {
                    view.frame.size = newSize
                    view.layoutSubviews()
                }

                var renderContext = UIGraphicsContext(window: window)
                renderContext.beginDraw(in: window.frame.size, scaleFactor: 1)
                view.draw(with: renderContext)
                renderContext.commitDraw()
            case .default:
                view.transform3D = globalTransform.matrix
            }

            for event in Input.getInputEvents() {
                guard view.canRespondToAction(event) else {
                    continue
                }

                let responder = view.findFirstResponder(for: event) ?? view
                responder.onEvent(event)
            }

            Task {
                await view.update(context.deltaTime)
            }
        }
    }
}
