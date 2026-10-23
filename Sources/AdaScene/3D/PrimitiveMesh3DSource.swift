import AdaAssets
import AdaRender
import AdaUtils
import Math

/// Portable authored primitive data. GPU resources are created only when the
/// scene is instantiated, so export never serializes a device mesh or material.
public struct PrimitiveMesh3DSource: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case quad = "Quad", circle = "Circle", cube = "Cube", sphere = "Sphere", plane = "Plane"
    }
    public var mesh: Kind
    public var size: Float
    public var color: Color
    public var metallic: Float
    public var roughness: Float
    public var castShadows: Bool
    public var receiveShadows: Bool
    public var graphMaterial: ShaderGraphMaterialSource?

    public init(
        mesh: Kind = .cube,
        size: Float = 1,
        color: Color = .white,
        metallic: Float = 0,
        roughness: Float = 0.5,
        castShadows: Bool = true,
        receiveShadows: Bool = true,
        graphMaterial: ShaderGraphMaterialSource? = nil
    ) {
        self.mesh = mesh
        self.size = size
        self.color = color
        self.metallic = metallic
        self.roughness = roughness
        self.castShadows = castShadows
        self.receiveShadows = receiveShadows
        self.graphMaterial = graphMaterial
    }

    private enum CodingKeys: CodingKey { case mesh, size, color, metallic, roughness, castShadows, receiveShadows, graphMaterial }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mesh = try values.decodeIfPresent(Kind.self, forKey: .mesh) ?? .cube
        size = try values.decodeIfPresent(Float.self, forKey: .size) ?? 1
        color = try values.decodeIfPresent(Color.self, forKey: .color) ?? .white
        metallic = try values.decodeIfPresent(Float.self, forKey: .metallic) ?? 0
        roughness = try values.decodeIfPresent(Float.self, forKey: .roughness) ?? 0.5
        castShadows = try values.decodeIfPresent(Bool.self, forKey: .castShadows) ?? true
        receiveShadows = try values.decodeIfPresent(Bool.self, forKey: .receiveShadows) ?? true
        graphMaterial = try values.decodeIfPresent(ShaderGraphMaterialSource.self, forKey: .graphMaterial)
    }

    public func validate() throws {
        guard size.isFinite, size > 0, metallic.isFinite, roughness.isFinite,
            (0...1).contains(metallic), (0...1).contains(roughness),
            [color.red, color.green, color.blue, color.alpha].allSatisfy(\.isFinite) else {
            throw AssetError.message("Invalid primitive mesh dimensions or material values.")
        }
    }

    public func makeComponent(renderDevice: RenderDevice) throws -> Mesh3DComponent {
        try validate()
        let material = PBRMaterial()
        material.baseColorFactor = [color.red, color.green, color.blue, color.alpha]
        material.metallicFactor = metallic
        material.roughnessFactor = roughness
        if let graphMaterial {
            let graph = try ShaderGraphMaterial(source: graphMaterial)
            guard graph.program.target == .pbrSurface else { throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: "PBR") }
            material.graphMaterial = graph
        }
        let generated: Mesh
        switch mesh {
        case .quad: generated = Mesh.generate(from: Quad(size: [size, size]), renderDevice: renderDevice)
        case .circle: generated = Mesh.generateCircle(radius: size / 2, renderDevice: renderDevice)
        case .cube: generated = Mesh.generateCube(size: [size, size, size], renderDevice: renderDevice)
        case .sphere: generated = Mesh.generateSphere(radius: size / 2, renderDevice: renderDevice)
        case .plane: generated = Mesh.generatePlane(size: [size, size], renderDevice: renderDevice)
        }
        return Mesh3DComponent(mesh: generated, materials: [material], castShadows: castShadows, receiveShadows: receiveShadows)
    }
}
