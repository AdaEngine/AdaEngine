@_spi(Scripting) import AdaECS
import Testing

@Suite("Dynamic runtime query")
struct DynamicQueryTests {
    @Test("Typed capability checks component identity and rejects an exhausted cursor")
    @MainActor func typedComponents() throws {
        DynamicQueryPosition.registerComponent()
        DynamicQueryTarget.registerComponent()
        let world = World()
        let entity = world.spawn { DynamicQueryPosition(value: 1) }
        var access = SystemAccessSet()
        access.addComponentWrite(DynamicQueryPosition.self)
        let query = DynamicQuery(where: .has(DynamicQueryPosition.self), components: [DynamicQueryPosition.identifier], access: access)
        query.update(from: world)
        let cursor = query.wrappedValue.makeCursor()
        #expect(cursor.readTyped(DynamicQueryPosition.self, componentAt: 0) == nil)
        #expect(cursor.advance())
        #expect(cursor.readTyped(DynamicQueryPosition.self, componentAt: 0)?.value == 1)
        #expect(cursor.readTyped(DynamicQueryTarget.self, componentAt: 0) == nil)
        var called = false
        #expect(!cursor.updateTyped(DynamicQueryTarget.self, componentAt: 0) { _ in called = true })
        #expect(!called)
        #expect(cursor.updateTyped(DynamicQueryPosition.self, componentAt: 0) { $0.value += 2 })
        #expect(world.get(DynamicQueryPosition.self, from: entity.id)?.value == 3)
        #expect(!cursor.advance())
        #expect(cursor.readTyped(DynamicQueryPosition.self, componentAt: 0) == nil)
        #expect(!cursor.updateTyped(DynamicQueryPosition.self, componentAt: 0) { $0.value = 100 })
    }

    @Test("Binds component columns and mutates rows across chunks")
    @MainActor
    func iteratesAndWritesComponentColumns() throws {
        DynamicQueryPosition.registerComponent()

        let world = World(name: "Dynamic query test")
        var entities: [Entity] = []
        for index in 0..<260 {
            entities.append(
                world.spawn {
                    DynamicQueryPosition(value: index)
                }
            )
        }
        entities[17].isActive = false

        var access = SystemAccessSet()
        access.addComponentWrite(DynamicQueryPosition.self)
        let query = DynamicQuery(
            where: .has(DynamicQueryPosition.self),
            components: [DynamicQueryPosition.identifier],
            access: access
        )
        query.update(from: world)

        let descriptor = try #require(
            DynamicQueryPosition.componentDescriptor.fields.first { $0.key == "value" }
        )
        let cursor = query.wrappedValue.makeCursor()
        var visited = 0
        while cursor.advance() {
            let value = try #require(cursor.read(componentAt: 0, field: descriptor)?.intValue)
            #expect(cursor.write(componentAt: 0, field: descriptor, value: .int(value + 1)))
            visited += 1
        }

        #expect(visited == 259)
        #expect(world.get(DynamicQueryPosition.self, from: entities[0].id)?.value == 1)
        #expect(world.get(DynamicQueryPosition.self, from: entities[17].id)?.value == 17)
        #expect(world.get(DynamicQueryPosition.self, from: entities[259].id)?.value == 260)
    }

    private func matches(_ query: DynamicQuery, in world: World) -> Set<Entity.ID> {
        query.update(from: world)
        let cursor = query.wrappedValue.makeCursor()
        var ids = Set<Entity.ID>()
        while cursor.advance() { ids.insert(cursor.entityID) }
        return ids
    }

    @Test("An optional component matches rows without it and reports its absence")
    @MainActor
    func optionalComponents() throws {
        DynamicQueryPosition.registerComponent()
        DynamicQueryTarget.registerComponent()
        let world = World(name: "Dynamic optional")
        let both = world.spawn { DynamicQueryPosition(value: 1); DynamicQueryTarget(id: 7) }
        let alone = world.spawn { DynamicQueryPosition(value: 2) }
        let targetOnly = world.spawn { DynamicQueryTarget(id: 9) }

        let query = DynamicQuery(
            where: .has(DynamicQueryPosition.self),
            components: [DynamicQueryPosition.identifier, DynamicQueryTarget.identifier],
            optionalComponents: [DynamicQueryTarget.identifier],
            access: SystemAccessSet()
        )
        query.update(from: world)
        let targetField = try #require(DynamicQueryTarget.componentDescriptor.fields.first { $0.key == "id" })
        let cursor = query.wrappedValue.makeCursor()
        var seen: [Entity.ID: Int?] = [:]
        while cursor.advance() {
            seen[cursor.entityID] = cursor.isPresent(componentAt: 1) ? cursor.read(componentAt: 1, field: targetField)?.intValue : .some(nil)
        }

        #expect(seen.count == 2)
        #expect(seen[both.id] == .some(7))
        #expect(seen[alone.id] == .some(nil))
        #expect(seen[targetOnly.id] == nil)
        #expect(!cursor.write(componentAt: 1, field: targetField, value: .int(1)))
    }

    @Test("Changed and added filters match only rows touched since the system last ran")
    @MainActor
    func tickFilters() throws {
        DynamicQueryPosition.registerComponent()
        let world = World(name: "Dynamic ticks")
        let first = world.spawn { DynamicQueryPosition(value: 1) }
        let second = world.spawn { DynamicQueryPosition(value: 2) }
        let access = SystemAccessSet()
        func query(changed: Bool = false, added: Bool = false) -> DynamicQuery {
            DynamicQuery(
                where: .has(DynamicQueryPosition.self),
                components: [DynamicQueryPosition.identifier],
                changedComponents: changed ? [DynamicQueryPosition.identifier] : [],
                addedComponents: added ? [DynamicQueryPosition.identifier] : [],
                access: access
            )
        }
        // A frame boundary: everything so far is old news.
        world.clearTrackers()
        world.clearTrackers()
        #expect(matches(query(changed: true), in: world).isEmpty)
        #expect(matches(query(added: true), in: world).isEmpty)
        #expect(matches(query(), in: world) == [first.id, second.id])

        let late = world.spawn { DynamicQueryPosition(value: 3) }
        #expect(matches(query(added: true), in: world) == [late.id])

        // Mutating one row through the query marks only that row changed.
        let writer = query()
        writer.update(from: world)
        let descriptor = try #require(DynamicQueryPosition.componentDescriptor.fields.first { $0.key == "value" })
        let cursor = writer.wrappedValue.makeCursor()
        while cursor.advance() {
            if cursor.entityID == second.id {
                #expect(cursor.write(componentAt: 0, field: descriptor, value: .int(99)))
            }
        }
        #expect(matches(query(changed: true), in: world).contains(second.id))
        #expect(!matches(query(changed: true), in: world).contains(first.id))

        world.clearTrackers()
        world.clearTrackers()
        #expect(matches(query(changed: true), in: world).isEmpty)
    }
}

@Component
private struct DynamicQueryPosition {
    var value: Int
}

@Component
private struct DynamicQueryTarget {
    var id: Int
}
