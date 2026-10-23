import AdaECS
import Math
import Testing

@Component
struct NullableReflectionFixture {
    var destination: Vector3? = [1, 2, 3]
    var count: Int? = nil
    let identifier: Int = 7
    private(set) var revision: Int = 2
    private var implementationDetail: Float = 3
    var summary: String { destination == nil ? "stopped" : "moving" }
}

@Suite("Nullable and read-only component fields")
struct NullableReflectionTests {
    @Test func optionalValuesRoundTripAndRejectInvalidInput() throws {
        let descriptor = NullableReflectionFixture.componentDescriptor
        let field = try #require(descriptor.fields.first { $0.key == "destination" })
        #expect(field.kind == .optional(.vector3))
        #expect(field.isWritable)
        #expect(field.read(NullableReflectionFixture()) == .array([.double(1), .double(2), .double(3)]))
        let cleared = try #require(field.write(NullableReflectionFixture(), .null) as? NullableReflectionFixture)
        #expect(cleared.destination == nil)
        #expect(field.read(cleared) == .null)
        #expect(field.write(cleared, .string("bad")) == nil)
        #expect(!field.accepts(.array([.double(.nan), .double(0), .double(0)])))
        let restored = try #require(field.write(cleared, .array([.double(4), .double(5), .double(6)])) as? NullableReflectionFixture)
        #expect(restored.destination == [4, 5, 6])
        var count: Int? = 4
        #expect(ComponentReflection.write(.null, to: &count))
        #expect(count == nil)
        #expect(ComponentReflection.write(.int(9), to: &count))
        #expect(count == 9)
    }

    @Test func gettersConstantsAndRestrictedSettersCannotBeWritten() throws {
        let descriptor = NullableReflectionFixture.componentDescriptor
        #expect(!descriptor.fields.contains { $0.key == "implementationDetail" })
        for key in ["identifier", "revision", "summary"] {
            let field = try #require(descriptor.fields.first { $0.key == key })
            #expect(!field.isWritable)
            #expect(field.write(NullableReflectionFixture(), .int(100)) == nil)
        }
        #expect(descriptor.fields.first { $0.key == "summary" }?.read(NullableReflectionFixture()) == .string("moving"))
        #expect(NullableReflectionFixture.runtimeComponentConstructor.parameters.map(\.name) == ["destination", "count"])
    }
}
