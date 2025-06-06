//
//  Graph.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 27.06.2024.
//

import AdaUtils
import Foundation

@MainActor
final class ViewGraph {

    private static var viewsTypeToDebug: Set<ObjectIdentifier> = []

    static func registerViewToDebugUpdate<V: View>(_ type: V.Type) {
        viewsTypeToDebug.insert(ObjectIdentifier(V.self))
    }

    static func shouldNotifyAboutChanges<V: View>(_ content: V.Type) -> Bool {
        viewsTypeToDebug.contains(ObjectIdentifier(V.self))
    }
}

@MainActor
public struct _ViewInputs {
    var parentNode: ViewNode?
    var layout: any Layout = VStackLayout()
    var environment: EnvironmentValues
    var propertyStorages: [PropertyStoragable] = []
    var gestures: [_Gesture] = []

    func makeNode<T: View>(from content: T) -> ViewNode {
        T._makeView(_ViewGraphNode(value: content), inputs: self).node
    }

    /// Method can find and register ``State``, ``Binding``, ``Environment`` property wrappers
    /// in new _ViewInputs value.
    func resolveStorages<T>(in content: T) -> _ViewInputs {
        var newSelf = self
        let mirror = Mirror(reflecting: content)

        let storages = mirror.children.compactMap { label, property -> PropertyStoragable? in
            guard let storagable = property as? PropertyStoragable else {
                return nil
            }

            if let env = storagable.storage as? ViewContextStorage {
                env.values = self.environment
            }

            let storage = storagable.storage
            storage.propertyName = label ?? ""
            return storagable
        }
        newSelf.propertyStorages.append(contentsOf: storages)
        return newSelf
    }

    /// Inflate all found storages to view node.
    @MainActor
    func registerNodeForStorages(_ node: ViewNode) {
        for storage in propertyStorages {
            storage.storage.registerNodeToUpdate(node)
        }
    }
}

/// Contains resolved view node.
@MainActor
public struct _ViewOutputs {
    let node: ViewNode
}

/// Contains information for make list of views.
public struct _ViewListInputs {
    let input: _ViewInputs
}

/// Contains list of resolved view nodes.
public struct _ViewListOutputs {
    var outputs: [_ViewOutputs]
}

public struct _ViewGraphNode<Value>: Equatable {

    let value: Value

    init(value: Value) {
        self.value = value
    }

    subscript<U>(keyPath: KeyPath<Value, U>) -> _ViewGraphNode<U> {
        _ViewGraphNode<U>(value: self.value[keyPath: keyPath])
    }

    public static func == (lhs: _ViewGraphNode<Value>, rhs: _ViewGraphNode<Value>) -> Bool where Value: Equatable {
        lhs.value == rhs.value
    }

    public static func == (lhs: _ViewGraphNode<Value>, rhs: _ViewGraphNode<Value>) -> Bool {
        // if its pod, we can compare it together using memcmp.
        if _isPOD(Value.self) {
            let memSize = MemoryLayout<Value>.size
            return withUnsafePointer(to: lhs.value) { lhsPtr in
                withUnsafePointer(to: rhs.value) { rhsPtr in
                    memcmp(lhsPtr, rhsPtr, memSize) == 0
                }
            }
        } else {
            // For another hand we should compare it using reflection or smth else
            return false
        }
    }
}
