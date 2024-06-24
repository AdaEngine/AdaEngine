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

public extension Widget {
    func padding(_ edges: Edge.Set = .all, _ length: Float?) -> some Widget {
        self.modifier(
            PaddingWidgetModifier(
                edges: edges,
                insets: length.map { EdgeInsets(top: $0, leading: $0, bottom: $0, trailing: $0) } ?? EdgeInsets(),
                content: self
            )
        )
    }

    func padding(_ insets: EdgeInsets) -> some Widget {
        self.modifier(PaddingWidgetModifier(edges: .all, insets: insets, content: self))
    }

    func padding(_ length: Float) -> some Widget {
        self.modifier(
            PaddingWidgetModifier(
                edges: .all,
                insets: EdgeInsets(top: length, leading: length, bottom: length, trailing: length),
                content: self
            )
        )
    }
}

struct PaddingWidgetModifier<Content: Widget>: WidgetModifier, WidgetNodeBuilder {
    typealias Body = Never
    
    let edges: Edge.Set
    let insets: EdgeInsets
    let content: Content

    func makeWidgetNode(context: Context) -> WidgetNode {
        PaddingModifierWidgetNode(
            edges: edges,
            insets: insets,
            content: content,
            context: context
        )
    }
}

final class PaddingModifierWidgetNode: WidgetModifierNode {

    let edges: Edge.Set
    let insets: EdgeInsets

    init<Content>(edges: Edge.Set, insets: EdgeInsets, content: Content, context: WidgetNodeBuilderContext) where Content : Widget {
        self.edges = edges
        self.insets = insets
        super.init(content: content, context: context)
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

        for node in self.nodes {
            node.place(
                in: origin,
                anchor: .topLeading,
                proposal: proposal
            )
        }

    }
}
