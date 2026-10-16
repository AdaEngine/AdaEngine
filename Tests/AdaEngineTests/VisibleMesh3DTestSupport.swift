@testable import AdaCorePipelines
@_spi(Internal) @testable import AdaApp
import AdaEngine
import Testing
@_spi(Internal) @testable import AdaRender

/// What the 3D render nodes draw for one view: the mesh sources extracted into the render world, culled and batched
/// by `VisibleMesh3DLists`. Tests use it to look at draw items without running a full frame.
@MainActor
struct VisibleMesh3D {
    let items: [Opaque3DRenderItem]
    let buffers: Active3DInstanceBuffers
    let count: Visibility3DCount

    /// Runs the render-world extraction of `app` and builds the visible list of a camera that sees every mesh.
    ///
    /// The view looks along +Z from 1000 units behind the origin through a very wide frustum, so meshes placed near
    /// the origin are never culled.
    static func capture(from app: AppWorlds, pass: Int = -1) async throws -> VisibleMesh3D {
        await app.main.runScheduler(.preUpdate)
        await app.main.runScheduler(.postUpdate)
        let renderWorld = try #require(app.getSubworldBuilder(by: .renderWorld)?.main)
        renderWorld.insertResource(MainWorld(world: app.main))
        await renderWorld.runScheduler(.extract)
        return try capture(from: renderWorld, pass: pass)
    }

    /// Builds the visible list from the sources already extracted into `renderWorld`.
    static func capture(from renderWorld: World, pass: Int = -1) throws -> VisibleMesh3D {
        let sources = try #require(renderWorld.getResource(ExtractedMesh3DSources.self)).meshes
        let device = unsafe RenderEngine.shared.renderDevice
        let view = renderWorld.spawn().id
        let viewMatrix = Transform3D(translation: [0, 0, 1000])
        let projection = Transform3D.perspective(fieldOfView: .degrees(120), aspectRatio: 1, zNear: 0.1, zFar: 100_000)
        var lists = VisibleMesh3DLists()
        var materials = PBR3DUniforms()
        materials.beginFrame()
        lists.prepare(
            sources: sources,
            view: view,
            pass: pass,
            viewMatrix: viewMatrix,
            projection: projection,
            cullingProjection: projection * viewMatrix,
            settings: .init(),
            device: device,
            materials: &materials
        )
        return VisibleMesh3D(
            items: lists.items(view: view, pass: pass),
            buffers: lists.buffers(view: view, pass: pass),
            count: lists.count(view: view, pass: pass)
        )
    }
}
