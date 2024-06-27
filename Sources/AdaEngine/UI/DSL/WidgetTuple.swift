//
//  WidgetTuple.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct WidgetTuple<Content>: Widget {
    
    public typealias Body = Never

    public let value: Content
    
    public init(value: Content) {
        self.value = value
    }

    public static func _makeView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetInputs) -> _WidgetOutputs {
        let listInputs = _WidgetListInputs(input: inputs)
        let outputs = Self._makeListView(view, inputs: listInputs)
        
        let node = LayoutWidgetContainerNode(
            layout: inputs.layout,
            content: view.value,
            nodes: outputs.outputs.map { $0.node }
        )

        return _WidgetOutputs(node: node)
    }

    public static func _makeListView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetListInputs) -> _WidgetListOutputs {
        let outputs = Array<any Widget>.fromTuple(view.value.value).map {
            Self.makeView($0, inputs: inputs.input)
        }
        return _WidgetListOutputs(outputs: outputs)
    }

    private static func makeView<V: Widget>(_ view: V, inputs: _WidgetInputs) -> _WidgetOutputs {
        V._makeView(_WidgetGraphNode(value: view), inputs: inputs)
    }
}

extension Widget where Body == Never {
    public var body: Never {
        fatalError()
    }
}

extension Never: Widget {
    public var body: Never {
        fatalError()
    }
}

/// Indicates that this container just move nodes from one container to another
final class WidgetTransportContainerNode: WidgetContainerNode { }

extension Array {
    static func fromTuple<Tuple>(_ tuple: Tuple) -> [Element] {
        return Mirror(reflecting: tuple).children.compactMap { $0.value as? Element }
    }
}

@MainActor
enum WidgetNodeBuilderUtils {
    static func findPropertyStorages<T>(in value: T, node: WidgetNode) -> [UpdatablePropertyStorage] {
        let mirror = Mirror(reflecting: value)
        
        return mirror.children.compactMap { label, property in
            let storage = (property as? PropertyStoragable)?._storage
            storage?.propertyName = label ?? ""
            storage?.widgetNode = node
            return storage
        }
    }
}

struct PropertyStoragableWidgetNodeBuilder<Content: Widget>: WidgetNodeBuilder {
    let content: Content

    func makeWidgetNode(context: Context) -> WidgetNode {
        PropertyStoragableWidgetNode(content: content)
    }
}

class PropertyStoragableWidgetNode: WidgetContainerNode {

    var storages: [UpdatablePropertyStorage] = []
    var rootContent: any Widget

    override init<Content>(content: Content) where Content : Widget {
        self.rootContent = content
        super.init(content: content.body)
        self.invalidateContent()
        self.storages = WidgetNodeBuilderUtils.findPropertyStorages(in: content, node: self)
    }

}

