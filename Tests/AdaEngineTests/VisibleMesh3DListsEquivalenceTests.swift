@testable import AdaCorePipelines
import AdaECS
@_spi(Internal) @testable import AdaRender
import AdaScene
import AdaUtils
import Foundation
import Math
import Testing

/// Pins what `VisibleMesh3DLists.prepare` produces for a varied synthetic scene, so the culling and batching code can
/// be rewritten for speed without changing a single draw item or instance.
///
/// The scene mixes meshes, multi-part meshes, materials (opaque, masked, blended, textured-looking flags), skinned-like
/// buffers, shadow casters and receivers, LOD alternatives, distance limits and sources outside the frustum. The digest
/// covers every draw item, every instance and the counters for a camera pass and shadow passes.
@MainActor
@Suite("Visible mesh list equivalence")
struct VisibleMesh3DListsEquivalenceTests {
    /// 64-bit FNV-1a over text, which is stable across runs unlike `Hasher`.
    private struct Digest {
        private(set) var value: UInt64 = 0xcbf2_9ce4_8422_2325
        mutating func add(_ text: String) {
            for byte in text.utf8 {
                value = (value ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
            }
            value = (value ^ 0xff) &* 0x0000_0100_0000_01b3
        }
    }

    private struct Scene {
        var sources: [Mesh3DRenderSource]
        var materials: [Material]
        var meshes: [Mesh]
    }

    private func setup() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
    }

    /// A small deterministic generator so the scene never changes between runs or machines.
    private struct Generator {
        var state: UInt64
        mutating func next() -> Float {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float((state >> 40) & 0xffff) / 65535
        }
    }

    private func makeScene(count: Int) throws -> Scene {
        try setup()
        let device = unsafe RenderEngine.shared.renderDevice
        let world = World()
        let high = Mesh.generateSphere(radius: 0.5, segments: 24, rings: 14, renderDevice: device)
        let medium = Mesh.generateSphere(radius: 0.5, segments: 12, rings: 8, renderDevice: device)
        let low = Mesh.generateSphere(radius: 0.5, segments: 6, rings: 4, renderDevice: device)
        let cube = Mesh.generateCube(size: [1, 2, 1], renderDevice: device)
        let plane = Mesh.generatePlane(size: [2, 2], renderDevice: device)
        var descriptorA = MeshDescriptor(name: "A")
        descriptorA.positions = [[0, 0, 0], [1, 0, 0], [0, 1, 0]]
        descriptorA.normals = [[0, 0, 1], [0, 0, 1], [0, 0, 1]]
        descriptorA.indicies = [0, 1, 2]
        var descriptorB = descriptorA
        descriptorB.positions = [[0, 0, 1], [1, 0, 1], [0, 1, 1]]
        let multi = Mesh.generate(from: [descriptorA, descriptorB], renderDevice: device)

        var materials: [Material] = []
        for index in 0..<7 {
            let material = PBRMaterial()
            material.baseColorFactor = [0.2 + 0.1 * Float(index), 0.5, 0.9 - 0.1 * Float(index), 1]
            material.roughnessFactor = 0.1 + 0.12 * Float(index)
            material.metallicFactor = index % 2 == 0 ? 0 : 1
            if index == 3 { material.alphaMode = .mask }
            if index == 5 { material.alphaMode = .blend }
            if index == 6 { material.emissiveStrength = 2 }
            materials.append(material)
        }
        materials.append(AtmosphereMaterial())
        let meshes = [high, cube, plane, multi]
        var generator = Generator(state: 0x5eed)
        var sources: [Mesh3DRenderSource] = []
        for index in 0..<count {
            let mesh = meshes[index % meshes.count]
            let position = Vector3((generator.next() - 0.5) * 120, (generator.next() - 0.5) * 20, generator.next() * 120)
            let transform = Transform3D(translation: position, rotation: Quat(axis: .up, angle: generator.next() * 6), scale: .one)
            let hasLOD = index % 5 == 0
            let materialsForSource = [materials[index % materials.count], materials[(index * 3 + 1) % materials.count]]
            sources.append(Mesh3DRenderSource(
                entity: world.spawn().id,
                drawPass: Model3DDrawPass(),
                mesh: hasLOD ? high : mesh,
                materials: materialsForSource,
                transform: transform,
                bounds: MeshVisibility3DMath.transformed(mesh.bounds, by: transform),
                alternatives: hasLOD ? [medium, low] : [],
                thresholds: hasLOD ? [0.2, 0.05] : [],
                hysteresis: 0.15,
                maximumDistance: index % 7 == 0 ? 90 : nil,
                fadeDistance: 20,
                forceVisible: index % 41 == 0,
                castShadows: index % 9 != 0,
                receiveShadows: index % 11 != 0,
                previousTransform: index % 13 == 0 ? Transform3D(translation: position + [0.1, 0, 0]) : nil
            ))
        }
        return Scene(sources: sources, materials: materials, meshes: meshes)
    }

    /// Runs the camera pass, two shadow passes and a second camera frame (so LOD hysteresis history is exercised).
    private func digest(of scene: Scene) -> (String, Visibility3DCount) {
        let device = unsafe RenderEngine.shared.renderDevice
        let world = World()
        let view = world.spawn().id
        var lists = VisibleMesh3DLists()
        var materials = PBR3DUniforms()
        var digest = Digest()
        let projection = Transform3D.perspective(fieldOfView: .degrees(70), aspectRatio: 1.5, zNear: 0.1, zFar: 400)
        let cameras = [
            Transform3D(translation: [0, 4, -20]).inverse,
            Transform3D(translation: [6, 5, -14], rotation: Quat(axis: .up, angle: 0.4), scale: .one).inverse,
        ]
        let shadowProjection = Transform3D.orthographic(left: -70, right: 70, top: 40, bottom: -40, zNear: 0.1, zFar: 300)
        var lastCount = Visibility3DCount()
        for (frame, viewMatrix) in cameras.enumerated() {
            materials.beginFrame()
            let passes: [(pass: Int, culling: Transform3D, settings: MeshVisibilitySettings3D)] = [
                (-1, projection * viewMatrix, MeshVisibilitySettings3D()),
                (0, shadowProjection, MeshVisibilitySettings3D(frustumCulling: true, lod: true, distanceCulling: false)),
                (100, projection * viewMatrix, MeshVisibilitySettings3D(frustumCulling: false, lod: false, distanceCulling: false)),
            ]
            for entry in passes {
                lists.prepare(
                    sources: scene.sources,
                    view: view,
                    pass: entry.pass,
                    viewMatrix: viewMatrix,
                    projection: projection,
                    cullingProjection: entry.culling,
                    settings: entry.settings,
                    device: device,
                    materials: &materials
                )
                digest.add("frame \(frame) pass \(entry.pass)")
                let count = lists.count(view: view, pass: entry.pass)
                lastCount = count
                digest.add("count \(count.candidates) \(count.visibleMeshes) \(count.frustumRejected) \(count.distanceRejected) \(count.drawCalls) \(count.triangles) \(count.lod0Triangles) \(count.lodInstances)")
                for item in lists.items(view: view, pass: entry.pass) {
                    let materialIndex = scene.materials.firstIndex { $0 === item.material } ?? -1
                    let meshIndex = scene.meshes.firstIndex { $0.models.count == item.mesh.models.count && $0.bounds == item.mesh.bounds } ?? -1
                    digest.add("item \(item.entity) m\(item.modelIndex) p\(item.partIndex) mat\(materialIndex) mesh\(meshIndex) range \(String(describing: item.batchRange)) cast \(item.castShadows) recv \(item.receiveShadows) skin \(item.skinningBuffer != nil)")
                }
                for instance in lists.buffers(view: view, pass: entry.pass).instances?.elements ?? [] {
                    digest.add("\(instance.modelMatrix) \(instance.color) \(instance.material) \(instance.textureFlags) \(instance.shadowFlags) \(instance.previousModelMatrix)")
                }
                let candidates = lists.gpuCandidates(view: view, pass: entry.pass)
                digest.add("candidates \(candidates.count)")
            }
        }
        return (String(digest.value, radix: 16), lastCount)
    }

    /// Recorded from main's unoptimized implementation after it gained descriptor-aware batch keys and lightweight shadow
    /// instances; the optimized version produces the same digest. A deliberate behavior change must update it with a reason.
    private static let expectedDigest = "5de09fd1016c21b6"

    @Test func listsAreIdenticalToTheRecordedBehavior() throws {
        let scene = try makeScene(count: 600)
        let result = digest(of: scene)
        print("DIGEST \(result.0)")
        #expect(result.0 == Self.expectedDigest, "Draw items, instances or counters changed: digest \(result.0).")
        #expect(result.1.visibleMeshes > 0 && result.1.drawCalls > 0, "The scene must produce draws.")
    }

    @Test func digestIsStableAcrossRuns() throws {
        let first = digest(of: try makeScene(count: 150))
        let second = digest(of: try makeScene(count: 150))
        #expect(first.0 == second.0)
    }

    /// Prints how long a camera pass takes over many meshes. It asserts nothing about speed.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_PERF"] == "1"))
    func prepareCost() throws {
        let scene = try makeScene(count: 5000)
        let device = unsafe RenderEngine.shared.renderDevice
        let world = World()
        let view = world.spawn().id
        var lists = VisibleMesh3DLists()
        var materials = PBR3DUniforms()
        let projection = Transform3D.perspective(fieldOfView: .degrees(70), aspectRatio: 1.5, zNear: 0.1, zFar: 400)
        let viewMatrix = Transform3D(translation: [0, 4, -60]).inverse
        func run() {
            materials.beginFrame()
            lists.prepare(
                sources: scene.sources,
                view: view,
                pass: -1,
                viewMatrix: viewMatrix,
                projection: projection,
                cullingProjection: projection * viewMatrix,
                settings: MeshVisibilitySettings3D(),
                device: device,
                materials: &materials
            )
        }
        for _ in 0..<5 { run() }
        let start = ContinuousClock.now
        let iterations = 40
        for _ in 0..<iterations { run() }
        let elapsed = start.duration(to: .now)
        let milliseconds = (Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18) * 1000 / Double(iterations)
        let count = lists.count(view: view, pass: -1)
        print("PREPARE \(String(format: "%.3f", milliseconds)) ms for \(count.candidates) sources, \(count.visibleMeshes) visible, \(count.drawCalls) draws")
    }
}
