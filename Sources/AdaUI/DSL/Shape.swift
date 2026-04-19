//
//  Shape.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.07.2024.
//

import AdaUtils
import Math

/// A type that resolves into a concrete fill or stroke color for shapes.
public protocol ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color
}

extension Color: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> Color {
        self
    }
}

/// A set of stroke attributes to apply when stroking a shape.
public struct StrokeStyle: Sendable, Equatable {
    public var lineWidth: Float

    public init(lineWidth: Float = 1) {
        self.lineWidth = lineWidth
    }
}

/// A protocol that defines a shape.
public protocol Shape: View {
    /// The path of the shape.
    ///
    /// - Parameter rect: The rect of the shape.
    /// - Returns: The path of the shape.
    func path(in rect: Rect) -> Path

    /// The size that fits the shape.
    ///
    /// - Parameter proposal: The proposed size.
    /// - Returns: The size that fits the shape.
    func sizeThatFits(_ proposal: ProposedViewSize) -> Size
}

extension Shape {
    public var body: some View {
        _ShapeView(shape: self)
    }
}

enum ShapeRenderMode: Sendable, Equatable {
    case legacy
    case fill(Color)
    case stroke(Color, StrokeStyle)
}

struct _ShapeView<S: Shape>: View, ViewNodeBuilder {

    let shape: S
    var body: Never { fatalError() }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        ShapeViewNode(shape: shape, renderMode: .legacy, content: self)
    }
}

struct _ShapeStyledView<S: Shape, Style: ShapeStyle>: View, ViewNodeBuilder {

    enum Kind: Sendable, Equatable {
        case fill
        case stroke(StrokeStyle)
    }

    let shape: S
    let style: Style
    let kind: Kind
    var body: Never { fatalError() }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let color = style.resolve(in: context.environment)
        let renderMode: ShapeRenderMode

        switch kind {
        case .fill:
            renderMode = .fill(color)
        case let .stroke(strokeStyle):
            renderMode = .stroke(color, strokeStyle)
        }

        return ShapeViewNode(shape: shape, renderMode: renderMode, content: self)
    }
}

/// A circle shape.
public struct CircleShape: Shape {
    public init() {}

    public func path(in rect: Rect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        return path
    }
}

/// A rectangle shape.
public struct RectangleShape: Shape {
    public init() {}

    public func path(in rect: Rect) -> Path {
        var path = Path()
        path.addRect(rect)
        return path
    }
}

/// A capsule shape — a rectangle with fully rounded ends.
public struct CapsuleShape: Shape {
    public init() {}

    public func path(in rect: Rect) -> Path {
        var path = Path()
        path.addRoundedRect(rect, cornerRadius: min(rect.width, rect.height) * 0.5)
        return path
    }
}

/// A rectangle shape with a uniform corner radius.
public struct RoundedRectangleShape: Shape {
    public var cornerRadius: Float

    public init(cornerRadius: Float) {
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: Rect) -> Path {
        var path = Path()
        path.addRoundedRect(rect, cornerRadius: cornerRadius)
        return path
    }
}

/// A shape view node.
@MainActor
class ShapeViewNode<S: Shape>: ViewNode {

    private var shape: S
    private var renderMode: ShapeRenderMode
    private var path: Path = Path()

    /// Initialize a new shape view node.
    ///
    /// - Parameters:
    ///   - shape: The shape.
    ///   - content: The content.
    init<Content: View>(shape: S, renderMode: ShapeRenderMode, content: Content) {
        self.shape = shape
        self.renderMode = renderMode
        super.init(content: content)
    }

    /// Perform the layout of the shape view node.
    override func performLayout() {
        super.performLayout()

        self.path = self.shape.path(in: self.frame)
    }

    /// Draw the shape view node.
    ///
    /// - Parameter context: The context.
    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = self.environment
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        switch renderMode {
        case .legacy:
            context.draw(path)
        case let .fill(color):
            context.fill(path, with: color)
        case let .stroke(color, style):
            context.stroke(path, with: color, style: style)
        }
    }

    /// Update the shape view node from a new node.
    ///
    /// - Parameter newNode: The new node.
    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let otherNode = newNode as? Self else {
            return
        }

        self.shape = otherNode.shape
        self.renderMode = otherNode.renderMode
    }

    /// The size that fits the shape view node.
    ///
    /// - Parameter proposal: The proposed size.
    /// - Returns: The size that fits the shape view node.
    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return shape.sizeThatFits(proposal)
    }
}

public extension Shape {
    func fill<S: ShapeStyle>(_ style: S) -> some View {
        _ShapeStyledView(shape: self, style: style, kind: .fill)
    }

    func stroke<S: ShapeStyle>(_ style: S, style strokeStyle: StrokeStyle = .init()) -> some View {
        _ShapeStyledView(shape: self, style: style, kind: .stroke(strokeStyle))
    }

    func stroke<S: ShapeStyle>(_ style: S, lineWidth: Float = 1) -> some View {
        self.stroke(style, style: StrokeStyle(lineWidth: lineWidth))
    }

    /// The size that fits the shape.
    ///
    /// - Parameter proposal: The proposed size.
    /// - Returns: The size that fits the shape.
    func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return proposal.replacingUnspecifiedDimensions()
    }
}

extension Shape where Self == CapsuleShape {
    public static var capsule: CapsuleShape { CapsuleShape() }
}

extension Shape where Self == CircleShape {
    public static var circle: CircleShape { CircleShape() }
}

extension Shape where Self == RectangleShape {
    public static var rectangle: RectangleShape { RectangleShape() }
}

extension Shape where Self == RoundedRectangleShape {
    public static func rect(cornerRadius: Float) -> RoundedRectangleShape {
        RoundedRectangleShape(cornerRadius: cornerRadius)
    }
}
