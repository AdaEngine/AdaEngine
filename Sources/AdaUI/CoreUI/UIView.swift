//
//  View.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/11/22.
//

@_spi(Internal) import AdaInput
import AdaUtils
import Math

// - TODO: (Vlad) Blending mode (cuz alpha doesn't work)
// - TODO: (Vlad) texturing the views
// - TODO: (Vlad) draw lines
// - TODO: (Vlad) create transperent API for 2D rendering
// - TODO: (Vlad) Interaction (hit testing)
// - TODO: (Vlad) Cropping

/// An object that manages the content for a rectangular area on the screen.
///
/// Views are the fundamental building blocks of your app’s user interface, and the ``UIView`` class defines the behaviors that are common to all views.
///
/// - Warning: Under development and currently doesn't work as expected.
@MainActor
open class UIView {

    // MARK: - Public Fields -

    /// Contains size and position coordinates relative to parent local coordinates
    open var frame: Rect {
        didSet {
            self.setFrame(self.frame)
        }
    }

    /// Contains size and position relative to self local coordinates.
    open var bounds: Rect = .zero

    /// Contains link to parent parent view
    public private(set) weak var parentView: UIView?

    /// The subviews of the view.
    public private(set) var subviews: [UIView] = []

    /// A Boolean value indicating whether the view is interactive.
    open var isInteractionEnabled: Bool = true

    /// A Boolean value indicating whether the view is hidden.
    open var isHidden: Bool = false {
        didSet {
            if oldValue != isHidden {
                setNeedsDisplay()
            }
        }
    }

    /// The z-index of the view.
    open var zIndex: Int = 0 {
        didSet {
            self.parentView?.needsResortZPositionForChildren = true
            setNeedsDisplay()
        }
    }

    /// The background color of the view.
    public var backgroundColor: Color = .white {
        didSet {
            setNeedsDisplay()
        }
    }

    /// The debug view color of the view.
    private let debugViewColor = Color.random()

    /// The window of the view.
    public internal(set) weak var window: UIWindow? {
        willSet {
            willMoveToWindow(newValue)
        }
        didSet {
            didMoveToWindow(self.window)
        }
    }

    /// The affine matrix to apply any transformation to current view.
    public var affineTransform: Transform2D {
        get {
            return Transform2D(affineTransformFrom: self.transform3D)
        }
        set {
            self.transform3D = Transform3D(fromAffineTransform: newValue)
        }
    }

    /// The 3D transform of the view.
    public var transform3D: Transform3D = .identity

    // MARK: - Private Fields -

    /// A Boolean value indicating whether the view needs to be laid out.
    private var needsLayout = true
    internal var needsDisplay = true

    /// A Boolean value indicating whether the view needs to be resorted by z-index.
    var needsResortZPositionForChildren = false

    private var _zSortedChildren: [UIView] = []
    var zSortedChildren: [UIView] {
        if needsResortZPositionForChildren {
            _zSortedChildren = self.subviews.sorted(by: { $0.zIndex < $1.zIndex })
            needsResortZPositionForChildren = false
        }

        return _zSortedChildren
    }

    // MARK: - Init

    /// Initialize a new view.
    ///
    /// - Parameter frame: The frame of the view.
    public required init(frame: Rect) {
        self.frame = frame
        self.bounds.size = frame.size
    }

    /// Initialize a new view.
    public init() {
        self.frame = .zero
    }

    // MARK: Rendering

    /// Draw the view.
    ///
    /// - Parameters:
    ///   - rect: The rect to draw the view in.
    ///   - context: The context to draw the view in.
    open func draw(in rect: Rect, with context: UIGraphicsContext) { }

    /// Internal method for drawing.
    @_spi(AdaEngine)
    open func draw(with context: UIGraphicsContext) {
        if self.isHidden {
            return
        }
        
        var context = context

        if affineTransform != .identity {
            context.concatenate(Transform3D(fromAffineTransform: affineTransform))
        }

        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)

        /// Draw background
        context.drawRect(self.bounds, color: self.backgroundColor)

        self.draw(in: self.bounds, with: context)

        if context.environment.debugViewDrawingOptions.contains(.drawViewOverlays) {
            context.drawDebugBorders(frame.size, color: debugViewColor)
        }

        for subview in self.zSortedChildren {
            subview.draw(with: context)
        }
    }

    /// The world transform of the view.
    private var worldTransform: Transform2D {
        if let parentView = self.parentView {
            return parentView.affineTransform * self.affineTransform
        }

        return self.affineTransform
    }

    // MARK: - Layout

    /// Set the frame of the view.
    ///
    /// - Parameter frame: The frame of the view.
    func setFrame(_ frame: Rect) {
        self.bounds.size = frame.size

        self.frameDidChange()
        self.setNeedsLayout()
    }

    /// Called when the frame of the view changes.
    open func frameDidChange() { }

    /// Set the needs layout flag.
    public func setNeedsLayout() {
        self.needsLayout = true
        setNeedsDisplay()
    }

    /// Set the needs display flag.
    public func setNeedsDisplay() {
        setNeedsDisplay(in: bounds)
    }

    /// Set the needs display flag for specific rect.
    public func setNeedsDisplay(in rect: Rect) {
        self.needsDisplay = true
        guard let window else {
            return
        }

        window.markDirty(rectInWindow(rect))
        window.needsDisplay = true
    }

    internal func consumeNeedsDisplay() -> Bool {
        defer { needsDisplay = false }
        return needsDisplay
    }

    /// Layout the view if needed.
    public func layoutIfNeeded() {
        if needsLayout {
            self.layoutSubviews()
            self.needsLayout = false
        }
    }

    /// Update the autoresizing frame if needed.
    private func updateAutoresizingFrameIfNeeded() {
        guard let parentView = self.parentView else {
            return
        }

        if autoresizingRules.contains(.flexibleHeight) && self.frame.height != parentView.frame.height {
            self.frame.size.height = parentView.frame.height
            self.setNeedsLayout()
        }

        if autoresizingRules.contains(.flexibleWidth) && self.frame.width != parentView.frame.width {
            self.frame.size.width = parentView.frame.width
            self.setNeedsLayout()
        }
    }

    /// Build the menu.
    ///
    /// - Parameter builder: The builder to build the menu with.
    @_spi(Internal)
    public func _buildMenu(with builder: UIMenuBuilder) {
        self.buildMenu(with: builder)

        for subview in subviews {
            subview._buildMenu(with: builder)
        }
    }

    /// Build the menu.
    ///
    /// - Parameter builder: The builder to build the menu with.
    open func buildMenu(with builder: UIMenuBuilder) { }

    /// Layout the subviews.
    open func layoutSubviews() {
        self.updateAutoresizingFrameIfNeeded()

        for subview in subviews {
            subview.layoutSubviews()
        }
    }

    /// The minimum content size of the view.
    open var minimumContentSize: Size {
        return .zero
    }

    /// The autoresizing rules of the view.
    public struct AutoresizingRule: OptionSet, Sendable {

        public var rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let flexibleWidth = AutoresizingRule(rawValue: 1 << 0)
        public static let flexibleHeight = AutoresizingRule(rawValue: 1 << 1)
    }

    /// The autoresizing rules of the view.
    public var autoresizingRules: AutoresizingRule = []

    /// The size that fits the view.
    ///
    /// - Parameter proposal: The proposed size.
    /// - Returns: The size that fits the view.
    open func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        var newSize = self.bounds.size

        if let width = proposal.width, width != .infinity {
            newSize.width = width
        }

        if let height = proposal.height, height != .infinity {
            newSize.height = height
        }

        return newSize
    }

    // MARK: - Life cycle

    /// - Parameter parentView: Return view instance if view attached to parentview or nil if view deattached from parentView.
    /// Also parent can be ``UIWindow`` instance.
    open func viewWillMove(to parentView: UIView?) {
        if parentView != nil {
            updateAutoresizingFrameIfNeeded()
        }
    }

    /// Called when the view is moved to a parent view.
    open func viewDidMoveToParentView() { }

    /// Called when the view is moved to a window.
    open func viewDidMoveToWindow() { }

    /// Called when the view is moved to a window.
    open func viewWillMove(to window: UIWindow?) { }

    /// Called when the view is moved to a window.
    private func willMoveToWindow(_ window: UIWindow?) {
        self.viewWillMove(to: window)

        for subview in subviews {
            subview.viewWillMove(to: window)
        }
    }

    private func didMoveToWindow(_ window: UIWindow?) {
        for subview in subviews {
            subview.window = window
            subview.viewWillMove(to: window)
        }
    }

    // MARK: - Interaction

    /// Returns the farthest descendant in the view hierarchy of the current view, including itself, that contains the specified point.
    ///
    /// - Parameters:
    ///   - point: The point to hit test.
    ///   - event: The event to hit test with.
    /// - Returns: The view that was hit.
    open func hitTest(_ point: Point, with event: any InputEvent) -> UIView? {
        guard self.isInteractionEnabled && !self.isHidden else {
            return nil
        }
        if !self.point(inside: point, with: event) {
            return nil
        }
        if self.subviews.isEmpty {
            return self
        }

        for subview in self.subviews.reversed() {
            let newPoint = subview.convert(point, from: self)
            if let view = subview.hitTest(newPoint, with: event) {
                return view
            }
        }

        return self
    }

    /// Returns a Boolean value indicating whether the receiver contains the specified point.
    ///
    /// - Parameters:
    ///   - point: The point to check.
    ///   - event: The event to check with.
    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    open func point(inside point: Point, with event: any InputEvent) -> Bool {
        return self.bounds.contains(point: point)
    }

    public func convert(_ point: Point, to view: UIView?) -> Point {
        guard let view, view !== self else {
            return point
        }

        if view.parentView === self {
            return (point - view.frame.origin).applying(self.affineTransform.inverse) + view.bounds.origin
        } else if let parentView, parentView === view {
            return (point - bounds.origin).applying(self.affineTransform) + frame.origin
        }

        let currentWorldTransform = self.worldTransform.position
        let viewWorldTransform = self.worldTransform.position

        return point - (viewWorldTransform - currentWorldTransform)
    }

    /// Converts a point from the coordinate system of another view to the coordinate system of the current view.
    ///
    /// - Parameters:
    ///   - point: The point to convert.
    ///   - view: The view to convert the point from.
    /// - Returns: The converted point.
    public func convert(_ point: Point, from view: UIView?) -> Point {
        return view?.convert(point, to: self) ?? point
    }

    private func rectInWindow(_ rect: Rect) -> Rect {
        guard let window else {
            return rect
        }

        let origin = convert(rect.origin, to: window)
        let maxPoint = convert(Point(x: rect.maxX, y: rect.maxY), to: window)
        let minX = min(origin.x, maxPoint.x)
        let minY = min(origin.y, maxPoint.y)
        let maxX = max(origin.x, maxPoint.x)
        let maxY = max(origin.y, maxPoint.y)
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Called when the view can respond to an action.
    ///
    /// - Parameter event: The event to check.
    /// - Returns: A Boolean value indicating whether the view can respond to an action.
    open func canRespondToAction(_ event: any InputEvent) -> Bool {
        return true
    }

    /// Called when the touches event is received.
    ///
    /// - Parameter touches: The touches event.
    open func onTouchesEvent(_ touches: Set<TouchEvent>) { }

    /// Called when the mouse event is received.
    ///
    /// - Parameter event: The mouse event.
    open func onMouseEvent(_ event: MouseEvent) { }

    open func onKeyPressed(_ event: Set<KeyEvent>) { }

    /// Called when the event is received.
    ///
    /// - Parameter event: The event.
    internal func onEvent(_ event: any InputEvent) {
        switch event {
        case let event as MouseEvent:
            self.onMouseEvent(event)
        case is TouchEvent:
            let window = self.window?.id
//            let touches = Input.shared.touches.filter({ $0.window == window })
//            self.onTouchesEvent(touches)
        default:
            return
        }
    }

    private var eventsDisposeBag: Set<AnyCancellable> = []

    /// Subscribe to an event.
    ///
    /// - Parameters:
    ///   - event: The event to subscribe to.
    ///   - completion: The completion handler.
    public func subscribe<Event: InputEvent>(to event: Event.Type, completion: @escaping @Sendable (Event) -> Void) {
        self.window?.eventManager.subscribe(to: event, completion: completion)
            .store(in: &eventsDisposeBag)
    }

    /// Find the first responder for an event.
    ///
    /// - Parameter event: The event to find the first responder for.
    /// - Returns: The first responder.
    func findFirstResponder(for event: any InputEvent) -> UIView? {
        let responder: UIView? = switch event {
        case let event as MouseEvent:
            self.hitTest(
                convert(event.mousePosition, to: self),
                with: event
            )
        case let event as TouchEvent:
            self.hitTest(
                event.location,
                with: event
            )
        default:
            nil
        }

        if responder?.canRespondToAction(event) == false {
            return nil
        }

        return responder
    }

    // MARK: - View Hierarchy

    /// Add a subview to the view.
    ///
    /// - Parameter view: The view to add.
    open func addSubview(_ view: UIView) {
        if self === view {
            fatalError("Can't add self as subview")
        }

        if view.parentView != nil {
            fatalError("Can't add view if view attached to another view")
        }

        view.viewWillMove(to: self)
        self.subviews.append(view)

        // FIXME: Should fix?
        if let window = self as? UIWindow {
            view.window = window
        } else {
            view.window = self.window
        }

        view.parentView = self
        view.viewDidMoveToParentView()
        self.needsResortZPositionForChildren = true
        self.setNeedsLayout()
    }

    /// Remove the view from its parent view.
    open func removeFromParentView() {
        self.parentView?.removeSubview(self)
    }

    /// Remove a subview from the view.
    ///
    /// - Parameter view: The view to remove.
    open func removeSubview(_ view: UIView) {
        guard let index = self.subviews.firstIndex(where: { $0 === view }) else { return }
        let deletedView = self.subviews.remove(at: index)
        view.viewWillMove(to: nil)
        view.window = nil
        deletedView.parentView = nil

        self.needsResortZPositionForChildren = true
    }

    /// Internal update.
    ///
    /// - Parameter deltaTime: The delta time.
    func internalUpdate(_ deltaTime: TimeInterval) {
        self.layoutIfNeeded()
        self.update(deltaTime)

        for subview in self.subviews {
            subview.internalUpdate(deltaTime)
            subview.update(deltaTime)
        }
    }

    /// Called each frame.
    ///
    /// - Parameter deltaTime: The delta time.
    open func update(_ deltaTime: TimeInterval) { }
}

/// During layout in AdaEngine UI, views choose their own size, but they do that in response to a size proposal from their parent view.
public struct ProposedViewSize: Hashable, Equatable, Sendable {
    /// The proposed horizontal size measured in points.
    public var width: Float?

    /// The proposed vertical size measured in points.
    public var height: Float?

    /// A size proposal that contains zero in both dimensions.
    public static let zero = ProposedViewSize(width: 0, height: 0)

    /// A size proposal that contains infinity in both dimensions.
    public static let infinity = ProposedViewSize(width: .infinity, height: .infinity)

    /// The proposed size with both dimensions left unspecified.
    public static let unspecified = ProposedViewSize(width: nil, height: nil)

    /// Creates a new proposal that replaces unspecified dimensions in this proposal with the corresponding dimension of the specified size.
    public func replacingUnspecifiedDimensions(by size: Size = Size(width: 10, height: 10)) -> Size {
        return Size(width: self.width ?? size.width, height: self.height ?? size.height)
    }

    init(width: Float? = nil, height: Float? = nil) {
        self.width = width
        self.height = height
    }

    init(_ size: Size) {
        self.width = size.width
        self.height = size.height
    }

}
