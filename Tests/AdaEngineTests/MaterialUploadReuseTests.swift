@_spi(Internal) @testable import AdaRender
import Foundation
import Math
import Testing

@testable import AdaCorePipelines

@Suite
@MainActor
struct MaterialUploadReuseTests {
    @Test
    func unchangedMaterialAvoidsUploadsAndMutationPreservesInFlightBuffer() async throws {
        let device = HeadlessRenderBackend().renderDevice
        var uniforms = PBR3DUniforms()
        let material = PBRMaterial()
        uniforms.beginFrame()
        uniforms.write(material: material, descriptor: VertexDescriptor(), device: device)
        let buffer = try #require(uniforms.buffer(for: material))
        let marker = Data(repeating: 0xa5, count: buffer.length)
        unsafe buffer.contents().initializeMemory(as: UInt8.self, repeating: 0xa5, count: buffer.length)
        uniforms.write(material: material, descriptor: VertexDescriptor(), device: device)
        #expect(try await buffer.readData() == marker)
        material.normalScale = 2
        uniforms.write(material: material, descriptor: VertexDescriptor(), device: device)
        let edited = try #require(uniforms.buffer(for: material))
        #expect(edited !== buffer)
        #expect(try await buffer.readData() == marker)
        let value = unsafe edited.contents().load(as: PBR3DUniform.self)
        #expect(value.properties.x == 2)
        // Subsequent frames reuse the edited value without rewriting in-flight data.
        for _ in 0..<max(1, unsafe RenderEngine.configurations.maxFramesInFlight) {
            uniforms.beginFrame()
            uniforms.write(material: material, descriptor: VertexDescriptor(), device: device)
            let current = try #require(uniforms.buffer(for: material))
            let snapshot = unsafe current.contents().load(as: PBR3DUniform.self)
            #expect(snapshot.properties.x == 2)
        }
    }
}
