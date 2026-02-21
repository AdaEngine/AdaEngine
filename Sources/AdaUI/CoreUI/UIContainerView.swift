//
//  UIContainerView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaInput
import AdaUtils
import Math

@MainActor
protocol FocusedInputContainer: AnyObject {
    var hasFocusedInputNode: Bool { get }
}

/// A container view that contains a view tree.
public final class UIContainerView<Content: View>: UIView, ViewOwner, FocusedInputContainer {

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

        viewTree.rootNode.place(
            in: .zero,
            anchor: .zero,
            proposal: ProposedViewSize(self.frame.size)
        )
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
    private weak var lastOnMouseEventNode: ViewNode?
    /// Mouse-down capture target. Subsequent changed/ended events are routed here.
    private weak var activeMouseEventNode: ViewNode?
    /// Focused node that receives keyboard and text input events.
    private weak var focusedNode: ViewNode?
    var hasFocusedInputNode: Bool {
        self.focusedNode != nil
    }

    /// Handle the mouse event.
    ///
    /// - Parameter event: The mouse event to handle.
    public override func onMouseEvent(_ event: MouseEvent) {
        let localPoint = self.convert(event.mousePosition, from: self.window)
        switch event.phase {
        case .began:
            let viewNode = self.viewTree.rootNode.hitTest(localPoint, with: event)
            self.activeMouseEventNode = viewNode
            self.updateFocusedNode(with: viewNode)
            viewNode?.onMouseEvent(event)
            if lastOnMouseEventNode !== viewNode {
                lastOnMouseEventNode?.onMouseLeave()
                lastOnMouseEventNode = viewNode
            }
        case .changed:
            if event.button != .scrollWheel, let activeMouseEventNode {
                activeMouseEventNode.onMouseEvent(event)
                if lastOnMouseEventNode !== activeMouseEventNode {
                    lastOnMouseEventNode?.onMouseLeave()
                    lastOnMouseEventNode = activeMouseEventNode
                }
            } else if let viewNode = self.viewTree.rootNode.hitTest(localPoint, with: event) {
                viewNode.onMouseEvent(event)
                if lastOnMouseEventNode !== viewNode {
                    lastOnMouseEventNode?.onMouseLeave()
                    lastOnMouseEventNode = viewNode
                }
            } else if lastOnMouseEventNode != nil {
                lastOnMouseEventNode?.onMouseLeave()
                lastOnMouseEventNode = nil
            }
        case .ended, .cancelled:
            if let activeMouseEventNode {
                activeMouseEventNode.onMouseEvent(event)
                if lastOnMouseEventNode !== activeMouseEventNode {
                    lastOnMouseEventNode?.onMouseLeave()
                    lastOnMouseEventNode = activeMouseEventNode
                }
            } else if let viewNode = self.viewTree.rootNode.hitTest(localPoint, with: event) {
                viewNode.onMouseEvent(event)
                if lastOnMouseEventNode !== viewNode {
                    lastOnMouseEventNode?.onMouseLeave()
                    lastOnMouseEventNode = viewNode
                }
            } else if lastOnMouseEventNode != nil {
                lastOnMouseEventNode?.onMouseLeave()
                lastOnMouseEventNode = nil
            }
            self.activeMouseEventNode = nil
        }
    }

    public override func onKeyEvent(_ event: KeyEvent) {
        if let focusedNode {
            focusedNode.onKeyEvent(event)
        } else {
            self.viewTree.rootNode.onReceiveEvent(event)
        }
    }

    public override func onTextInputEvent(_ event: TextInputEvent) {
        if let focusedNode {
            focusedNode.onTextInputEvent(event)
        } else {
            self.viewTree.rootNode.onReceiveEvent(event)
        }
    }

    private func updateFocusedNode(with hitNode: ViewNode?) {
        let newFocusedNode = self.findFocusableNode(from: hitNode)
        if self.focusedNode === newFocusedNode {
            return
        }

        self.focusedNode?.onFocusChanged(isFocused: false)
        self.focusedNode = newFocusedNode
        self.focusedNode?.onFocusChanged(isFocused: true)
    }

    private func findFocusableNode(from node: ViewNode?) -> ViewNode? {
        var currentNode = node
        while let current = currentNode {
            if current.canBecomeFocused {
                return current
            }
            currentNode = current.parent
        }

        return nil
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
        let localPoint = self.convert(firstTouch.location, from: self.window)
        if let viewNode = self.viewTree.rootNode.hitTest(localPoint, with: firstTouch) {
            if firstTouch.phase == .began {
                self.updateFocusedNode(with: viewNode)
            }
            viewNode.onTouchesEvent(touches)
        } else if firstTouch.phase == .began {
            self.updateFocusedNode(with: nil)
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
        var context = context
        context.dirtyRect = window?.consumeDirtyRect()
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
