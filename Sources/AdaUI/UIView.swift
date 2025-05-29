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
/// Views are the fundamental building blocks of your app’s user interface, and the ``View`` class defines the behaviors that are common to all views.
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

    public private(set) var subviews: [UIView] = []

    open var isInteractionEnabled: Bool = true

    open var isHidden: Bool = false

    open var zIndex: Int = 0 {
        didSet {
            self.parentView?.needsResortZPositionForChildren = true
        }
    }

    public var backgroundColor: Color = .white
    private let debugViewColor = Color.random()

    public internal(set) weak var window: UIWindow? {
        willSet {
            willMoveToWindow(newValue)
        }
        didSet {
            didMoveToWindow(self.window)
        }
    }

    /// Affine matrix to apply any transformation to current view
    public var affineTransform: Transform2D {
        get {
            return Transform2D(affineTransformFrom: self.transform3D)
        }
        set {
            self.transform3D = Transform3D(fromAffineTransform: newValue)
        }
    }
    public var transform3D: Transform3D = .identity

    // MARK: - Private Fields -

    private var needsLayout = true

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

    public required init(frame: Rect) {
        self.frame = frame
        self.bounds.size = frame.size
    }

    public init() {
        self.frame = .zero
    }

    // MARK: Rendering

    open func draw(in rect: Rect, with context: UIGraphicsContext) { }

    /// Internal method for drawing
    @_spi(AdaEngineEditor)
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

        if context._environment.drawDebugOutlines {
            context.drawDebugBorders(frame.size, color: debugViewColor)
        }

        for subview in self.zSortedChildren {
            subview.draw(with: context)
        }
    }

    private var worldTransform: Transform2D {
        if let parentView = self.parentView {
            return parentView.affineTransform * self.affineTransform
        }

        return self.affineTransform
    }

    // MARK: - Layout

    func setFrame(_ frame: Rect) {
        self.bounds.size = frame.size

        self.frameDidChange()
        self.setNeedsLayout()
    }

    open func frameDidChange() { }

    public func setNeedsLayout() {
        self.needsLayout = true
    }

    public func layoutIfNeeded() {
        if needsLayout {
            self.layoutSubviews()
            self.needsLayout = false
        }
    }

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

    @_spi(Internal)
    public func _buildMenu(with builder: UIMenuBuilder) {
        self.buildMenu(with: builder)

        for subview in subviews {
            subview._buildMenu(with: builder)
        }
    }

    open func buildMenu(with builder: UIMenuBuilder) { }

    open func layoutSubviews() {
        self.updateAutoresizingFrameIfNeeded()

        for subview in subviews {
            subview.layoutSubviews()
        }
    }

    open var minimumContentSize: Size {
        return .zero
    }

    public struct AutoresizingRule: OptionSet, Sendable {

        public var rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let flexibleWidth = AutoresizingRule(rawValue: 1 << 0)
        public static let flexibleHeight = AutoresizingRule(rawValue: 1 << 1)
    }

    public var autoresizingRules: AutoresizingRule = []

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

    open func viewDidMoveToParentView() { }

    open func viewDidMoveToWindow() { }

    open func viewWillMove(to window: UIWindow?) { }

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

    open func hitTest(_ point: Point, with event: InputEvent) -> UIView? {
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

    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    open func point(inside point: Point, with event: InputEvent) -> Bool {
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

    public func convert(_ point: Point, from view: UIView?) -> Point {
        return view?.convert(point, to: self) ?? point
    }

    open func canRespondToAction(_ event: InputEvent) -> Bool {
        return true
    }

    open func onTouchesEvent(_ touches: Set<TouchEvent>) { }

    open func onMouseEvent(_ event: MouseEvent) { }

    internal func onEvent(_ event: InputEvent) {
        switch event {
        case let event as MouseEvent:
            self.onMouseEvent(event)
        case is TouchEvent:
            let window = self.window?.id
            let touches = Input.shared.touches.filter({ $0.window == window })
            self.onTouchesEvent(touches)
        default:
            return
        }
    }

    private var eventsDisposeBag: Set<AnyCancellable> = []

    public func subscribe<Event: InputEvent>(to event: Event.Type, completion: @escaping (Event) -> Void) {
        self.window?.eventManager.subscribe(to: event, completion: completion)
            .store(in: &eventsDisposeBag)
    }

    func findFirstResponder(for event: InputEvent) -> UIView? {
        let responder: UIView?

        switch event {
        case let event as MouseEvent:
            let point = convert(event.mousePosition, to: self)
            responder = self.hitTest(point, with: event)
        case let event as TouchEvent:
            let point = event.location
            responder = self.hitTest(point, with: event)
        default:
            return nil
        }

        if responder?.canRespondToAction(event) == false {
            return nil
        }

        return responder
    }

    // MARK: - View Hierarchy

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

    open func removeFromParentView() {
        self.parentView?.removeSubview(self)
    }

    open func removeSubview(_ view: UIView) {
        guard let index = self.subviews.firstIndex(where: { $0 === view }) else { return }
        let deletedView = self.subviews.remove(at: index)
        view.viewWillMove(to: nil)
        view.window = nil
        deletedView.parentView = nil

        self.needsResortZPositionForChildren = true
    }

    func internalUpdate(_ deltaTime: TimeInterval) async {
        self.layoutIfNeeded()
        await self.update(deltaTime)

        for subview in self.subviews {
            await subview.internalUpdate(deltaTime)
            await subview.update(deltaTime)
        }
    }

    /// Called each frame
    open func update(_ deltaTime: TimeInterval) async { }
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
