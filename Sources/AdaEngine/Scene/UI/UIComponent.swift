//
//  UIComponent.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

@Component
public struct UIComponent {

    public enum Behaviour {
        case overlay
        case world
    }

    public let view: AnyView
    public let behaviour: Behaviour

    init<V: View>(view: V, behaviour: Behaviour) {
        self.view = AnyView(view)
        self.behaviour = behaviour
    }
}
