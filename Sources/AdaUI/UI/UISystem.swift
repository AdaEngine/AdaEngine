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

@PlainSystem
public struct UIComponentSystem: Sendable {
    
    @Query<Entity, UIComponent, GlobalTransform>
    private var uiComponents

    @ResMut
    private var input: Input?

    @Res<DeltaTime>
    private var deltaTime

    public init(world: World) {}

    @MainActor
    public func update(context: UpdateContext) {
//        for value in self.uiComponents {
//            await update(
//                entity: value.entity,
//                component: value.component,
//                globalTransform: value.globalTransform,
//                window: UIWindow,
//                deltaTime: deltaTime.deltaTime
//            )
//        }
    }
}

private extension UIComponentSystem {
    @MainActor
    @inline(__always)
    func update(
        entity: Entity,
        component: UIComponent,
        globalTransform: GlobalTransform,
        window: UIWindow,
        deltaTime: TimeInterval
    ) async {
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

        if let input = self.input {
            for event in input.getInputEvents() {
                guard view.canRespondToAction(event) else {
                    continue
                }

                let responder = view.findFirstResponder(for: event) ?? view
                responder.onEvent(event)
            }
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
