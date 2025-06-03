//
//  Resource.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.05.2025.
//

import Foundation

/// The singleton resource that passed to the ecs world.
/// Only one instance of the resource is allowed in the world.
public protocol Resource: Sendable { }

/// Init the object from a world
public protocol WorldInitable: Sendable {
    init(from world: World)
}

// TODO: (Vlad) Add components list to editor and generate file with registered components.
// TODO: (Vlad) We can think about `swift_getMangledTypeName` and `swift_getTypeByMangledNameInContext`

// We should register our resources in engine, because we should initiate them in memory
// This can help to avoid registering resources during runtime.
extension Resource {

    /// Call this method to add resource to the engine.
    /// When engine will initiate resource from scene file, it will try to find
    /// resource in registered list.
    /// Otherwise resource will not be initialized.
    @MainActor
    public static func registerResource() {
        ResourceStorage.addResource(self)
    }
}

extension Resource {
    
    /// Return name with Bundle -> AdaEngine.ResourceName
    /// - Note: We use reflection, we paid a huge cost for that.
    static var swiftName: String {
        return String(reflecting: self)
    }
    
    /// Return identifier of resource based on Resource.Type
    @inline(__always) static var identifier: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}

enum ResourceStorage {
    
    nonisolated(unsafe) private static var registeredResources: [String: Resource.Type] = [:]
    
    /// Return registered resource or try to find it by NSClassFromString (works only for objc runtime)
    static func getRegisteredResource(for name: String) -> Resource.Type? {
        return self.registeredResources[name] ?? (NSClassFromString(name) as? Resource.Type)
    }
    
    static func addResource<T: Resource>(_ type: T.Type) {
        self.registeredResources[T.swiftName] = type
    }
}
