//
//  WidgetTuple.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct WidgetTuple<Content>: Widget {
    
    public let value: Content
    
    public init(value: Content) {
        self.value = value
    }
    
    public var body: Never {
        fatalError()
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

extension WidgetTuple: WidgetNodeBuilder {
    func makeWidgetNode(context: Context) -> WidgetNode {
        // swiftlint:disable:next syntactic_sugar
        let widgets = Array<any Widget>.fromTuple(value)
        let nodes = widgets.compactMap { WidgetNodeBuilderUtils.findNodeBuilder(in: $0)?.makeWidgetNode(context: context) }

        return WidgetTransportContainerNode(
            content: self,
            nodes: nodes
        )
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
    static func findNodeBuilder(in content: any Widget) -> WidgetNodeBuilder? {
        var nodeBuilder: WidgetNodeBuilder? = (content as? WidgetNodeBuilder)
        
        var body: any Widget = content
        while nodeBuilder == nil {
            let newBody = body.body
            
            if let builder = newBody as? WidgetNodeBuilder {
                nodeBuilder = builder
                break
            } else {
                body = newBody
            }
        }
        
        return nodeBuilder
    }
    
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
