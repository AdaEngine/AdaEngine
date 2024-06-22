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

extension Never: Widget {
    public var body: Never {
        fatalError()
    }
}

extension WidgetTuple: WidgetNodeBuilder {
    func makeWidgetNode(context: Context) -> WidgetNode {
        let node = WidgetContainerNode(
            content: self,
            buildNodesBlock: {
                // swiftlint:disable:next syntactic_sugar
                let widgets = Array<any Widget>.fromTuple(value)
                
                return widgets.compactMap {
                    var nodeBuilder: WidgetNodeBuilder? = ($0 as? WidgetNodeBuilder)

                    var body: (any Widget)? = $0
                    while nodeBuilder == nil {
                        let newBody = body?.body

                        if let builder = newBody as? WidgetNodeBuilder {
                            nodeBuilder = builder
                            break
                        } else {
                            body = newBody
                        }
                    }


                    return nodeBuilder?.makeWidgetNode(context: context)
                }
            }
        )
        
        node.storages = WidgetStorageReflection.findStorages(in: self, node: node)
        return node
    }
}

extension Array {
    static func fromTuple<Tuple>(_ tuple: Tuple) -> [Element] {
        return Mirror(reflecting: tuple).children.compactMap { $0.value as? Element }
    }
}

@MainActor
enum WidgetStorageReflection {
    static func findStorages<T>(in value: T, node: WidgetNode) -> [UpdatablePropertyStorage] {
        let mirror = Mirror(reflecting: value)
        
        return mirror.children.compactMap { label, property in
            let storage = (property as? PropertyStoragable)?._storage
            storage?.propertyName = label ?? ""
            storage?.widgetNode = node
            return storage
        }
    }
}
