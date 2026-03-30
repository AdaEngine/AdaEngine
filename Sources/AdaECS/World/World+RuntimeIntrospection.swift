import Foundation

public extension World {
    func getComponents(for entity: Entity.ID) -> [(typeName: String, component: any Component)] {
        guard let location = self.entities.entities[entity] else {
            return []
        }

        let chunk = self.archetypes
            .archetypes[location.archetypeId]
            .chunks
            .chunks[location.chunkIndex]

        return chunk.getComponents(for: entity).map { _, component in
            (String(reflecting: type(of: component)), component)
        }
    }

    func getComponent(named typeName: String, from entity: Entity.ID) -> (any Component)? {
        guard let componentType = RuntimeTypeRegistry.componentType(named: typeName) else {
            return nil
        }
        guard let location = self.entities.entities[entity] else {
            return nil
        }

        let chunk = self.archetypes
            .archetypes[location.archetypeId]
            .chunks
            .chunks[location.chunkIndex]

        return chunk.getComponents(for: entity).first { id, _ in
            id == componentType.identifier
        }?.1
    }

    func hasComponent(named typeName: String, in entity: Entity.ID) -> Bool {
        guard let componentType = RuntimeTypeRegistry.componentType(named: typeName) else {
            return false
        }
        return self.has(componentType.identifier, in: entity)
    }

    func getResource(named typeName: String) -> (any Resource)? {
        guard let resourceType = RuntimeTypeRegistry.resourceType(named: typeName) else {
            return nil
        }
        return self.resources.getResource(resourceType)
    }
}
