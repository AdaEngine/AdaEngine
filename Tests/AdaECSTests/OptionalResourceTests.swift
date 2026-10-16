import AdaECS
import Testing

@Suite
struct OptionalResourceTests {
    private struct Value: Resource {
        var number: Int
    }

    @Test("Optional resource construction accepts an absent resource")
    func absentResource() {
        let world = World()
        let resource = Res<Value?>(from: world)
        #expect(resource.wrappedValue == nil)
        resource.update(from: world)
        #expect(resource.wrappedValue == nil)
    }

    @Test("Optional resource construction and updates use the wrapped resource")
    func replacementAndRemoval() {
        let world = World()
        world.insertResource(Value(number: 1))
        let resource = Res<Value?>(from: world)
        #expect(resource.wrappedValue?.number == 1)
        world.insertResource(Value(number: 2))
        resource.update(from: world)
        #expect(resource.wrappedValue?.number == 2)
        world.removeResource(Value.self)
        resource.update(from: world)
        #expect(resource.wrappedValue == nil)
    }
}
