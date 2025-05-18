//
//  UIComponent.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

/// - Warning: Work in progress component
@Component
public struct UIComponent: Sendable {
    /// Behaviour how to draw view on screen
    public enum Behaviour: Sendable {

        /// Always render on top of scene.
        case overlay

        /// Render UI elements in camera
        case `default`
    }

    public let view: UIView
    public let behaviour: Behaviour

    @MainActor
    public init<V: View>(view: V, behaviour: Behaviour) {
        self.view = UIContainerView(rootView: view)
        self.view.backgroundColor = .clear
        self.behaviour = behaviour
    }
}
