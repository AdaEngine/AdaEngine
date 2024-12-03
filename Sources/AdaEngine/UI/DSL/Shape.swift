//
//  Shape.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.07.2024.
//

import Math

public protocol Shape: View {
    func path(in rect: Rect) -> Path
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

public struct CircleShape: Shape {
    public func path(in rect: Rect) -> Path {
        Path { _ in
            // FIXME: Make it
        }
    }
}

public struct RectangleShape: Shape {
    public func path(in rect: Rect) -> Path {
        var path = Path()
        path.addRect(rect)
        return path
    }
}

@MainActor
class ShapeViewNode<S: Shape>: ViewNode {

    private var shape: S
    private var path: Path = Path()

    init<Content: View>(shape: S, content: Content) {
        self.shape = shape
        super.init(content: content)
    }

    override func performLayout() {
        super.performLayout()

        self.path = self.shape.path(in: self.frame)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = self.environment
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        context.draw(path)
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let otherNode = newNode as? Self else {
            return
        }

        self.shape = otherNode.shape
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return shape.sizeThatFits(proposal)
    }
}

public extension Shape {
    func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return proposal.replacingUnspecifiedDimensions()
    }
}
