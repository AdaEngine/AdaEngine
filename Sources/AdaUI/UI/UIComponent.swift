//
//  UIComponent.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaECS
import AdaUtils
import AdaRender

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
    public let windowRef: WindowRef

    @MainActor
    public init<V: View>(
        view: V,
        behaviour: Behaviour,
        windowRef: WindowRef = .primary
    ) {
        self.view = UIContainerView(rootView: view)
        self.view.backgroundColor = .clear
        self.behaviour = behaviour
        self.windowRef = windowRef
    }

    public init(
        view: UIView,
        behaviour: Behaviour,
        windowRef: WindowRef = .primary
    ) {
        self.view = view
        self.behaviour = behaviour
        self.windowRef = windowRef
    }
}
