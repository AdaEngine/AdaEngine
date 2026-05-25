@_spi(AdaEngine) import AdaEngine

enum EditorSceneViewportDisplayMode: String {
    case twoD = "2D"
    case threeD = "3D"
}

enum EditorSceneViewportTool: String, CaseIterable {
    case select = "Select"
    case translate = "Move"
    case scale = "Scale"
    case rotate = "Rotate"
}

@MainActor
final class EditorSceneViewportModel {
    private weak var world: World?
    private var cameraEntityID: Entity.ID?
    private var displayMode: EditorSceneViewportDisplayMode = .twoD
    private var viewportSize: Size = .zero
    private var entitiesByEditorID: [String: Entity.ID] = [:]
    private var editorIDsByEntityID: [Entity.ID: String] = [:]
    private var sceneContent = ""
    private var sceneModel: EditorSceneModel?
    private var selectedEditorID: String?
    private var activeTool: EditorSceneViewportTool = .translate

    private var twoDCenter = Vector2.zero
    private var twoDZoom: Float = 1
    private var threeDPosition = Vector3(0, 6, -10)
    private var threeDYaw: Float = 0
    private var threeDPitch: Float = -0.42

    private var pressedKeys: Set<KeyCode> = []
    private var lastMousePosition: Point?
    private var mouseDownPosition: Point?
    private var transformDrag: TransformDrag?
    private var isTwoDPanning = false
    private var isThreeDRotating = false
    private var lastTouchPosition: Point?

    var onSelectEntity: ((String?) -> Void)?
    private var onSelectionChanged: ((EditorInspectorSidebarViewModel.SelectedEntity?) -> Void)?
    private var onDocumentContentChanged: ((String) -> Void)?

    private struct TransformDrag {
        var editorID: String
        var startMousePosition: Point
        var startPayload: EditorComponentPayload
    }

    @discardableResult
    func configure(
        sceneContent: String,
        onSelectionChanged: @escaping (EditorInspectorSidebarViewModel.SelectedEntity?) -> Void,
        onDocumentContentChanged: @escaping (String) -> Void
    ) -> EditorSceneRuntimeLoadResult? {
        let contentChanged = self.sceneContent != sceneContent
        self.sceneContent = sceneContent
        self.onSelectionChanged = onSelectionChanged
        self.onDocumentContentChanged = onDocumentContentChanged
        self.onSelectEntity = { [weak self] editorID in
            self?.selectEntity(editorID)
        }

        guard contentChanged else {
            return nil
        }

        sceneModel = EditorSceneFileLoader.model(from: sceneContent)
        guard let model = sceneModel else {
            return nil
        }
        selectedEditorID = model.editor?.selectedEntity
        let loadResult = reloadSceneRuntimeIfReady()
        onSelectionChanged(selectedEntityViewModel(editorID: selectedEditorID, model: model))
        return loadResult
    }

    func disconnect() {
        world = nil
        cameraEntityID = nil
        entitiesByEditorID.removeAll()
        editorIDsByEntityID.removeAll()
        pressedKeys.removeAll()
        lastMousePosition = nil
        mouseDownPosition = nil
        transformDrag = nil
        isTwoDPanning = false
        isThreeDRotating = false
        lastTouchPosition = nil
        onSelectEntity = nil
        onSelectionChanged = nil
        onDocumentContentChanged = nil
    }

    func attachSceneWorld(_ world: World, loadResult: EditorSceneRuntimeLoadResult) {
        self.world = world
        self.entitiesByEditorID = loadResult.entitiesByEditorID
        self.editorIDsByEntityID = loadResult.editorIDsByEntityID
        cameraEntityID = findCameraEntity(in: world)?.id
        applyCamera()
    }

    @discardableResult
    func reloadSceneRuntimeIfReady() -> EditorSceneRuntimeLoadResult? {
        guard let world else {
            return nil
        }

        let previousEntityIDs = Set(entitiesByEditorID.values)
        entitiesByEditorID.removeAll()
        editorIDsByEntityID.removeAll()
        transformDrag = nil

        for entityID in previousEntityIDs {
            guard entityID != cameraEntityID else {
                continue
            }
            world.removeEntity(entityID, recursively: true)
        }
        world.flush()

        let result = EditorSceneFileLoader.load(content: sceneContent, into: world)
        entitiesByEditorID = result.entitiesByEditorID
        editorIDsByEntityID = result.editorIDsByEntityID
        cameraEntityID = findCameraEntity(in: world)?.id
        applyCamera()
        return result
    }

    func setDisplayMode(_ mode: EditorSceneViewportDisplayMode) {
        guard mode != displayMode else {
            return
        }

        displayMode = mode
        lastMousePosition = nil
        isTwoDPanning = false
        isThreeDRotating = false
        applyCamera()
    }

    func setActiveTool(_ tool: EditorSceneViewportTool) {
        activeTool = tool
    }

    func setViewportSize(_ size: Size) {
        guard size.width > 0 && size.height > 0 && size != viewportSize else {
            return
        }

        viewportSize = size
        applyCamera()
    }

    func update(deltaTime: TimeInterval) -> Bool {
        guard displayMode == .threeD else {
            return false
        }

        let movement = movementVector()
        guard movement.squaredLength > 0 else {
            return false
        }

        let speedMultiplier: Float = pressedKeys.contains(.shift) ? 4 : 1
        let speed = Float(deltaTime) * 8 * speedMultiplier
        threeDPosition += movement.normalized * speed
        applyCamera()
        return true
    }

    func handleInput(_ event: any InputEvent) -> Bool {
        switch event {
        case let keyEvent as KeyEvent:
            return handleKeyEvent(keyEvent)
        case let mouseEvent as MouseEvent:
            return handleMouseEvent(mouseEvent)
        case let touchEvent as TouchEvent:
            return handleTouchEvent(touchEvent)
        default:
            return false
        }
    }

    func drawGrid(in context: inout UIGraphicsContext, size: Size, theme: Theme) {
        switch displayMode {
        case .twoD:
            draw2DGrid(in: &context, size: size, theme: theme)
        case .threeD:
            draw3DGrid(in: &context, size: size, theme: theme)
        }
    }

    func drawGizmos(in context: inout UIGraphicsContext, size: Size, theme: Theme) {
        if let world {
            for icon in EditorGizmoOverlayModel.icons(in: world, editorIDsByEntityID: editorIDsByEntityID) {
                guard let point = projectedPoint(from: icon.position, size: size) else {
                    continue
                }
                let radius = max(5, min(18, icon.size * 8))
                let rect = Rect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                context.fill(CircleShape().path(in: rect), with: color(for: icon, theme: theme).opacity(icon.isExplicit ? 0.86 : 0.58))
            }
        }

        guard let model = sceneModel else {
            return
        }

        for entity in model.entities {
            guard let transformPayload = entity.components[EditorBuiltInComponentType.transform],
                  let point = projectedPoint(from: transformPayload, size: size) else {
                continue
            }

            let isSelected = entity.id == selectedEditorID
            let radius: Float = isSelected ? 6 : 4
            drawViewportMarker(
                at: point,
                radius: radius,
                color: isSelected ? theme.editorColors.purple : theme.editorColors.blue.opacity(0.72),
                in: &context
            )
        }
    }

    private func color(for icon: EditorGizmoOverlayModel.Icon, theme: Theme) -> Color {
        if let color = icon.color {
            return color
        }
        switch icon.kind {
        case .transform:
            return theme.editorColors.blue
        case .light:
            return .yellow
        case .camera:
            return .green
        case .audio:
            return theme.editorColors.purple
        case .custom:
            return theme.editorColors.text
        }
    }

    func updateSelectedGizmo(_ gizmo: EditorGizmo) {
        guard let selectedEditorID else {
            return
        }

        do {
            sceneContent = try EditorSceneYAMLDocument.upsertGizmo(gizmo, entityID: selectedEditorID, in: sceneContent)
            onDocumentContentChanged?(sceneContent)
            if let model = EditorSceneFileLoader.model(from: sceneContent) {
                sceneModel = model
                onSelectionChanged?(selectedEntityViewModel(editorID: selectedEditorID, model: model))
            }
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    var statusSuffix: String {
        switch displayMode {
        case .twoD:
            "2D zoom \(formatted(twoDZoom))"
        case .threeD:
            "3D fly \(formatted(threeDPosition.x)), \(formatted(threeDPosition.y)), \(formatted(threeDPosition.z))"
        }
    }
}

private extension EditorSceneViewportModel {
    func handleKeyEvent(_ event: KeyEvent) -> Bool {
        switch event.status {
        case .down:
            pressedKeys.insert(event.keyCode)
        case .up:
            pressedKeys.remove(event.keyCode)
        }

        switch event.keyCode {
        case .space, .w, .a, .s, .d, .q, .e, .shift:
            return true
        default:
            return false
        }
    }

    func handleMouseEvent(_ event: MouseEvent) -> Bool {
        if event.button == .scrollWheel {
            return handleScroll(event)
        }

        switch displayMode {
        case .twoD:
            return handle2DMouse(event)
        case .threeD:
            return handle3DMouse(event)
        }
    }

    func handle2DMouse(_ event: MouseEvent) -> Bool {
        let wantsPan = pressedKeys.contains(.space) && event.button == .left

        switch event.phase {
        case .began:
            mouseDownPosition = event.mousePosition
            if beginTransformDragIfNeeded(at: event.mousePosition, button: event.button) {
                return true
            }
            guard wantsPan else {
                return event.button == .left
            }
            isTwoDPanning = true
            lastMousePosition = event.mousePosition
            return true
        case .changed:
            if updateTransformDrag(to: event.mousePosition) {
                return true
            }
            guard isTwoDPanning, let lastMousePosition else {
                return false
            }
            pan2D(byScreenDelta: event.mousePosition - lastMousePosition)
            self.lastMousePosition = event.mousePosition
            return true
        case .ended, .cancelled:
            defer {
                isTwoDPanning = false
                lastMousePosition = nil
                mouseDownPosition = nil
                endTransformDrag()
            }
            if transformDrag != nil {
                return true
            }
            guard !isTwoDPanning, event.button == .left, isClickEnd(at: event.mousePosition) else {
                return isTwoDPanning
            }
            onSelectEntity?(pick2D(at: event.mousePosition))
            return true
        }
    }

    func handle3DMouse(_ event: MouseEvent) -> Bool {
        switch event.phase {
        case .began:
            mouseDownPosition = event.mousePosition
            if beginTransformDragIfNeeded(at: event.mousePosition, button: event.button) {
                return true
            }
            guard event.button == .right else {
                return event.button == .left
            }
            isThreeDRotating = true
            lastMousePosition = event.mousePosition
            return true
        case .changed:
            if updateTransformDrag(to: event.mousePosition) {
                return true
            }
            guard isThreeDRotating, let lastMousePosition else {
                return false
            }
            rotate3D(by: event.mousePosition - lastMousePosition)
            self.lastMousePosition = event.mousePosition
            return true
        case .ended, .cancelled:
            defer {
                isThreeDRotating = false
                lastMousePosition = nil
                mouseDownPosition = nil
                endTransformDrag()
            }
            if transformDrag != nil {
                return true
            }
            guard !isThreeDRotating, event.button == .left, isClickEnd(at: event.mousePosition) else {
                return isThreeDRotating
            }
            onSelectEntity?(pick3D(at: event.mousePosition))
            return true
        }
    }

    func isClickEnd(at position: Point) -> Bool {
        guard let mouseDownPosition else {
            return true
        }
        return Vector2(position.x - mouseDownPosition.x, position.y - mouseDownPosition.y).squaredLength < 16
    }

    func beginTransformDragIfNeeded(at position: Point, button: MouseButton) -> Bool {
        guard button == .left,
              activeTool != .select,
              let selectedEditorID,
              let model = sceneModel,
              let entity = model.entities.first(where: { $0.id == selectedEditorID }),
              let payload = entity.components[EditorBuiltInComponentType.transform],
              let projected = projectedPoint(from: payload, size: viewportSize),
              Vector2(position.x - projected.x, position.y - projected.y).squaredLength < 72 * 72 else {
            return false
        }

        transformDrag = TransformDrag(editorID: selectedEditorID, startMousePosition: position, startPayload: payload)
        return true
    }

    func updateTransformDrag(to position: Point) -> Bool {
        guard let transformDrag,
              var model = sceneModel,
              let entityIndex = model.entities.firstIndex(where: { $0.id == transformDrag.editorID }) else {
            return false
        }

        let delta = position - transformDrag.startMousePosition
        let payload = transformedPayload(from: transformDrag.startPayload, screenDelta: delta)
        model.entities[entityIndex].components[EditorBuiltInComponentType.transform] = payload
        guard let content = try? model.encodedYAML() else {
            return true
        }

        sceneContent = content
        sceneModel = model
        onDocumentContentChanged?(content)
        syncRuntimeTransform(editorID: transformDrag.editorID, payload: payload)
        onSelectionChanged?(selectedEntityViewModel(editorID: transformDrag.editorID, model: model))
        return true
    }

    func endTransformDrag() {
        transformDrag = nil
    }

    func transformedPayload(from payload: EditorComponentPayload, screenDelta: Vector2) -> EditorComponentPayload {
        var payload = payload
        switch activeTool {
        case .select:
            break
        case .translate:
            var position = vector(payload["position"], count: 3, defaultValues: [0, 0, 0])
            let divisor: Float = displayMode == .twoD ? max(0.001, twoDZoom) : 18
            position[0] += Double(screenDelta.x / divisor)
            position[1] += Double(-screenDelta.y / divisor)
            payload["position"] = .array(position.map(EditorSceneValue.double))
        case .scale:
            let factor = max(0.05, Double(1 + (screenDelta.x - screenDelta.y) / 120))
            let scale = vector(payload["scale"], count: 3, defaultValues: [1, 1, 1]).map { max(0.01, $0 * factor) }
            payload["scale"] = .array(scale.map(EditorSceneValue.double))
        case .rotate:
            let angle = Double(screenDelta.x - screenDelta.y) * 0.012
            let z = Double(Math.sin(Float(angle * 0.5)))
            let w = Double(Math.cos(Float(angle * 0.5)))
            let rotation: [EditorSceneValue] = [
                EditorSceneValue.double(0),
                EditorSceneValue.double(0),
                EditorSceneValue.double(z),
                EditorSceneValue.double(w)
            ]
            payload["rotation"] = .array(rotation)
        }
        return payload
    }

    func syncRuntimeTransform(editorID: String, payload: EditorComponentPayload) {
        guard let runtimeID = entitiesByEditorID[editorID],
              let entity = world?.getEntityByID(runtimeID),
              let transform = try? EditorComponentPayloadDecoder.decode(Transform.self, payload: payload) as? Transform else {
            return
        }
        entity.components += transform
    }

    func vector(_ value: EditorSceneValue?, count: Int, defaultValues: [Double]) -> [Double] {
        guard case .array(let values)? = value else {
            return Array(defaultValues.prefix(count))
        }
        var result = values.map { $0.doubleValue ?? 0 }
        if result.count < count {
            result.append(contentsOf: defaultValues.dropFirst(result.count).prefix(count - result.count))
        }
        return Array(result.prefix(count))
    }

    func handleScroll(_ event: MouseEvent) -> Bool {
        switch displayMode {
        case .twoD:
            if event.modifierKeys.contains(.main) || event.modifierKeys.contains(.control) {
                zoom2D(by: event.scrollDelta.y)
            } else {
                pan2D(byScreenDelta: Vector2(event.scrollDelta.x, event.scrollDelta.y) * 72)
            }
        case .threeD:
            let speedMultiplier: Float = event.modifierKeys.contains(.shift) ? 4 : 1
            threeDPosition += front3D * event.scrollDelta.y * speedMultiplier
            applyCamera()
        }

        return true
    }

    func handleTouchEvent(_ event: TouchEvent) -> Bool {
        switch event.phase {
        case .began:
            lastTouchPosition = event.location
            return true
        case .moved:
            guard let lastTouchPosition else {
                return false
            }

            let delta = event.location - lastTouchPosition
            switch displayMode {
            case .twoD:
                pan2D(byScreenDelta: delta)
            case .threeD:
                rotate3D(by: delta)
            }
            self.lastTouchPosition = event.location
            return true
        case .ended, .cancelled:
            if let lastTouchPosition, (event.location - lastTouchPosition).squaredLength < 16 {
                onSelectEntity?(displayMode == .twoD ? pick2D(at: event.location) : pick3D(at: event.location))
            }
            lastTouchPosition = nil
            return true
        }
    }

    func pan2D(byScreenDelta delta: Vector2) {
        twoDCenter.x -= delta.x / twoDZoom
        twoDCenter.y += delta.y / twoDZoom
        applyCamera()
    }

    func zoom2D(by delta: Float) {
        let factor = pow(Float(1.12), delta)
        twoDZoom = min(24, max(0.08, twoDZoom * factor))
        applyCamera()
    }

    func rotate3D(by delta: Vector2) {
        threeDYaw += delta.x * 0.008
        threeDPitch = min(1.45, max(-1.45, threeDPitch + delta.y * 0.008))
        applyCamera()
    }

    func movementVector() -> Vector3 {
        var movement = Vector3.zero
        let front = front3D
        let right = right3D

        if pressedKeys.contains(.w) {
            movement += front
        }
        if pressedKeys.contains(.s) {
            movement -= front
        }
        if pressedKeys.contains(.d) {
            movement += right
        }
        if pressedKeys.contains(.a) {
            movement -= right
        }
        if pressedKeys.contains(.e) {
            movement += .up
        }
        if pressedKeys.contains(.q) {
            movement -= .up
        }

        return movement
    }

    var front3D: Vector3 {
        Vector3(
            Math.sin(threeDYaw) * Math.cos(threeDPitch),
            Math.sin(threeDPitch),
            Math.cos(threeDYaw) * Math.cos(threeDPitch)
        ).normalized
    }

    var right3D: Vector3 {
        Vector3(Math.cos(threeDYaw), 0, -Math.sin(threeDYaw)).normalized
    }

    var up3D: Vector3 {
        front3D.cross(right3D).normalized
    }

    func applyCamera() {
        guard let cameraEntity = cameraEntity() else {
            return
        }

        guard var camera = cameraEntity.components[Camera.self],
              var transform = cameraEntity.components[Transform.self] else {
            return
        }

        switch displayMode {
        case .twoD:
            camera.projection = .orthographic(
                OrthographicProjection(
                    near: -10_000,
                    far: 10_000,
                    viewportOrigin: Vector2(0.5, 0.5),
                    scale: twoDZoom
                )
            )
            camera.backgroundColor = Color.fromHex(0x15181D)
            transform.position = Vector3(twoDCenter.x, twoDCenter.y, 0)
            transform.rotation = .identity
            cameraEntity.components += CameraRenderGraph(
                subgraphLabel: .main2D,
                inputSlot: "view"
            )
        case .threeD:
            let safeWidth = max(1, viewportSize.width)
            let safeHeight = max(1, viewportSize.height)
            var projection = PerspectiveProjection(
                near: 0.1,
                far: 10_000,
                fieldOfView: .degrees(62),
                aspectRation: safeWidth / safeHeight
            )
            projection.updateView(width: safeWidth, height: safeHeight)
            camera.projection = .perspective(projection)
            camera.backgroundColor = Color.fromHex(0x15181D)

            let view = Transform3D.lookAt(
                eye: threeDPosition,
                center: threeDPosition + front3D,
                up: .up
            )
            transform = Transform(matrix: view.inverse)
            cameraEntity.components += CameraRenderGraph(
                subgraphLabel: .main3D,
                inputSlot: "view"
            )
        }

        cameraEntity.components += camera
        cameraEntity.components += transform
    }

    func cameraEntity() -> Entity? {
        guard let world else {
            return nil
        }

        if let cameraEntityID, let entity = world.getEntityByID(cameraEntityID) {
            return entity
        }

        let entity = findCameraEntity(in: world)
        cameraEntityID = entity?.id
        return entity
    }

    func findCameraEntity(in world: World) -> Entity? {
        world.getEntities().first { entity in
            entity.components[Camera.self] != nil && entity.components[Transform.self] != nil
        }
    }
}

extension EditorSceneViewportModel {
    func pick2D(at screenPoint: Point) -> String? {
        guard let world else {
            return nil
        }

        let worldPoint = Vector2(
            twoDCenter.x + (screenPoint.x - viewportSize.width * 0.5) / twoDZoom,
            twoDCenter.y - (screenPoint.y - viewportSize.height * 0.5) / twoDZoom
        )

        return world.getEntities()
            .compactMap { entity -> (editorID: String, sortZ: Float)? in
                guard entity.id != cameraEntityID,
                      let editorID = editorIDsByEntityID[entity.id],
                      let transform = entity.components[Transform.self] else {
                    return nil
                }

                let bounds = entity.components[BoundingComponent.self]
                guard EditorPicking.contains2D(worldPoint, transform: transform, bounds: bounds) else {
                    return nil
                }
                return (editorID, transform.position.z)
            }
            .sorted { lhs, rhs in lhs.sortZ > rhs.sortZ }
            .first?
            .editorID
    }

    func pick3D(at screenPoint: Point) -> String? {
        guard let world else {
            return nil
        }

        let ray = EditorPicking.approximateRay(
            point: screenPoint,
            viewportSize: viewportSize,
            cameraPosition: threeDPosition,
            front: front3D,
            right: right3D
        )

        return world.getEntities()
            .compactMap { entity -> (editorID: String, distance: Float)? in
                guard entity.id != cameraEntityID,
                      let editorID = editorIDsByEntityID[entity.id],
                      let transform = entity.components[Transform.self] else {
                    return nil
                }

                let bounds = entity.components[BoundingComponent.self]
                guard let distance = EditorPicking.intersectionDistance(ray: ray, transform: transform, bounds: bounds) else {
                    return nil
                }
                return (editorID, distance)
            }
            .sorted { lhs, rhs in lhs.distance < rhs.distance }
            .first?
            .editorID
    }
}

private extension EditorSceneViewportModel {
    func selectEntity(_ editorID: String?) {
        selectedEditorID = editorID
        guard var model = sceneModel else {
            onSelectionChanged?(nil)
            return
        }

        model.selectEntity(editorID)
        if let content = try? model.encodedYAML() {
            sceneContent = content
            sceneModel = model
            onDocumentContentChanged?(content)
        }
        onSelectionChanged?(selectedEntityViewModel(editorID: editorID, model: model))
    }

    func selectedEntityViewModel(
        editorID: String?,
        model: EditorSceneModel
    ) -> EditorInspectorSidebarViewModel.SelectedEntity? {
        guard let editorID,
              let entity = model.entities.first(where: { $0.id == editorID }) else {
            return nil
        }

        let transformFields = transformFields(from: entity)
        let componentNames = entity.components.keys.sorted()
        let components = componentNames.map { componentSection(typeName: $0, payload: entity.components[$0] ?? [:]) }
        let addableComponents = EditorComponentRegistry.addableDescriptors(for: entity).map {
            EditorInspectorSidebarViewModel.AddableComponent(
                typeName: $0.typeName,
                displayName: $0.displayName,
                category: $0.category
            )
        }
        let gizmo = decodeGizmo(from: entity)

        return EditorInspectorSidebarViewModel.SelectedEntity(
            editorID: entity.id,
            name: entity.name,
            componentNames: componentNames,
            transformFields: transformFields,
            components: components,
            addableComponents: addableComponents,
            gizmo: gizmo,
            hasExplicitGizmo: entity.components[EditorSceneYAMLDocument.editorGizmoComponentName] != nil
        )
    }

    func componentSection(typeName: String, payload: EditorComponentPayload) -> EditorInspectorSidebarViewModel.ComponentSection {
        guard let descriptor = EditorComponentRegistry.descriptor(named: typeName) else {
            return EditorInspectorSidebarViewModel.ComponentSection(
                typeName: typeName,
                displayName: shortComponentName(typeName),
                fields: [
                    EditorInspectorSidebarViewModel.ComponentField(
                        typeName: typeName,
                        field: EditorComponentField(key: "payload", label: "Payload", kind: .readOnly, isEditable: false),
                        value: payload.description
                    )
                ],
                canRemove: typeName != EditorBuiltInComponentType.transform
            )
        }

        return EditorInspectorSidebarViewModel.ComponentSection(
            typeName: typeName,
            displayName: descriptor.displayName,
            fields: descriptor.fields.map {
                EditorInspectorSidebarViewModel.ComponentField(
                    typeName: typeName,
                    field: $0,
                    value: $0.displayValue(in: payload)
                )
            },
            canRemove: typeName != EditorBuiltInComponentType.transform
        )
    }

    func transformFields(from entity: EditorSceneEntity) -> [EditorInspectorSidebarViewModel.TransformField] {
        guard let payload = entity.components[EditorBuiltInComponentType.transform],
              let descriptor = EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.transform) else {
            return []
        }

        return descriptor.fields.map {
            EditorInspectorSidebarViewModel.TransformField(field: $0, value: $0.displayValue(in: payload))
        }
    }

    func decodeGizmo(from entity: EditorSceneEntity) -> EditorGizmo? {
        guard let payload = entity.components[EditorSceneYAMLDocument.editorGizmoComponentName] else {
            return nil
        }
        return try? EditorComponentPayloadDecoder.decode(EditorGizmo.self, payload: payload) as? EditorGizmo
    }

    func projectedPoint(from transformPayload: EditorComponentPayload, size: Size) -> Point? {
        guard case .array(let position)? = transformPayload["position"], position.count >= 2 else {
            return nil
        }

        let world = Vector2(Float(position[0].doubleValue ?? 0), Float(position[1].doubleValue ?? 0))
        let z = position.count > 2 ? Float(position[2].doubleValue ?? 0) : 0
        return projectedPoint(from: Vector3(world.x, world.y, z), size: size)
    }

    func projectedPoint(from position: Vector3, size: Size) -> Point? {
        let world = Vector2(position.x, position.y)
        switch displayMode {
        case .twoD:
            return Point(
                x: size.width * 0.5 + (world.x - twoDCenter.x) * twoDZoom,
                y: size.height * 0.5 - (world.y - twoDCenter.y) * twoDZoom
            )
        case .threeD:
            return Point(x: size.width * 0.5 + world.x * 18, y: size.height * 0.62 - world.y * 18)
        }
    }

    func shortComponentName(_ componentName: String) -> String {
        componentName.components(separatedBy: ".").last ?? componentName
    }
}

enum EditorPicking {
    static func contains2D(_ point: Vector2, transform: Transform, bounds: BoundingComponent?) -> Bool {
        let aabb = localAABB(from: bounds)
        let fallbackHalfExtent: Float = 0.35
        let halfX = max(abs(aabb.halfExtents.x * transform.scale.x), fallbackHalfExtent)
        let halfY = max(abs(aabb.halfExtents.y * transform.scale.y), fallbackHalfExtent)
        let center = transform.position.xy + aabb.center.xy

        return point.x >= center.x - halfX
            && point.x <= center.x + halfX
            && point.y >= center.y - halfY
            && point.y <= center.y + halfY
    }

    static func intersectionDistance(ray: Ray, transform: Transform, bounds: BoundingComponent?) -> Float? {
        let aabb = localAABB(from: bounds)
        let fallback = Vector3(0.35)
        let halfExtents = Vector3(
            max(abs(aabb.halfExtents.x * transform.scale.x), fallback.x),
            max(abs(aabb.halfExtents.y * transform.scale.y), fallback.y),
            max(abs(aabb.halfExtents.z * transform.scale.z), fallback.z)
        )
        let worldAABB = AABB(center: transform.position + aabb.center, halfExtents: halfExtents)
        return rayAABBIntersectionDistance(ray: ray, aabb: worldAABB)
    }

    static func approximateRay(
        point: Point,
        viewportSize: Size,
        cameraPosition: Vector3,
        front: Vector3,
        right: Vector3
    ) -> Ray {
        let safeWidth = max(1, viewportSize.width)
        let safeHeight = max(1, viewportSize.height)
        let ndc = Vector2(
            (point.x / safeWidth) * 2 - 1,
            1 - (point.y / safeHeight) * 2
        )
        let up = right.cross(front).normalized
        let direction = (front + right * ndc.x + up * ndc.y).normalized
        return Ray(origin: cameraPosition, direction: direction)
    }

    static func rayAABBIntersectionDistance(ray: Ray, aabb: AABB) -> Float? {
        let minPoint = aabb.min
        let maxPoint = aabb.max
        var tMin: Float = -.greatestFiniteMagnitude
        var tMax: Float = .greatestFiniteMagnitude

        for axis in 0..<3 {
            let origin = ray.origin[axis]
            let direction = ray.direction[axis]
            let minValue = minPoint[axis]
            let maxValue = maxPoint[axis]

            if abs(direction) < 0.000_001 {
                if origin < minValue || origin > maxValue {
                    return nil
                }
                continue
            }

            let inverseDirection = 1 / direction
            var near = (minValue - origin) * inverseDirection
            var far = (maxValue - origin) * inverseDirection
            if near > far {
                swap(&near, &far)
            }
            tMin = Swift.max(tMin, near)
            tMax = Swift.min(tMax, far)
            if tMin > tMax {
                return nil
            }
        }

        if tMax < 0 {
            return nil
        }
        return Swift.max(0, tMin)
    }

    private static func localAABB(from bounds: BoundingComponent?) -> AABB {
        guard let bounds else {
            return .empty
        }
        switch bounds.bounds {
        case .aabb(let aabb):
            return aabb
        }
    }
}

private extension EditorSceneViewportModel {
    func draw2DGrid(in context: inout UIGraphicsContext, size: Size, theme: Theme) {
        let safeZoom = max(0.001, twoDZoom)
        let minorStep = niceGridStep(minPixels: 28, zoom: safeZoom)
        let majorStep = minorStep * 5
        let halfWidth = size.width * 0.5 / safeZoom
        let halfHeight = size.height * 0.5 / safeZoom
        let minX = twoDCenter.x - halfWidth
        let maxX = twoDCenter.x + halfWidth
        let minY = twoDCenter.y - halfHeight
        let maxY = twoDCenter.y + halfHeight

        draw2DLines(
            in: &context,
            size: size,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            step: minorStep,
            lineWidth: 1,
            color: theme.editorColors.border.opacity(0.28)
        )
        draw2DLines(
            in: &context,
            size: size,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            step: majorStep,
            lineWidth: 1,
            color: theme.editorColors.border.opacity(0.42)
        )

        if minY <= 0 && maxY >= 0 {
            let y = worldToScreen(Vector2(0, 0), size: size).y
            context.drawLine(
                start: Vector2(0, y),
                end: Vector2(size.width, y),
                lineWidth: 2,
                color: theme.editorColors.blue.opacity(0.55)
            )
        }
        if minX <= 0 && maxX >= 0 {
            let x = worldToScreen(Vector2(0, 0), size: size).x
            context.drawLine(
                start: Vector2(x, 0),
                end: Vector2(x, size.height),
                lineWidth: 2,
                color: theme.editorColors.purple.opacity(0.52)
            )
        }
    }

    func draw2DLines(
        in context: inout UIGraphicsContext,
        size: Size,
        minX: Float,
        maxX: Float,
        minY: Float,
        maxY: Float,
        step: Float,
        lineWidth: Float,
        color: Color
    ) {
        guard step > 0 else {
            return
        }

        var x = floor(minX / step) * step
        while x <= maxX {
            let start = worldToScreen(Vector2(x, minY), size: size)
            let end = worldToScreen(Vector2(x, maxY), size: size)
            drawViewportLine(from: start, to: end, lineWidth: lineWidth, color: color, in: &context)
            x += step
        }

        var y = floor(minY / step) * step
        while y <= maxY {
            let start = worldToScreen(Vector2(minX, y), size: size)
            let end = worldToScreen(Vector2(maxX, y), size: size)
            drawViewportLine(from: start, to: end, lineWidth: lineWidth, color: color, in: &context)
            y += step
        }
    }

    func drawViewportMarker(
        at point: Point,
        radius: Float,
        color: Color,
        in context: inout UIGraphicsContext
    ) {
        let diameter = radius * 2
        context.drawRect(
            Rect(x: point.x - radius, y: point.y - radius, width: diameter, height: diameter),
            color: color.opacity(0.18)
        )
        context.drawRect(
            Rect(x: point.x - radius, y: point.y - 1, width: diameter, height: 2),
            color: color
        )
        context.drawRect(
            Rect(x: point.x - 1, y: point.y - radius, width: 2, height: diameter),
            color: color
        )
    }

    func drawViewportLine(
        from start: Vector2,
        to end: Vector2,
        lineWidth: Float,
        color: Color,
        in context: inout UIGraphicsContext
    ) {
        if abs(start.x - end.x) <= 0.001 {
            let minY = min(start.y, end.y)
            let maxY = max(start.y, end.y)
            context.drawRect(
                Rect(x: start.x - lineWidth * 0.5, y: minY, width: lineWidth, height: max(1, maxY - minY)),
                color: color
            )
            return
        }

        if abs(start.y - end.y) <= 0.001 {
            let minX = min(start.x, end.x)
            let maxX = max(start.x, end.x)
            context.drawRect(
                Rect(x: minX, y: start.y - lineWidth * 0.5, width: max(1, maxX - minX), height: lineWidth),
                color: color
            )
            return
        }

        context.drawLine(start: start, end: end, lineWidth: lineWidth, color: color)
    }

    func draw3DGrid(in context: inout UIGraphicsContext, size: Size, theme: Theme) {
        let step: Float = 1
        let majorEvery = 5
        let extent = max(40, min(240, threeDPosition.length * 5))
        let centerX = floor(threeDPosition.x / step) * step
        let centerZ = floor(threeDPosition.z / step) * step
        let minX = centerX - extent
        let maxX = centerX + extent
        let minZ = centerZ - extent
        let maxZ = centerZ + extent

        var index = Int(floor(minX / step))
        var x = Float(index) * step
        while x <= maxX {
            let isAxis = abs(x) < 0.0001
            let isMajor = index.isMultiple(of: majorEvery)
            let color = isAxis ? theme.editorColors.purple.opacity(0.65) : theme.editorColors.border.opacity(isMajor ? 0.40 : 0.22)
            let width: Float = isAxis ? 2 : 1
            drawProjectedSegment(
                from: Vector3(x, 0, minZ),
                to: Vector3(x, 0, maxZ),
                in: &context,
                size: size,
                lineWidth: width,
                color: color
            )
            index += 1
            x += step
        }

        index = Int(floor(minZ / step))
        var z = Float(index) * step
        while z <= maxZ {
            let isAxis = abs(z) < 0.0001
            let isMajor = index.isMultiple(of: majorEvery)
            let color = isAxis ? theme.editorColors.blue.opacity(0.70) : theme.editorColors.border.opacity(isMajor ? 0.40 : 0.22)
            let width: Float = isAxis ? 2 : 1
            drawProjectedSegment(
                from: Vector3(minX, 0, z),
                to: Vector3(maxX, 0, z),
                in: &context,
                size: size,
                lineWidth: width,
                color: color
            )
            index += 1
            z += step
        }
    }

    func drawProjectedSegment(
        from start: Vector3,
        to end: Vector3,
        in context: inout UIGraphicsContext,
        size: Size,
        lineWidth: Float,
        color: Color
    ) {
        guard let segment = clipSegmentToNearPlane(start: start, end: end),
              let projectedStart = project(segment.start, size: size),
              let projectedEnd = project(segment.end, size: size) else {
            return
        }

        context.drawLine(start: projectedStart, end: projectedEnd, lineWidth: lineWidth, color: color)
    }

    func project(_ worldPoint: Vector3, size: Size) -> Vector2? {
        let relative = worldPoint - threeDPosition
        let front = front3D
        let right = right3D
        let up = up3D
        let cameraX = relative.dot(right)
        let cameraY = relative.dot(up)
        let cameraZ = relative.dot(front)

        guard cameraZ > 0.05 else {
            return nil
        }

        let aspect = max(0.001, size.width / max(1, size.height))
        let focal = 1 / tan(Angle.degrees(62).radians * 0.5)
        let ndcX = (cameraX / cameraZ) * focal / aspect
        let ndcY = (cameraY / cameraZ) * focal

        guard ndcX.isFinite, ndcY.isFinite else {
            return nil
        }

        return Vector2(
            size.width * (0.5 + ndcX * 0.5),
            size.height * (0.5 - ndcY * 0.5)
        )
    }

    func clipSegmentToNearPlane(start: Vector3, end: Vector3) -> (start: Vector3, end: Vector3)? {
        let near: Float = 0.05
        let startDepth = (start - threeDPosition).dot(front3D)
        let endDepth = (end - threeDPosition).dot(front3D)

        if startDepth <= near && endDepth <= near {
            return nil
        }

        var clippedStart = start
        var clippedEnd = end
        if startDepth <= near || endDepth <= near {
            let denominator = endDepth - startDepth
            guard abs(denominator) > 0.0001 else {
                return nil
            }
            let t = (near - startDepth) / denominator
            let clipped = start + (end - start) * t
            if startDepth <= near {
                clippedStart = clipped
            } else {
                clippedEnd = clipped
            }
        }

        return (clippedStart, clippedEnd)
    }

    func worldToScreen(_ point: Vector2, size: Size) -> Vector2 {
        Vector2(
            (point.x - twoDCenter.x) * twoDZoom + size.width * 0.5,
            size.height * 0.5 - (point.y - twoDCenter.y) * twoDZoom
        )
    }

    func niceGridStep(minPixels: Float, zoom: Float) -> Float {
        let rawStep = max(0.0001, minPixels / zoom)
        let exponent = floor(log10(rawStep))
        let magnitude = pow(Float(10), exponent)
        let normalized = rawStep / magnitude

        if normalized <= 1 {
            return magnitude
        } else if normalized <= 2 {
            return 2 * magnitude
        } else if normalized <= 5 {
            return 5 * magnitude
        } else {
            return 10 * magnitude
        }
    }

    func formatted(_ value: Float) -> String {
        EditorSceneModelFormatting.format(Double(value))
    }
}
