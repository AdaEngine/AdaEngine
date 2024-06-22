//
//  Layout.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

@MainActor
public protocol Layout {
    associatedtype Cache = Void
    typealias Subviews = LayoutSubviews

    func sizeThatFits(_ proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Size

    func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache)

    func makeCache(subviews: Subviews) -> Cache
}

public extension Layout where Cache == Void {
    func makeCache(subviews: Subviews) -> Cache {
        return
    }
}

extension Layout {
    public func callAsFunction<Content: Widget>(@WidgetBuilder _ content: @escaping () -> Content) -> some Widget {
        CustomLayoutContainer(layout: self, content: content)
    }
}

public struct LayoutSubview: Equatable {

    let node: WidgetNode

    public static func == (lhs: LayoutSubview, rhs: LayoutSubview) -> Bool {
        return true
    }

    @MainActor
    public func place(at point: Point, proposal: ProposedViewSize) {
        self.node.frame.origin = point
        self.node.frame.size = self.sizeThatFits(proposal)
    }

    @MainActor
    public func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return self.node.sizeThatFits(proposal)
    }
}

public struct LayoutSubviews: Sequence, Collection {
    public func index(after i: Int) -> Int {
        return self.data.index(after: i)
    }

    public subscript(position: Int) -> LayoutSubview {
        _read {
            yield self.data[position]
        }
    }

    public typealias Element = LayoutSubview
    public typealias Iterator = IndexingIterator<[Element]>

    let data: [Element]

    init(_ data: [Element]) {
        self.data = data
    }

    public var startIndex: Int {
        data.startIndex
    }

    public var endIndex: Int {
        data.endIndex
    }

    public func makeIterator() -> IndexingIterator<[Element]> {
        return data.makeIterator()
    }
}

// MARK: - Internal

struct CustomLayoutContainer<T: Layout, Content: Widget>: Widget, WidgetNodeBuilder {

    let layout: T
    let content: () -> Content

    var body: Never {
        fatalError()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        CustomLayoutWidgetContainer(layout: layout, content: self, buildNodesBlock: {
            let containerNode = (self.content() as? WidgetNodeBuilder)?.makeWidgetNode(context: context) as? WidgetContainerNode

            guard let containerNode else {
                return []
            }

            return containerNode.nodes
        })
    }
}

final class CustomLayoutWidgetContainer<T: Layout>: WidgetContainerNode {
    let layout: T
    private var cache: T.Cache!
    private var subviews: LayoutSubviews = LayoutSubviews([])

    init(layout: T, content: any Widget, buildNodesBlock: @escaping WidgetContainerNode.BuildContentBlock) {
        self.layout = layout
        super.init(content: content, buildNodesBlock: buildNodesBlock)
    }

    override func invalidateContent() {
        super.invalidateContent()

        self.subviews = LayoutSubviews(self.nodes.map { LayoutSubview(node: $0) })
        self.cache = layout.makeCache(subviews: self.subviews)
    }

    override func performLayout() {
        super.performLayout()

        layout.placeSubviews(
            in: self.frame,
            proposal: ProposedViewSize(width: self.frame.width, height: self.frame.height),
            subviews: subviews,
            cache: &cache
        )
    }

    override func sizeThatFits(_ proposal: ProposedViewSize, usedByParent: Bool = false) -> Size {
        return layout.sizeThatFits(proposal, subviews: self.subviews, cache: &cache)
    }
}
