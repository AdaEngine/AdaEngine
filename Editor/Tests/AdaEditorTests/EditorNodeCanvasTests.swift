@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import Testing

@MainActor @Suite("Node canvas geometry") struct EditorNodeCanvasTests {
    @Test func wireDrawingUsesTheSameLocalEndpointsAsPicking() throws {
        var context = UIGraphicsContext()
        context.translateBy(x: 10, y: -20)
        EditorNodeCanvas.drawWire(context: &context, start: [40, 60], end: [100, 200], color: .white)
        let lines = context.getDrawCommands().compactMap { command -> (Vector3, Vector3)? in
            if case let .drawLine(start, end, _, _) = command { return (start, end) }
            return nil
        }
        #expect(lines.count == 24)
        #expect(lines.first?.0 == [50, -80, 0])
        #expect(lines.last?.1 == [110, -220, 0])
    }

    private var node: EditorNodeCanvasItem {
        .init(id: "node", title: "Node", position: [100, 80], inputs: [.init(id: "a", title: "A", type: "float")], outputs: [.init(id: "value", title: "Value", type: "float")])
    }

    @Test func portsAndNodePickingShareTheDisplayedScaleAndPan() throws {
        let geometry = EditorNodeCanvasGeometry(nodes: [node], pan: [60, -20], zoom: 0.5)
        let endpoint = EditorNodeCanvasEndpoint(node: "node", port: "value", isOutput: true)
        let point = try #require(geometry.port(endpoint))
        #expect(geometry.hitPort(point) == endpoint)
        #expect(geometry.hitNode(geometry.screen([140, 100])) == "node")
        #expect(geometry.world(geometry.screen([140, 100])) == [140, 100])
        #expect(geometry.hitNode([-200, -200]) == nil)
    }

    @Test func zoomKeepsItsAnchorAndFitKeepsNodesOnScreen() {
        let state = EditorNodeCanvasState()
        let anchor = Vector2(320, 240)
        let before = (anchor - state.pan) / state.zoom
        state.zoom(by: 1.5, around: anchor)
        #expect(((anchor - state.pan) / state.zoom - before).squaredLength < 0.001)
        state.fit([node], in: Size(width: 640, height: 480))
        let geometry = EditorNodeCanvasGeometry(nodes: [node], pan: state.pan, zoom: state.zoom)
        let bounds = geometry.bounds(node)
        #expect(bounds.minX >= 0 && bounds.maxX <= 640)
        #expect(bounds.minY >= 0 && bounds.maxY <= 480)
        #expect(geometry.selected(in: bounds) == ["node"])
    }

    @Test func dragGroupsMovementIntoOneTransactionAndCancellationRestoresIt() {
        let state = EditorNodeCanvasState()
        let geometry = EditorNodeCanvasGeometry(nodes: [node], pan: .zero, zoom: 0.5)
        let interaction = EditorNodeCanvasInteraction()
        var begins = 0, commits = 0, cancels = 0
        var positions: [String: Vector2] = [:]
        interaction.begin = { begins += 1 }
        interaction.commit = { commits += 1 }
        interaction.cancel = { cancels += 1 }
        interaction.move = { positions = $0 }
        interaction.drag(from: [70, 45], to: [80, 55], geometry: geometry, wires: [], selection: [], state: state)
        interaction.drag(from: [70, 45], to: [90, 65], geometry: geometry, wires: [], selection: ["node"], state: state)
        #expect(positions["node"] == [140, 120])
        interaction.end(at: [90, 65], geometry: geometry)
        #expect(begins == 1 && commits == 1 && cancels == 0)
        interaction.drag(from: [70, 45], to: [80, 55], geometry: geometry, wires: [], selection: [], state: state)
        interaction.abort()
        #expect(begins == 2 && commits == 1 && cancels == 1)
    }

    @Test func wireCaptureUsesPortsAtCurrentZoomAndEmptyDropDoesNotConnect() throws {
        var other = node
        other.id = "other"
        other.position = [450, 100]
        let state = EditorNodeCanvasState()
        let geometry = EditorNodeCanvasGeometry(nodes: [node, other], pan: [30, -5], zoom: 0.75)
        let source = EditorNodeCanvasEndpoint(node: "node", port: "value", isOutput: true)
        let target = EditorNodeCanvasEndpoint(node: "other", port: "a", isOutput: false)
        let start = try #require(geometry.port(source)), end = try #require(geometry.port(target))
        let interaction = EditorNodeCanvasInteraction()
        var pairs: [EditorNodeCanvasWire] = []
        interaction.connect = { pairs.append(.init(source: $0, target: $1, type: "float")) }
        interaction.drag(from: start, to: end, geometry: geometry, wires: [], selection: [], state: state)
        interaction.end(at: end, geometry: geometry)
        #expect(pairs == [.init(source: source, target: target, type: "float")])
        interaction.drag(from: start, to: .zero, geometry: geometry, wires: [], selection: [], state: state)
        interaction.end(at: .zero, geometry: geometry)
        #expect(pairs.count == 1)
    }
}
