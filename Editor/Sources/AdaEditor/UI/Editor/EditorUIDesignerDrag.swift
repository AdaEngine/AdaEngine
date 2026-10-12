@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Math
import Observation

@MainActor @Observable
final class EditorUIDesignerDrag {
    enum Source: Equatable {
        case node(String)
        case component(String)
        case canvas
    }

    struct Feedback {
        let ghost: Rect
        let target: Rect
        var insertion: Rect?
        let valid: Bool
    }

    private(set) var isDragging = false
    private(set) var targetLayerID: String?
    private(set) var layerInsertionAfter: Bool?
    private(set) var layerDropIsValid = false
    @ObservationIgnored private(set) var feedback: Feedback?
    @ObservationIgnored var canvasFrame: (() -> Rect)?
    @ObservationIgnored var canvasZoom: Float = 1
    @ObservationIgnored var isCompact = false
    @ObservationIgnored var layerFrames: [String: () -> Rect] = [:]
    @ObservationIgnored var onFeedbackChange: (() -> Void)?
    @ObservationIgnored var suppressesCanvasSelection = false
    @ObservationIgnored private weak var model: EditorUISceneModel?
    @ObservationIgnored private var moving: UINodeDescription?
    @ObservationIgnored private var baseline: UISceneDocument?
    @ObservationIgnored private var destination: EditorUIDropDestination?
    @ObservationIgnored private var grab = Point.zero
    @ObservationIgnored private var size = Size.zero
    @ObservationIgnored private var onBegin: (() -> Void)?

    init(model: EditorUISceneModel) { self.model = model }

    func change(source: Source, start: Point, location: Point, onBegin: (() -> Void)? = nil) {
        guard let model, !model.isReadOnly, !model.isInteractive, !model.showsSource else {
            cancel()
            return
        }
        if !isDragging {
            let node: UINodeDescription?
            switch source {
            case let .node(id): node = model.node(id)
            case let .component(type): node = model.makeDesignerNode(type)
            case .canvas: node = pickedNode(at: canvasPoint(start))
            }
            guard let node, node.id != model.document.root.id else {
                return
            }
            moving = node
            baseline = model.document
            let frame = renderedFrames()[node.id]
            size = frame?.size ?? measure(node)
            if source == .canvas, let frame {
                grab = canvasPoint(start) - frame.origin
            } else {
                grab = Point(size.width / 2, size.height / 2)
            }
            self.onBegin = onBegin
            isDragging = true
            onBegin?()
        }
        guard baseline == model.document else {
            cancel()
            return
        }
        update(at: location)
    }

    func end(at point: Point) {
        guard let model, isDragging, baseline == model.document, let moving else {
            cancel()
            return
        }
        update(at: point)
        let final = destination.flatMap { model.canDrop(moving, at: $0) ? $0 : nil }
        cancel()
        suppressesCanvasSelection = true
        if let final { model.dropDesignerNode(moving, at: final) }
    }

    func cancel() {
        isDragging = false
        targetLayerID = nil
        layerInsertionAfter = nil
        layerDropIsValid = false
        moving = nil
        baseline = nil
        destination = nil
        feedback = nil
        onBegin = nil
        onFeedbackChange?()
    }

    func canvasPoint(_ windowPoint: Point) -> Point {
        let frame = canvasFrame?() ?? .zero
        return Point((windowPoint.x - frame.minX) / canvasZoom, (windowPoint.y - frame.minY) / canvasZoom)
    }

    private func renderedFrames() -> [String: Rect] {
        guard let preview = model?.preview as? UIContainerView<UISceneView> else {
            return [:]
        }
        var authoredIDs = Set<String>()
        model?.document.root.visit { authoredIDs.insert($0.id) }
        var result: [String: Rect] = [:]
        func visit(_ snapshot: UINodeSnapshot) {
            if let id = snapshot.sceneNodeID, authoredIDs.contains(id) { result[id] = snapshot.absoluteFrame }
            snapshot.children.forEach(visit)
        }
        preview.uiTreeRoots().forEach(visit)
        return result
    }

    private func pickedNode(at point: Point) -> UINodeDescription? {
        guard let model else {
            return nil
        }
        let frames = renderedFrames()
        func find(_ node: UINodeDescription) -> UINodeDescription? {
            for child in (node.children + node.modifiers.flatMap(\.children)).reversed() {
                if let result = find(child) {
                    return result
                }
            }
            return frames[node.id]?.contains(point: point) == true ? node : nil
        }
        return find(model.document.root)
    }

    private func measure(_ node: UINodeDescription) -> Size {
        guard let model else {
            return Size(width: 80, height: 32)
        }
        do {
            let document = UISceneDocument(root: node, inputs: model.document.inputs, actions: model.document.actions)
            let session = try UISceneInstance(document: document, context: model.session?.context ?? .init(), catalog: model.catalog, resources: model.resources, sourceURL: model.sourceURL)
            let view = UIContainerView(rootView: UISceneView(session: session))
            view.frame = Rect(x: 0, y: 0, width: model.width, height: model.height)
            view.layoutIfNeeded()
            func find(_ snapshot: UINodeSnapshot) -> Size? {
                if snapshot.sceneNodeID == node.id {
                    return snapshot.absoluteFrame.size
                }
                return snapshot.children.compactMap(find).first
            }
            let measured = view.uiTreeRoots().compactMap(find).first ?? Size(width: 80, height: 32)
            return Size(width: max(24, measured.width), height: max(24, measured.height))
        } catch { return Size(width: 80, height: 32) }
    }
}

extension EditorUIDesignerDrag {
    private func update(at windowPoint: Point) {
        guard let model, let moving else {
            return
        }
        destination = nil
        var layerTargetID: String?
        var insertionAfter: Bool?
        feedback = nil
        defer {
            targetLayerID = layerTargetID
            layerInsertionAfter = insertionAfter
            layerDropIsValid = destination.map { model.canDrop(moving, at: $0) } ?? false
            onFeedbackChange?()
        }
        // Hierarchy targets use live geometry, including scroll offsets and modifier child slots.
        for (id, provider) in layerFrames where !isCompact {
            let frame = provider()
            guard frame.contains(point: windowPoint), let target = model.node(id) else { continue }
            let fraction = (windowPoint.y - frame.minY) / max(1, frame.height)
            if fraction > 0.25, fraction < 0.75, let content = model.catalog.views[target.type]?.signature.content, content != .none {
                destination = .children(.init(parentID: id, index: target.children.count))
            } else if var slot = model.dropSlot(containing: id) {
                if fraction >= 0.5 { slot.index += 1 }
                insertionAfter = fraction >= 0.5
                destination = .children(slot)
            }
            layerTargetID = id
            return
        }
        guard let canvas = canvasFrame?(), canvas.contains(point: windowPoint) else {
            return
        }
        let point = canvasPoint(windowPoint)
        let frames = renderedFrames()
        func findContainer(_ node: UINodeDescription) -> UINodeDescription? {
            if node.id == moving.id {
                return nil
            }
            for child in (node.children + node.modifiers.flatMap(\.children)).reversed() {
                if let result = findContainer(child) {
                    return result
                }
            }
            guard let frame = frames[node.id], let content = model.catalog.views[node.type]?.signature.content, content != .none else {
                return nil
            }
            let dropFrame = Rect(x: frame.midX - max(24, frame.width) / 2, y: frame.midY - max(24, frame.height) / 2, width: max(24, frame.width), height: max(24, frame.height))
            guard dropFrame.contains(point: point) else {
                return nil
            }
            return node
        }
        let target = findContainer(model.document.root)
        let parentFrame = target.flatMap { frames[$0.id] } ?? Rect(x: 0, y: 0, width: model.width, height: model.height)
        let origin = Point(
            min(max(parentFrame.minX, point.x - grab.x), parentFrame.minX + max(0, parentFrame.width - size.width)),
            min(max(parentFrame.minY, point.y - grab.y), parentFrame.minY + max(0, parentFrame.height - size.height))
        )
        var insertion: Rect?
        if let target, target.type != "FreeLayout" {
            var index = target.children.count
            if target.type == "VStack" || target.type == "HStack" || target.type == "LazyVStack" || target.type == "Grid" {
                let horizontal = target.type == "HStack"
                for (childIndex, child) in target.children.enumerated() where child.id != moving.id {
                    guard let frame = frames[child.id] else { continue }
                    let before = horizontal ? point.x < frame.midX : point.y < frame.midY
                    if before {
                        index = childIndex
                        insertion = horizontal ? Rect(x: frame.minX - 2, y: parentFrame.minY, width: 2, height: parentFrame.height)
                            : Rect(x: parentFrame.minX, y: frame.minY - 2, width: parentFrame.width, height: 2)
                        break
                    }
                }
                if insertion == nil {
                    insertion = horizontal ? Rect(x: parentFrame.maxX - 2, y: parentFrame.minY, width: 2, height: parentFrame.height)
                        : Rect(x: parentFrame.minX, y: parentFrame.maxY - 2, width: parentFrame.width, height: 2)
                }
            }
            destination = .children(.init(parentID: target.id, index: index))
        } else {
            let availableWidth = max(0, parentFrame.width - size.width), availableHeight = max(0, parentFrame.height - size.height)
            let position = Point(availableWidth > 0 ? (origin.x - parentFrame.minX) / availableWidth : 0.5, availableHeight > 0 ? (origin.y - parentFrame.minY) / availableHeight : 0.5)
            destination = .free(parentID: target?.id, position: position)
        }
        if let destination {
            feedback = .init(ghost: Rect(origin: origin, size: size), target: parentFrame, insertion: insertion, valid: model.canDrop(moving, at: destination))
        }
    }
}
