//
//  World+Storages.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 20.11.2025.
//

import AdaUtils

extension World {
    struct ComponentsStorage: Sendable {
        struct RequiredComponentInfo: Sendable {
            let id: ComponentId
            let constructor: @Sendable () -> any Component
        }

        private var components: [ComponentId] = []
        private var componentsIds: [ObjectIdentifier: ComponentId] = [:]
        private var requiredComponents: [ComponentId: [RequiredComponentInfo]] = [:]

        mutating func registerRequiredComponent<T: Component>(
            for component: ComponentId,
            requiredComponentId: ComponentId,
            constructor: @Sendable @escaping () -> T
        ) {
            var requiredComponents = self.requiredComponents[component] ?? []
            let newInfo = RequiredComponentInfo(
                id: requiredComponentId,
                constructor: constructor
            )
            if let index = requiredComponents.firstIndex(where: { $0.id == requiredComponentId }) {
                requiredComponents[index] = newInfo
            } else {
                requiredComponents.append(newInfo)
            }

            self.requiredComponents[component] = requiredComponents
        }

        @discardableResult
        mutating func registerComponent() -> ComponentId {
            let id = ComponentId(id: components.count)
            self.components.append(id)
            return id
        }

        mutating func getOrRegisterComponent<T: Component>(
            _ component: T.Type
        ) -> ComponentId {
            let id = ObjectIdentifier(T.self)
            if let componentId = self.componentsIds[id] {
                return componentId
            }
            let componentId = registerComponent()
            componentsIds[id] = componentId
            return componentId
        }

        @inline(__always)
        func getComponentId<T: Component>(_ component: T.Type) -> ComponentId? {
            self.componentsIds[ObjectIdentifier(T.self)]
        }

        func getRequiredComponents<T: Component>(for component: T) -> [RequiredComponentInfo] {
            getComponentId(T.self).flatMap { self.requiredComponents[$0] } ?? []
        }

        func getRequiredComponents<T: Component>(for component: T.Type) -> [RequiredComponentInfo] {
            getComponentId(T.self).flatMap { self.requiredComponents[$0] } ?? []
        }
    }
}

extension World {
    struct Resources: Sendable {
        @safe
        struct ResourceData: @unchecked Sendable {
            let pointer: BlobArray
            let resourceType: any Resource.Type
            let addedTick: UnsafeBox<Tick>
            let changedTick: UnsafeBox<Tick>

            var erasedResource: any Resource {
                pointer.get(at: 0, as: resourceType)
            }

            func getWithTick<T: Resource>(
                _ type: T.Type
            ) -> (
                pointer: UnsafeMutablePointer<T>,
                addedTick: UnsafeBox<Tick>,
                changedTick: UnsafeBox<Tick>
            ) {
                unsafe (
                    pointer.getMutablePointer(at: 0, as: T.self),
                    addedTick,
                    changedTick
                )
            }
        }

        private var resources: [ComponentId] = []
        private var resourceIds: [ObjectIdentifier: ComponentId] = [:]
        private var resourceData: SparseSet<ComponentId, ResourceData> = [:]

        func getResource<T: Resource>(_ resourceType: T.Type) -> T? {
            guard let componentId = self.resourceIds[T.identifier],
                  let resource = self.resourceData[componentId] else {
                return nil
            }
            return resource.pointer.get(at: 0, as: T.self)
        }

        func contains<T: Resource>(_ type: T.Type) -> Bool {
            if let componentId = self.resourceIds[T.identifier] {
                return self.resourceData.contains(componentId)
            }
            return false
        }

        func getResources() -> Array<any Resource> {
            self.resourceData.map { $0.erasedResource }
        }

        mutating func getOrRegisterResource(
            _ resource: any Resource.Type
        ) -> ComponentId {
            let id = resource.identifier
            if let componentId = self.resourceIds[id] {
                return componentId
            }
            return registerResource(resource, id: id)
        }

        mutating func insertResource<T: Resource>(
            _ resource: consuming T,
            tick: Tick
        ) {
            let componentId = self.getOrRegisterResource(T.self)
            self.resourceData[componentId] = makeResourceData(resource, tick: tick)
        }

        @discardableResult
        mutating func registerComponent() -> ComponentId {
            let id = ComponentId(id: resources.count)
            self.resources.append(id)
            return id
        }

        func getResourceId<T: Resource>(for type: T.Type) -> ComponentId? {
            self.resourceIds[ObjectIdentifier(type)]
        }

        func getPointer(for resourceId: ComponentId) -> UnsafeMutableRawPointer? {
            unsafe self.resourceData[resourceId]?.pointer.buffer.pointer.baseAddress
        }

        mutating func registerResource<T: Resource>(
            _ resource: T.Type,
            id: ObjectIdentifier
        ) -> ComponentId {
            Task { @MainActor in
                T.registerResource()
            }
            let componentId = registerComponent()
            self.resourceIds[id] = componentId
            return componentId
        }

        mutating func removeResource<T: Resource>(_ resource: T.Type) {
            let id = ObjectIdentifier(T.self)
            guard let componentId = self.resourceIds[id] else {
                return
            }
            self.resourceData[componentId] = nil
            self.resourceIds[id] = nil
        }

        func getResourceData<T: Resource>(_ resource: T.Type) -> ResourceData? {
            guard let componentId = self.resourceIds[T.identifier],
                  let resource = self.resourceData[componentId] else {
                return nil
            }
            return resource
        }

        mutating func clear() {
            self.resources.removeAll()
            self.resourceIds.removeAll()
            self.resourceData.removeAll()
        }

        private func makeResourceData<T: Resource>(_ resource: consuming T, tick: Tick) -> ResourceData {
            let array = unsafe BlobArray(count: 1, of: T.self) { pointer, count in
                unsafe pointer.baseAddress?
                    .assumingMemoryBound(to: T.self)
                    .deinitialize(count: count)
            }
            array.insert(resource, at: 0)
            return ResourceData(
                pointer: array,
                resourceType: T.self,
                addedTick: UnsafeBox(tick),
                changedTick: UnsafeBox(tick)
            )
        }
    }
}
