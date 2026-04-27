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

@MainActor
protocol UIInspectionOverlayStateProviding: AnyObject {
    var inspectionFocusedNode: ViewNode? { get }
    var inspectionHitTestNode: ViewNode? { get }
}

@MainActor
public protocol UIMousePassthroughEventReceiving: AnyObject {
    func uiReceivePassthroughMouseMoved(_ event: MouseEvent)
}

/// A container view that contains a view tree.
public final class UIContainerView<Content: View>: UIView, ViewOwner, FocusedInputContainer, UIInspectionOverlayStateProviding, UIMousePassthroughEventReceiving {

    /// The container view of the container view.
    var containerView: UIView? {
        return self
    }

    /// The view tree of the container view.
    let viewTree: ViewTree<Content>

    var inspectionDebugOverlayMode: UIDebugOverlayMode = .off
    weak var inspectionLastHitTestNode: ViewNode?

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

        var env = EnvironmentValues()
        env.safeAreaInsets = safeAreaInsets
        env.userInterfaceIdiom = userInterfaceIdiom
        env.colorScheme = colorScheme
        env.scaleFactor = window?.screen?.scale ?? Screen.main?.scale ?? 1
        viewTree.rootNode.mergeEnvironment(env)

        focusManager.setRootNode(viewTree.rootNode)
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

        return nil
    }

    /// The last on mouse event node.
    private weak var lastOnMouseEventNode: ViewNode?
    /// Mouse-down capture target. Subsequent changed/ended events are routed here.
    private weak var activeMouseEventNode: ViewNode?
    /// Touch-began capture target. Subsequent moved/ended/cancelled events are routed here.
    private weak var activeTouchEventNode: ViewNode?
    /// Manages keyboard-driven focus traversal across focusable nodes.
    let focusManager = UIFocusManager()
    var hasFocusedInputNode: Bool {
        self.focusManager.focusedNode != nil
    }
    var inspectionFocusedNode: ViewNode? {
        self.focusManager.focusedNode
    }
    var inspectionHitTestNode: ViewNode? {
        self.inspectionLastHitTestNode
    }

    // MARK: - Keyboard shortcuts (before focused key dispatch)

    private final class KeyboardShortcutWeakHandle {
        weak var target: KeyboardShortcutModifierNode?

        init(target: KeyboardShortcutModifierNode) {
            self.target = target
        }
    }

    private var keyboardShortcutHandles: [KeyboardShortcutWeakHandle] = []

    /// Handle the mouse event.
    ///
    /// - Parameter event: The mouse event to handle.
    public override func onMouseEvent(_ event: MouseEvent) {
        let localPoint = self.convert(event.mousePosition, from: self.window)
        switch event.phase {
        case .began:
            let viewNode = self.viewTree.rootNode.hitTest(localPoint, with: event)
            self.inspectionLastHitTestNode = viewNode
            self.activeMouseEventNode = viewNode
            self.updateFocusedNode(with: viewNode)
            viewNode?.onMouseEvent(event)
            self.invalidateInspectionOverlayIfNeeded()
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
                self.inspectionLastHitTestNode = viewNode
                viewNode.onMouseEvent(event)
                self.invalidateInspectionOverlayIfNeeded()
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
                self.inspectionLastHitTestNode = viewNode
                viewNode.onMouseEvent(event)
                self.invalidateInspectionOverlayIfNeeded()
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

    @_spi(Internal)
    public func uiReceivePassthroughMouseMoved(_ event: MouseEvent) {
        onMouseEvent(event)
    }

    public override func onKeyEvent(_ event: KeyEvent) {
        if event.keyCode == .tab, event.status == .down {
            if event.modifiers.contains(.shift) {
                focusManager.focusPrevious()
            } else {
                focusManager.focusNext()
            }
            self.invalidateInspectionOverlayIfNeeded()
            return
        }

        // Local shortcuts (`.keyboardShortcut`) run before focused controls so navigation keys
        // still work when a ``TextField`` has focus. Remove dead weak entries opportunistically.
        self.keyboardShortcutHandles.removeAll { $0.target == nil }
        for handle in self.keyboardShortcutHandles {
            guard let node = handle.target else {
                continue
            }
            if node.handleShortcutIfNeeded(event: event) {
                return
            }
        }

        if let focusedNode = focusManager.focusedNode {
            focusedNode.onKeyEvent(event)
        } else {
            self.viewTree.rootNode.onReceiveEvent(event)
        }
    }

    public override func onTextInputEvent(_ event: TextInputEvent) {
        if let focusedNode = focusManager.focusedNode {
            focusedNode.onTextInputEvent(event)
        } else {
            self.viewTree.rootNode.onReceiveEvent(event)
        }
    }

    private func updateFocusedNode(with hitNode: ViewNode?) {
        let previousFocusedNode = focusManager.focusedNode
        let newFocusedNode = self.findFocusableNode(from: hitNode)
        focusManager.focus(newFocusedNode)
        if previousFocusedNode !== focusManager.focusedNode {
            self.invalidateInspectionOverlayIfNeeded()
        }
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
        guard let firstTouch = touches.first else {
            return
        }

        let localPoint = self.convert(firstTouch.location, from: self.window)

        switch firstTouch.phase {
        case .began:
            let viewNode = self.viewTree.rootNode.hitTest(localPoint, with: firstTouch)
            self.inspectionLastHitTestNode = viewNode
            self.activeTouchEventNode = viewNode
            self.updateFocusedNode(with: viewNode)
            viewNode?.onTouchesEvent(touches)
            self.invalidateInspectionOverlayIfNeeded()
        case .moved:
            if let activeTouchEventNode {
                activeTouchEventNode.onTouchesEvent(touches)
            } else if let viewNode = self.viewTree.rootNode.hitTest(localPoint, with: firstTouch) {
                self.inspectionLastHitTestNode = viewNode
                viewNode.onTouchesEvent(touches)
                self.invalidateInspectionOverlayIfNeeded()
            }
        case .ended, .cancelled:
            if let activeTouchEventNode {
                activeTouchEventNode.onTouchesEvent(touches)
            } else if let viewNode = self.viewTree.rootNode.hitTest(localPoint, with: firstTouch) {
                self.inspectionLastHitTestNode = viewNode
                viewNode.onTouchesEvent(touches)
                self.invalidateInspectionOverlayIfNeeded()
            }
            self.activeTouchEventNode = nil
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
        drawInspectionDebugOverlay(with: context)
    }

    /// Update the container view.
    ///
    /// - Parameter deltaTime: The delta time to update the container view with.
    public override func update(_ deltaTime: TimeInterval) {
        super.update(deltaTime)
        self.viewTree.rootNode.update(deltaTime)
    }

    private func drawInspectionDebugOverlay(with context: UIGraphicsContext) {
        guard inspectionDebugOverlayMode != .off else {
            return
        }

        viewTree.rootNode.drawInspectionDebugOverlay(
            with: context,
            mode: inspectionDebugOverlayMode,
            focusedNode: focusManager.focusedNode,
            hitTestNode: inspectionLastHitTestNode
        )
    }

    private func invalidateInspectionOverlayIfNeeded() {
        self.setNeedsDisplay()
    }
}

extension UIContainerView: KeyboardShortcutRegistering {
    func registerKeyboardShortcut(target: KeyboardShortcutModifierNode) {
        let id = ObjectIdentifier(target)
        self.keyboardShortcutHandles.removeAll {
            guard let t = $0.target else {
                return false
            }
            return ObjectIdentifier(t) == id
        }
        self.keyboardShortcutHandles.append(KeyboardShortcutWeakHandle(target: target))
    }

    func unregisterKeyboardShortcut(target: KeyboardShortcutModifierNode) {
        let id = ObjectIdentifier(target)
        self.keyboardShortcutHandles.removeAll {
            guard let t = $0.target else {
                return false
            }
            return ObjectIdentifier(t) == id
        }
    }
}
