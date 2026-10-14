@_spi(Scripting) import AdaECS
import Foundation
import Math
import Testing

@Suite("Dynamic component access", .serialized)
struct DynamicComponentTests {
    @Test("Removes, mutates, and codes a runtime component without naming its type")
    @MainActor
    func runtimeComponent() throws {
        let descriptor = RuntimeComponentDescriptor(
            stableID: "tests.dynamic.body",
            name: "DynamicBody",
            fieldNames: ["count", "position", "mode"],
            fieldKinds: [.int, .vector3, .enumeration(["idle", "moving"])],
            defaultValues: [.int(1), .array([.double(0), .double(0), .double(0)]), .string("idle")]
        )
        let world = World(name: "Dynamic runtime component")
        world.registerRuntimeComponent(descriptor)
        let entity = world.spawn("Target")

        #expect(world.dynamicComponentID(named: "DynamicBody") == descriptor.componentID)
        #expect(world.dynamicComponentID(named: "tests.dynamic.body") == descriptor.componentID)
        #expect(world.insertDynamicComponent(named: "tests.dynamic.body", fields: ["count": .int(7), "mode": .string("moving")], into: entity.id))
        #expect(world.dynamicComponentPayload(named: "DynamicBody", of: entity.id)?["count"] == .int(7))
        #expect(world.dynamicComponentPayload(named: "DynamicBody", of: entity.id)?["mode"] == .string("moving"))

        #expect(world.setDynamicComponentField(named: "DynamicBody", field: "position", to: .array([.int(1), .int(2), .int(3)]), in: entity.id))
        #expect(world.dynamicComponentPayload(named: "DynamicBody", of: entity.id)?["position"] == .array([.double(1), .double(2), .double(3)]))
        #expect(!world.setDynamicComponentField(named: "DynamicBody", field: "mode", to: .string("flying"), in: entity.id))
        #expect(!world.setDynamicComponentField(named: "DynamicBody", field: "missing", to: .int(1), in: entity.id))

        let json = try #require(try world.encodeDynamicComponent(named: "DynamicBody", of: entity.id))
        let other = world.spawn("Copy")
        #expect(world.insertDynamicComponent(named: "DynamicBody", json: json, into: other.id))
        #expect(world.dynamicComponentPayload(named: "DynamicBody", of: other.id) == world.dynamicComponentPayload(named: "DynamicBody", of: entity.id))

        #expect(world.removeDynamicComponent(named: "DynamicBody", from: entity.id))
        #expect(world.dynamicComponentPayload(named: "DynamicBody", of: entity.id) == nil)
        #expect(!world.removeDynamicComponent(named: "DynamicBody", from: entity.id))
        #expect(!world.removeDynamicComponent(named: "Unknown", from: entity.id))
    }

    @Test("A rejected field leaves the entity untouched")
    @MainActor
    func rejectedInsertDoesNotPartiallyApply() {
        let descriptor = RuntimeComponentDescriptor(
            stableID: "tests.dynamic.atomic",
            name: "DynamicAtomic",
            fieldNames: ["count"],
            fieldKinds: [.int],
            defaultValues: [.int(0)]
        )
        let world = World(name: "Atomic dynamic insert")
        world.registerRuntimeComponent(descriptor)
        let entity = world.spawn("Target")

        #expect(!world.insertDynamicComponent(named: "DynamicAtomic", fields: ["count": .string("nope")], into: entity.id))
        #expect(!world.insertDynamicComponent(named: "DynamicAtomic", fields: ["unknown": .int(1)], into: entity.id))
        #expect(!world.insertDynamicComponent(named: "DynamicAtomic", into: 9_999_999))
        #expect(world.dynamicComponentPayload(named: "DynamicAtomic", of: entity.id) == nil)
    }

    @Test("Works for a registered native component through its reflection descriptor")
    @MainActor
    func nativeComponent() {
        RuntimeTypeRegistry.registerComponent(
            DynamicNativeBody.self,
            names: ["DynamicNativeBody", "tests.dynamic.native"],
            makeDefault: { DynamicNativeBody() }
        )
        ComponentReflectionRegistry.register(DynamicNativeBody.componentDescriptor)
        let world = World(name: "Dynamic native component")
        let entity = world.spawn("Target")

        #expect(world.insertDynamicComponent(named: "tests.dynamic.native", fields: ["count": .int(4)], into: entity.id))
        #expect(world.get(DynamicNativeBody.self, from: entity.id)?.count == 4)
        #expect(world.setDynamicComponentField(named: "DynamicNativeBody", field: "position", to: .array([.double(1), .double(2), .double(3)]), in: entity.id))
        #expect(world.get(DynamicNativeBody.self, from: entity.id)?.position == Vector3(1, 2, 3))
        #expect(!world.setDynamicComponentField(named: "DynamicNativeBody", field: "count", to: .string("x"), in: entity.id))
        #expect(world.dynamicComponentPayload(named: "DynamicNativeBody", of: entity.id)?["count"] == .int(4))
        #expect(!world.insertDynamicComponent(named: "DynamicNativeBody", fields: ["count": .string("x")], into: world.spawn("Other").id))
        #expect(world.removeDynamicComponent(named: "tests.dynamic.native", from: entity.id))
        #expect(world.get(DynamicNativeBody.self, from: entity.id) == nil)
    }
}

@Component
private struct DynamicNativeBody {
    var count: Int = 0
    var position: Vector3 = .zero
}
