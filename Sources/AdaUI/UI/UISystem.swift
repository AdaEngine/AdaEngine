//
//  UISystem.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaECS
import AdaInput
import AdaTransform
import AdaUtils
import Math

@System
public struct UIComponentSystem: Sendable {
    
    @EntityQuery(where: .has(UIComponent.self) && .has(GlobalTransform.self))
    private var uiComponents

    public init(world: World) {}

    public func update(context: UpdateContext) {
//        guard let scene = context.scene else {
//            return
//        }
//
//        for entity in self.uiComponents {
//            context.taskGroup.addTask {
//                await update(entity: entity, scene: scene, deltaTime: context.deltaTime)
//            }
//        }
    }
}

private extension UIComponentSystem {
    @MainActor
    func update(entity: Entity, window: UIWindow, deltaTime: TimeInterval) async {
        let (component, globalTransform) = entity.components[UIComponent.self, GlobalTransform.self]
        let view = component.view
        let behaviour = component.behaviour
        view.window = window

        if let viewOwner = (view as? ViewOwner) {
            var environment = EnvironmentValues()
//            environment.scene = WeakBox(value: scene)
            environment.entity = WeakBox(value: entity)
            viewOwner.updateEnvironment(environment)
        }

        switch behaviour {
        case .overlay:
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

        await view.update(deltaTime)
    }
}

public extension EnvironmentValues {

    /// The world where view attached.
    @Entry internal(set) var world: WeakBox<World>?

    /// The game scene where view attached.
    @Entry internal(set) var entity: WeakBox<Entity>?
}
