//
//  ForEach.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.06.2024.
//

/// A structure that computes widgets on demand from an underlying collection of
/// identified data.
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content>: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let data: Data
    var content: (Data.Element) -> Content

    func makeWidgetNode(context: Context) -> WidgetNode {
        let nodes = data.compactMap { item in
            (content(item) as? WidgetNodeBuilder)?.makeWidgetNode(context: context)
        }


        return WidgetTransportContainerNode(content: self, nodes: nodes)
    }
}

extension ForEach where ID == Data.Element.ID, Content : Widget, Data.Element : Identifiable {

    /// Creates an instance that uniquely identifies and creates views across
    /// updates based on the identity of the underlying data.
    ///
    /// It's important that the `id` of a data element doesn't change unless you
    /// replace the data element with a new data element that has a new
    /// identity. If the `id` of a data element changes, the content view
    /// generated from that data element loses any current state and animations.
    ///
    /// - Parameters:
    ///   - data: The identified data that the ``ForEach`` instance uses to
    ///     create views dynamically.
    ///   - content: The widget builder that creates widgets dynamically.
    public init(_ data: Data, @WidgetBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
}

extension ForEach where Content: Widget {

    /// Creates an instance that uniquely identifies and creates widegts across
    /// updates based on the provided key path to the underlying data's
    /// identifier.
    ///
    /// It's important that the `id` of a data element doesn't change, unless
    /// AdaEngine considers the data element to have been replaced with a new data
    /// element that has a new identity. If the `id` of a data element changes,
    /// then the content view generated from that data element will lose any
    /// current state and animations.
    ///
    /// - Parameters:
    ///   - data: The data that the ``ForEach`` instance uses to create views
    ///     dynamically.
    ///   - id: The key path to the provided data's identifier.
    ///   - content: The widget builder that creates widgets dynamically.
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @WidgetBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
}

extension ForEach where Data == Range<Int>, ID == Int, Content : Widget {

    /// Creates an instance that computes widgetss on demand over a given constant
    /// range.
    ///
    /// The instance only reads the initial value of the provided `data` and
    /// doesn't need to identify widgetss across updates. To compute widgets on
    /// demand over a dynamic range, use ``ForEach/init(_:id:content:)``.
    ///
    /// - Parameters:
    ///   - data: A constant range.
    ///   - content: The widget builder that creates widgets dynamically.
    public init(_ data: Range<Int>, @WidgetBuilder content: @escaping (Int) -> Content) {
        self.data = data
        self.content = content
    }
}
