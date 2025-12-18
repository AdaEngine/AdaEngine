//
//  UIContainerView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaInput
import AdaUtils
import Math

/// A container view that contains a view tree.
public class UIContainerView<Content: View>: UIView, ViewOwner {

    /// The container view of the container view.
    var containerView: UIView? {
        return self
    }

    /// The view tree of the container view.
    let viewTree: ViewTree<Content>

    /// Initialize a new container view.
    ///
    /// - Parameter rootView: The root view of the container view.
    public init(rootView: Content) {
        self.viewTree = ViewTree(rootView: rootView)
        super.init()
        viewTree.setViewOwner(self)
    }

    /// Layout the subviews.
    ///
    /// - Note: This method is called when the container view is laid out.
    public override func layoutSubviews() {
        super.layoutSubviews()

        viewTree.rootNode.place(in: .zero, anchor: .zero, proposal: ProposedViewSize(self.frame.size))
    }

    /// Build the menu.
    ///
    /// - Parameter builder: The builder to build the menu with.
    public override func buildMenu(with builder: any UIMenuBuilder) {
        viewTree.rootNode.buildMenu(with: builder)
    }

    /// Initialize a new container view.
    ///
    /// - Parameter frame: The frame of the container view.
    public required init(frame: Rect) {
        fatalError("init(frame:) has not been implemented")
    }

    /// Hit test the container view.
    ///
    /// - Parameters:
    ///   - point: The point to hit test.
    ///   - event: The event to hit test with.
    /// - Returns: The view that was hit.
    public override func hitTest(_ point: Point, with event: any InputEvent) -> UIView? {
        if self.viewTree.rootNode.hitTest(point, with: event) != nil {
            return self
        }

        return self
    }

    /// The last on mouse event node.
    private var lastOnMouseEventNode: ViewNode?

    /// Handle the mouse event.
    ///
    /// - Parameter event: The mouse event to handle.
    public override func onMouseEvent(_ event: MouseEvent) {
        if let viewNode = self.viewTree.rootNode.hitTest(event.mousePosition, with: event) {
            viewNode.onMouseEvent(event)

            if lastOnMouseEventNode !== viewNode {
                lastOnMouseEventNode?.onMouseLeave()
                lastOnMouseEventNode = viewNode
            }
        }
    }

    /// Update the environment.
    ///
    /// - Parameter env: The environment to update.
    func updateEnvironment(_ env: EnvironmentValues) {
        self.viewTree.rootNode.updateEnvironment(env)
    }

    /// Handle the touches event.
    ///
    /// - Parameter touches: The touches event to handle.
    public override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        if touches.isEmpty {
            return
        }

        let firstTouch = touches.first!
        if let viewNode = self.viewTree.rootNode.hitTest(firstTouch.location, with: firstTouch) {
            viewNode.onTouchesEvent(touches)
        }
    }

    /// Check if the container view is point inside.
    ///
    /// - Parameters:
    ///   - point: The point to check.
    ///   - event: The event to check with.
    /// - Returns: A Boolean value indicating whether the container view is point inside.
    public override func point(inside point: Point, with event: any InputEvent) -> Bool {
        return self.viewTree.rootNode.point(inside: point, with: event)
    }
    
    /// Draw the container view.
    ///
    /// - Parameters:
    ///   - rect: The rect to draw the container view in.
    ///   - context: The context to draw the container view in.
    override public func draw(in rect: Rect, with context: UIGraphicsContext) {
        viewTree.renderGraph(renderContext: context)
    }

    /// Update the container view.
    ///
    /// - Parameter deltaTime: The delta time to update the container view with.
    public override func update(_ deltaTime: TimeInterval) {
        super.update(deltaTime)
        self.viewTree.rootNode.update(deltaTime)
    }
}
