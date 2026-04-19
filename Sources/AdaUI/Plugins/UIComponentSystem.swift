//
//  UISystem.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaECS
import AdaInput
import AdaTransform
import AdaRender
import AdaUtils
import Math

@PlainSystem
public struct UIComponentSystem: Sendable {
    
    @Query<Entity, UIComponent, GlobalTransform>
    private var uiComponents

    @Query<Camera>
    private var cameras

    @ResMut
    private var input: Input

    @Res<DeltaTime>
    private var deltaTime

    @Res<WindowManagerResource>
    private var windowManager

    @ResMut<UIWindowPendingDrawViews>
    private var pendingViews

    @ResMut<UIRedrawRequest>
    private var redrawRequest

    @Res<PrimaryWindowId>
    private var primaryWindowId

    public init(world: World) {}

    @MainActor
    public func update(context: UpdateContext) async {
        self.uiComponents.forEach { entity, component, transform in
            update(
                entity: entity,
                component: component,
                globalTransform: transform,
                deltaTime: deltaTime.deltaTime
            )
        }
    }
}

private extension UIComponentSystem {
    @MainActor
    @inline(__always)
    func update(
        entity: Entity,
        component: UIComponent,
        globalTransform: GlobalTransform,
        deltaTime: TimeInterval
    ) {
        let view = component.view
        let behaviour = component.behaviour

        if let viewOwner = (view as? ViewOwner) {
            var environment = EnvironmentValues()
            environment.entity = entity//WeakBox(value: entity)
            if let world = entity.world {
                environment.world = world//WeakBox(value: world)
            }
            viewOwner.updateEnvironment(environment)
        }

        switch behaviour {
        case .overlay:
            if let window = windowManager
                .windowManager
                .windows[component.windowRef.getWindowId(from: primaryWindowId)] {
                // Do not assign `view.window` before `addSubview`: `UIWindow.addSubview`
                // treats `view.window === self` as “already added” and asserts.
                if view.parentView !== window {
                    view.autoresizingRules = [.flexibleWidth, .flexibleHeight]
                    window.addSubview(view)
                }
                let newSize = component.view.sizeThatFits(ProposedViewSize(window.frame.size))
                let newFrame = Rect(origin: .zero, size: newSize)
                if view.frame != newFrame {
                    view.frame = newFrame
                    view.layoutSubviews()
                }
            }
        case .default:
            if view.transform3D != globalTransform.matrix {
                view.transform3D = globalTransform.matrix
                view.setNeedsDisplay()
            }
        }

        let events = input.getInputEvents()
        for event in events {
            guard view.canRespondToAction(event) else {
                continue
            }

            let responder = view.findFirstResponder(for: event) ?? view
            responder.onEvent(event)
        }

        view.update(deltaTime)

        if view.consumeNeedsDisplay() {
            redrawRequest.needsRedraw = true
        }
    }
}

public extension EnvironmentValues {

    /// The world where view attached.
    @Entry internal(set) var world: World?

    /// The game scene where view attached.
    @Entry internal(set) var entity: Entity?

    @Entry internal(set) var input: Ref<Input>?
}
