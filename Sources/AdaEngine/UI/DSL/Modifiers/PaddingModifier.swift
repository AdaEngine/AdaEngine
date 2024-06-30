//
//  PaddingModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

public enum Edge: UInt8, Equatable, Hashable {
    case top
    case bottom
    case leading
    case trailing
}

extension Edge {
    public struct Set: OptionSet {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let top = Set(rawValue: 1 << 0)
        public static let leading = Set(rawValue: 1 << 1)
        public static let bottom = Set(rawValue: 1 << 2)
        public static let trailing = Set(rawValue: 1 << 3)

        public static let all: Set = [.top, .leading, .bottom, .trailing]
        public static let horizontal: Set = [.leading, .trailing]
        public static let vertical: Set = [.top, .bottom]

        public init(_ edge: Edge) {
            switch edge {
            case .top: 
                self = .top
            case .leading:
                self = .leading
            case .bottom:
                self = .bottom
            case .trailing:
                self = .trailing
            }
        }
    }
}

public struct EdgeInsets: Equatable, Hashable {
    public var top: Float
    public var leading: Float
    public var bottom: Float
    public var trailing: Float

    public init() {
        self.top = 0
        self.leading = 0
        self.bottom = 0
        self.trailing = 0
    }

    public init(top: Float, leading: Float, bottom: Float, trailing: Float) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

}

public extension View {
    func padding(_ edges: Edge.Set = .all, _ length: Float?) -> some View {
        self.modifier(
            PaddingViewModifier(
                edges: edges,
                insets: length.map { EdgeInsets(top: $0, leading: $0, bottom: $0, trailing: $0) } ?? EdgeInsets(),
                content: self
            )
        )
    }

    func padding(_ insets: EdgeInsets) -> some View {
        self.modifier(PaddingViewModifier(edges: .all, insets: insets, content: self))
    }

    func padding(_ length: Float) -> some View {
        self.modifier(
            PaddingViewModifier(
                edges: .all,
                insets: EdgeInsets(top: length, leading: length, bottom: length, trailing: length),
                content: self
            )
        )
    }
}

struct PaddingViewModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never
    
    let edges: Edge.Set
    let insets: EdgeInsets
    let content: Content

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        PaddingModifierViewNode(
            edges: edges,
            insets: insets,
            content: content,
            node: inputs.makeNode(from: content)
        )
    }
}

final class PaddingModifierViewNode: ViewModifierNode {

    let edges: Edge.Set
    let insets: EdgeInsets

    init<Content>(edges: Edge.Set, insets: EdgeInsets, content: Content, node: ViewNode) where Content : View {
        self.edges = edges
        self.insets = insets
        super.init(contentNode: node, content: content)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        var vertical = Float.zero
        var horizontal = Float.zero

        if self.edges.contains(.leading) {
            horizontal += insets.leading
        }
        if self.edges.contains(.trailing) {
            horizontal += insets.trailing
        }
        if self.edges.contains(.top) {
            vertical += insets.top
        }
        if self.edges.contains(.bottom) {
            vertical += insets.bottom
        }

        var proposalSize = proposal
        if let width = proposal.width {
            proposalSize.width = max(width - horizontal, 0)
        }

        if let height = proposal.height {
            proposalSize.height = max(height - vertical, 0)
        }

        let size = super.sizeThatFits(proposalSize)

        return Size(
            width: max(size.width + horizontal, 0),
            height: max(size.height + vertical, 0)
        )
    }

    override func performLayout() {
        var minX = self.frame.minX
        var maxX = self.frame.maxX
        var minY = self.frame.minY
        var maxY = self.frame.maxY

        if self.edges.contains(.leading) {
            minX += insets.leading
        }
        if self.edges.contains(.trailing) {
            maxX -= insets.trailing
        }
        if self.edges.contains(.top) {
            minY += insets.top
        }
        if self.edges.contains(.bottom) {
            maxY -= insets.bottom
        }

        let origin = Point(x: minX, y: minY)
        let width = max(maxX - minX, 0)
        let height = max(maxY - minY, 0)

        let proposal = ProposedViewSize(width: width, height: height)
        contentNode.place(
            in: origin,
            anchor: .topLeading,
            proposal: proposal
        )
    }
}
