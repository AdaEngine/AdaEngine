@_spi(AdaEngine) import AdaEngine
import Foundation

extension EditorShaderGraphModel {
    var canvasDecorations: [EditorNodeCanvasDecoration] {
        guard let graph else {
            return []
        }
        let items = canvasItems
        let geometry = EditorNodeCanvasGeometry(nodes: items, pan: .zero, zoom: 1)
        let groups = graph.groups.sorted { $0.key < $1.key }.compactMap { id, group -> EditorNodeCanvasDecoration? in
            let members = items.filter { group.nodes.contains($0.id) }.map { geometry.bounds($0) }
            guard let left = members.map(\.minX).min(), let top = members.map(\.minY).min(), let right = members.map(\.maxX).max(), let bottom = members.map(\.maxY).max() else {
                return nil
            }
            return .init(id: id, title: group.title, bounds: Rect(x: left - 16, y: top - 36, width: right - left + 32, height: bottom - top + 52))
        }
        return groups
            + graph.notes.sorted { $0.key < $1.key }.compactMap { id, note in
                guard note.position.x.isFinite, note.position.y.isFinite else {
                    return nil
                }
                return .init(id: id, title: note.text, bounds: Rect(x: note.position.x, y: note.position.y, width: 220, height: 110), isNote: true)
            }
    }

    func insert(_ entry: EditorShaderGraphNodeEntry, using search: EditorShaderGraphSearch) {
        beginTransaction()
        defer { endTransaction() }
        guard let id = addNode(entry.operation, type: entry.type, at: search.point), let graph, let node = graph.nodes.first(where: { $0.id == id }), let endpoint = search.endpoint,
            let existing = graph.nodes.first(where: { $0.id == endpoint.node })
        else {
            return
        }
        if endpoint.isOutput, let type = graph.outputPorts(for: existing)[endpoint.port],
            let port = graph.inputPorts(for: node).keys.sorted().first(where: { graph.inputPorts(for: node)[$0].map { EditorShaderGraphSearch.compatible(type, with: $0) } == true }) {
            if connect(.init(existing.id, port: endpoint.port), to: id, port: port), let old = search.replacedInput { editNode(old.node) { $0.inputs[old.port] = nil } }
        } else if let type = graph.inputPorts(for: existing)[endpoint.port],
            let port = graph.outputPorts(for: node).keys.sorted().first(where: { graph.outputPorts(for: node)[$0].map { EditorShaderGraphSearch.compatible($0, with: type) } == true }) {
            connect(.init(id, port: port), to: existing.id, port: endpoint.port)
        }
    }

    private struct Clipboard: Codable {
        var version = 1
        let target: ShaderGraph.Target
        let nodes: [ShaderGraph.Node]
        let layout: [String: ShaderGraph.Position]
        let groups: [String: ShaderGraph.LayoutGroup]?
    }

    func copySelection() -> String? {
        guard let graph else {
            return nil
        }
        let nodes = graph.nodes.filter { selection.contains($0.id) && $0.id != graph.output }
        guard !nodes.isEmpty else {
            return nil
        }
        let copiedIDs = Set(nodes.map(\.id))
        let groups = graph.groups.filter { $0.value.nodes.allSatisfy { copiedIDs.contains($0) } }
        let payload = Clipboard(target: graph.target, nodes: nodes, layout: graph.layout.filter { selection.contains($0.key) }, groups: groups.isEmpty ? nil : groups)
        return (try? JSONEncoder().encode(payload)).flatMap { String(data: $0, encoding: .utf8) }
    }

    @discardableResult func paste(_ text: String, at point: Vector2) -> Bool {
        guard let graph, let data = text.data(using: .utf8), data.count < 2 * 1024 * 1024, let payload = try? JSONDecoder().decode(Clipboard.self, from: data), payload.version == 1,
            payload.target == graph.target, !payload.nodes.isEmpty, payload.nodes.count <= 2_000,
            payload.nodes.allSatisfy({ $0.kind != "output" && ShaderGraph.Operation(rawValue: $0.kind) != nil }), Set(payload.nodes.map(\.id)).count == payload.nodes.count
        else {
            return false
        }
        let ids = Dictionary(uniqueKeysWithValues: payload.nodes.map { ($0.id, UUID().uuidString) })
        var remappedParameters: [String: String] = [:]
        let left = payload.layout.values.map(\.x).min() ?? 0, top = payload.layout.values.map(\.y).min() ?? 0
        let copied = payload.nodes.compactMap { original -> ShaderGraph.Node? in
            guard let id = ids[original.id] else {
                return nil
            }
            var node = original
            node.id = id
            node.inputs = original.inputs.compactMapValues { link in ids[link.node].map { .init($0, port: link.port) } }
            if let reference = node.reference, node.kind == "parameter",
                graph.nodes.contains(where: {
                    $0.kind == "parameter" && $0.reference == reference && ($0.type != node.type || $0.value != node.value || $0.defaultTexture != node.defaultTexture)
                }) {
                let id = remappedParameters[reference] ?? UUID().uuidString
                remappedParameters[reference] = id
                node.reference = id
            }
            return node
        }
        let changed = edit { candidate in
            candidate.nodes += copied
            for group in (payload.groups ?? [:]).values {
                candidate.groups[UUID().uuidString] = .init(title: group.title, nodes: group.nodes.compactMap { ids[$0] }, tint: group.tint)
            }
            for original in payload.nodes {
                if let id = ids[original.id] {
                    let location = payload.layout[original.id] ?? .init(x: left, y: top)
                    candidate.layout[id] = .init(x: location.x - left + point.x, y: location.y - top + point.y)
                }
            }
        }
        if changed { selection = Set(copied.map(\.id)) }
        return changed
    }

    func groupSelection() {
        guard !selection.isEmpty else {
            return
        }
        let id = UUID().uuidString
        edit(semantic: false) { $0.groups[id] = .init(title: L10n.tr("Group"), nodes: selection.sorted()) }
    }

    func addComment(at point: Vector2) {
        let id = UUID().uuidString
        edit(semantic: false) { $0.notes[id] = .init(text: L10n.tr("Comment"), position: .init(x: point.x, y: point.y)) }
    }

    func reveal(_ id: String, canvas: EditorNodeCanvasState, size: Size) {
        guard let item = canvasItems.first(where: { $0.id == id }) else {
            return
        }
        selection = [id]
        canvas.setPan(Vector2(size.width / 2, size.height / 2) - (item.position + Vector2(104, item.height / 2)) * canvas.zoom)
    }
}
