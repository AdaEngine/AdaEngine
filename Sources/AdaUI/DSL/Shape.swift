//
//  Shape.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.07.2024.
//

import Math

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

struct _ShapeView<S: Shape>: View, ViewNodeBuilder {

    let shape: S
    var body: Never { fatalError() }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        ShapeViewNode(shape: shape, content: self)
    }
}

/// A circle shape.
public struct CircleShape: Shape {
    public func path(in rect: Rect) -> Path {
        Path { _ in
            // FIXME: Make it
        }
    }
}

/// A rectangle shape.
public struct RectangleShape: Shape {
    public func path(in rect: Rect) -> Path {
        var path = Path()
        path.addRect(rect)
        return path
    }
}

/// A shape view node.
@MainActor
class ShapeViewNode<S: Shape>: ViewNode {

    private var shape: S
    private var path: Path = Path()

    /// Initialize a new shape view node.
    ///
    /// - Parameters:
    ///   - shape: The shape.
    ///   - content: The content.
    init<Content: View>(shape: S, content: Content) {
        self.shape = shape
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
        context.draw(path)
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

    /// The size that fits the shape.
    ///
    /// - Parameter proposal: The proposed size.
    /// - Returns: The size that fits the shape.
    func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return proposal.replacingUnspecifiedDimensions()
    }
}
