@_spi(AdaEngine) import AdaEngine
import AdaInput
import Math
import Testing

@testable import AdaEditor

@MainActor
@Suite("Presented viewport gizmo input")
struct EditorViewportInteractionPresentationTests {
    @Test("Hover and drag follow the displayed frame, including resized targets", arguments: [Float(1), 2])
    func inputUsesDisplayedGeometry(scale: Float) throws {
        let viewport = EditorSceneViewportModel()
        let presentation = EditorViewportPresentation()
        var model = EditorSceneModel.default(projectName: "Presented input")
        let selected = model.addEntity(name: "Selected", parentID: try #require(model.rootEntityID))
        model.selectEntity(selected.id)
        var content = try model.encodedYAML()
        viewport.configure(sceneContent: content, onSelectionChanged: { _ in }, onDocumentContentChanged: { content = $0 })
        viewport.twoDZoom = 1
        viewport.setViewportSize(Size(width: 640, height: 400))
        presentation.prepareFrame(viewportModel: viewport, theme: Theme())()
        let displayed = try #require(presentation.presentedAnnotations?.interactionGizmo.geometry)
        let point = displayed.screenOrigin + Vector2(40, 0)
        #expect(displayed.hitTest(point) == .x)

        viewport.twoDCenter = Vector2(200, 0)
        presentation.refresh(viewportModel: viewport)
        let presentNewFrame = presentation.prepareFrame(viewportModel: viewport, theme: Theme())
        viewport.setViewportSize(Size(width: 640 * scale, height: 400 * scale))
        let scaledPoint = point * scale
        #expect(try #require(viewport.transformGizmo()).hitTest(scaledPoint) == nil)
        #expect(viewport.handleInput(MouseEvent(window: .empty, button: .none, mousePosition: scaledPoint, phase: .changed, modifierKeys: [], time: 0)))
        #expect(viewport.hoveredGizmoHandle == .x)
        #expect(viewport.beginTransformDragIfNeeded(at: scaledPoint, button: .left))
        #expect(viewport.activeGizmoHandle == .x)
        #expect(viewport.updateTransformDrag(to: scaledPoint + Vector2(30 * scale, 0)))
        viewport.endTransformDrag()
        let edited = try EditorSceneModel.decode(from: content)
        let payload = try #require(edited.entities.first { $0.id == selected.id }?.components[EditorBuiltInComponentType.transform])
        let transform = try #require(EditorComponentPayloadDecoder.decode(Transform.self, payload: payload) as? Transform)
        #expect(abs(transform.position.x - 30) < 0.02)
        #expect(abs(transform.position.y) < 0.02)

        // Publishing the pending frame switches the input geometry at the same boundary.
        presentNewFrame()
        let current = try #require(viewport.interactionGizmo())
        #expect(current.screenOrigin != displayed.screenOrigin)
        #expect(current.hitTest(point) == nil)
    }

    @Test("A frame without handles does not fall back to newer live geometry")
    func noDisplayedHandles() throws {
        let viewport = EditorSceneViewportModel()
        let presentation = EditorViewportPresentation()
        var model = EditorSceneModel.default(projectName: "No handles")
        let selected = model.addEntity(name: "Selected", parentID: try #require(model.rootEntityID))
        model.selectEntity(selected.id)
        viewport.configure(sceneContent: try model.encodedYAML(), onSelectionChanged: { _ in }, onDocumentContentChanged: { _ in })
        viewport.setViewportSize(Size(width: 640, height: 400))
        viewport.setActiveTool(.select)
        presentation.prepareFrame(viewportModel: viewport, theme: Theme())()
        viewport.setActiveTool(.translate)
        let live = try #require(viewport.transformGizmo())
        #expect(viewport.interactionGizmo() == nil)
        #expect(!viewport.beginTransformDragIfNeeded(at: live.screenOrigin, button: .left))
        presentation.refresh(viewportModel: viewport)
        presentation.prepareFrame(viewportModel: viewport, theme: Theme())()
        #expect(viewport.beginTransformDragIfNeeded(at: live.screenOrigin, button: .left))
        viewport.endTransformDrag(cancelled: true)
    }
}
