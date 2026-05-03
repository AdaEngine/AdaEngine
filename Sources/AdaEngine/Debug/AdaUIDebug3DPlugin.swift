import AdaApp
import AdaECS
import AdaInput
@_spi(Internal) import AdaRender
import AdaSprite
import AdaTransform
import AdaUI
import AdaUtils
import Math

/// Opens a separate AdaUI debug window that visualizes live AdaUI trees as spaced 2.5D layers.
public struct AdaUIDebug3DPlugin: Plugin {
    public enum Presentation: Sendable {
        case separateWindow
        case primaryWindowOverlay
        case separateWindowAndOverlay
    }

    private let title: String
    private let size: Size
    private let presentation: Presentation

    public init(
        title: String = "AdaUI 3D Debug View",
        size: Size = Size(width: 1280, height: 820),
        presentation: Presentation = .separateWindow
    ) {
        self.title = title
        self.size = size
        self.presentation = presentation
    }

    @MainActor
    public func setup(in app: borrowing AppWorlds) {
        let model = AdaUIDebug3DModel()
        app
            .insertResource(AdaUIDebug3DResource(title: title, size: size, presentation: presentation, model: model))
            .addSystem(StartupAdaUIDebug3DSystem.self, on: .startup)
            .addSystem(UpdateAdaUIDebug3DSystem.self, on: .postUpdate)
    }

    @MainActor
    public func finish(for app: borrowing AppWorlds) {
        guard let debug = app.getResource(AdaUIDebug3DResource.self) else {
            return
        }

        debug.ensureSurfaces()
        debug.synchronizeOverlayFrame()
        debug.window?.setNeedsLayout()
        debug.window?.setNeedsDisplay()
        debug.overlayView?.setNeedsLayout()
        debug.overlayView?.setNeedsDisplay()
    }
}

public final class AdaUIDebug3DResource: Resource, @unchecked Sendable {
    @MainActor let title: String
    @MainActor let size: Size
    @MainActor let presentation: AdaUIDebug3DPlugin.Presentation
    @MainActor let model: AdaUIDebug3DModel
    @MainActor weak var window: UIWindow?
    @MainActor weak var overlayView: UIView?
    @MainActor private var didCreateWindow = false
    @MainActor private var didCreateOverlay = false
    @MainActor private var refreshAccumulator: TimeInterval = 0
    @MainActor private let autoRefreshInterval: TimeInterval = 0.35

    @MainActor
    init(
        title: String,
        size: Size,
        presentation: AdaUIDebug3DPlugin.Presentation,
        model: AdaUIDebug3DModel
    ) {
        self.title = title
        self.size = size
        self.presentation = presentation
        self.model = model
    }

    @MainActor
    func ensureSurfaces() {
        switch presentation {
        case .separateWindow:
            ensureWindow()
        case .primaryWindowOverlay:
            ensurePrimaryWindowOverlay()
        case .separateWindowAndOverlay:
            ensureWindow()
            ensurePrimaryWindowOverlay()
        }
    }

    @MainActor
    func synchronizeOverlayFrame() {
        guard let overlayView,
              let appWorlds = AppWorldsSession.current,
              let primaryWindow = appWorlds.getResource(PrimaryWindow.self)?.window else {
            return
        }

        let expectedFrame = Rect(origin: .zero, size: primaryWindow.frame.size)
        guard overlayView.frame != expectedFrame else {
            return
        }

        overlayView.frame = expectedFrame
        overlayView.setNeedsLayout()
        overlayView.setNeedsDisplay()
    }

    @MainActor
    func autoRefreshIfNeeded(deltaTime: TimeInterval) -> Bool {
        guard model.autoRefresh else {
            refreshAccumulator = 0
            return false
        }

        refreshAccumulator += deltaTime
        guard refreshAccumulator >= autoRefreshInterval else {
            return false
        }

        refreshAccumulator = 0
        model.refresh()
        return true
    }

    @MainActor
    private func ensureWindow() {
        guard !didCreateWindow, window == nil else {
            return
        }
        didCreateWindow = true

        let window = UIWindow(configuration: UIWindow.Configuration(
            title: title,
            frame: Rect(x: 80, y: 80, width: size.width, height: size.height),
            minimumSize: Size(width: 900, height: 580),
            mode: .windowed,
            background: .opaque(Color.fromHex(0x202327)),
            level: .floating,
            showsImmediately: false,
            makeKey: false
        ))
        model.debugWindowId = window.id

        let container = UIContainerView(rootView: AdaUIDebug3DView(model: model))
        container.frame = Rect(origin: .zero, size: size)
        container.autoresizingRules = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = Color.fromHex(0x202327)
        window.addSubview(container)
        window.showWindow(makeFocused: true)

        model.refresh()
        self.window = window
    }

    @MainActor
    private func ensurePrimaryWindowOverlay() {
        guard !didCreateOverlay, overlayView == nil else {
            return
        }
        guard let appWorlds = AppWorldsSession.current,
              let primaryWindow = appWorlds.getResource(PrimaryWindow.self)?.window else {
            return
        }

        didCreateOverlay = true

        let overlay = UIContainerView(rootView: AdaUIDebug3DView(model: model))
        overlay.frame = Rect(origin: .zero, size: primaryWindow.frame.size)
        overlay.autoresizingRules = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = Color.fromHex(0x202327)
        overlay.zIndex = Int.max
        primaryWindow.addSubview(overlay)
        model.ignoredContainerIds.insert(ObjectIdentifier(overlay))
        model.refresh()
        overlay.setNeedsLayout()
        overlay.setNeedsDisplay()
        self.overlayView = overlay
    }
}

@System
@MainActor
func StartupAdaUIDebug3D(_ resource: Res<AdaUIDebug3DResource>) {
    let debug = resource.wrappedValue
    debug.ensureSurfaces()
    debug.synchronizeOverlayFrame()
    debug.window?.setNeedsLayout()
    debug.window?.setNeedsDisplay()
    debug.overlayView?.setNeedsLayout()
    debug.overlayView?.setNeedsDisplay()
}

@System
@MainActor
func UpdateAdaUIDebug3D(_ resource: Res<AdaUIDebug3DResource>, _ deltaTime: Res<DeltaTime>) {
    let debug = resource.wrappedValue
    debug.ensureSurfaces()
    debug.synchronizeOverlayFrame()

    guard debug.autoRefreshIfNeeded(deltaTime: deltaTime.deltaTime) else {
        return
    }
    debug.window?.setNeedsLayout()
    debug.window?.setNeedsDisplay()
    debug.overlayView?.setNeedsLayout()
    debug.overlayView?.setNeedsDisplay()
}

@MainActor
final class AdaUIDebug3DModel {
    var debugWindowId: UIWindow.ID?
    var ignoredContainerIds: Set<ObjectIdentifier> = []
    var autoRefresh = true
    var selectedRuntimeId: String?
    var zoom: Float = 0.44
    var layerSpacing: Float = 24
    var depthLimit: Int = 36
    var pan = Point(48, 72)

    private(set) var windows: [AdaUIDebug3DWindowSnapshot] = []
    private(set) var lastItems: [AdaUIDebug3DLayout.Item] = []
    private(set) var selectedNode: UINodeSnapshot?
    private(set) var selectedPath: [UINodeSummary] = []
    private var snapshotVersion = 0
    private var cachedProjectionKey: ProjectionCacheKey?
    private var cachedProjectedItems: [AdaUIDebug3DLayout.Item] = []
    private weak var sceneWorld: World?
    private var sceneEntityId: Entity.ID?
    private var sceneMaterial = CustomMaterial(AdaUIDebugVertexColorMaterial())
    private var sceneKey: ProjectionCacheKey?

    var selectedDescriptionLines: [String] {
        guard let node = selectedNode else {
            return ["No view selected", "Click a layer in the scene."]
        }

        var lines = [
            "Type: \(shortType(node.viewType))",
            "Node: \(shortType(node.nodeType))",
            "Runtime: \(node.runtimeId)",
            "Accessibility: \(node.accessibilityIdentifier ?? "-")",
            "Frame: \(format(node.frame))",
            "Absolute: \(format(node.absoluteFrame))",
            "Focused: \(node.isFocused ? "yes" : "no")",
            "Focusable: \(node.canBecomeFocused ? "yes" : "no")",
            "Interactable: \(node.isInteractable ? "yes" : "no")"
        ]

        if let hidden = node.isHidden {
            lines.append("Hidden: \(hidden ? "yes" : "no")")
        }

        return lines
    }

    var selectedPathLines: [String] {
        selectedPath.map { summary in
            "\(shortType(summary.viewType))  \(summary.accessibilityIdentifier ?? summary.runtimeId)"
        }
    }

    func refresh() {
        guard let manager = UIWindowManager.shared else {
            windows = []
            selectedNode = nil
            selectedPath = []
            invalidateProjection()
            return
        }

        let nextWindows: [AdaUIDebug3DWindowSnapshot] = manager.windows.values.compactMap { element in
            let window = element.value
            guard window.id != debugWindowId else {
                return nil
            }

            let roots = window.uiInspectableContainers().filter { container in
                !ignoredContainerIds.contains(ObjectIdentifier(container))
            }.flatMap { container in
                container.uiTreeRoots()
            }

            guard !roots.isEmpty else {
                return nil
            }

            return AdaUIDebug3DWindowSnapshot(
                id: window.id,
                title: window.title.isEmpty ? "Window \(window.id.id)" : window.title,
                frame: window.frame,
                roots: roots
            )
        }

        guard !nextWindows.isEmpty || windows.isEmpty else {
            return
        }

        windows = nextWindows
        snapshotVersion += 1
        invalidateProjection()
        resolveSelectedNode()
    }

    func project(size: Size) -> [AdaUIDebug3DLayout.Item] {
        let projection = AdaUIDebug3DProjection(
            zoom: zoom,
            layerSpacing: layerSpacing,
            pan: pan,
            viewportSize: size,
            depthLimit: depthLimit
        )
        let key = ProjectionCacheKey(
            snapshotVersion: snapshotVersion,
            projection: projection,
            selectedRuntimeId: selectedRuntimeId
        )
        if cachedProjectionKey == key {
            lastItems = cachedProjectedItems
            syncSceneIfNeeded(items: cachedProjectedItems, viewportSize: size, key: key)
            return cachedProjectedItems
        }

        lastItems = AdaUIDebug3DLayout.project(
            windows: windows,
            projection: projection,
            selectedRuntimeId: selectedRuntimeId
        )
        cachedProjectionKey = key
        cachedProjectedItems = lastItems
        syncSceneIfNeeded(items: lastItems, viewportSize: size, key: key)
        return lastItems
    }

    func attachSceneWorld(_ world: World) {
        sceneWorld = world
        configureSceneCamera(viewportSize: Size(width: 1280, height: 820))
        sceneKey = nil
        if !cachedProjectedItems.isEmpty, let cachedProjectionKey {
            syncSceneIfNeeded(items: cachedProjectedItems, viewportSize: cachedProjectionKey.projection.viewportSize, key: cachedProjectionKey)
        }
    }

    func select(at point: Point, viewportSize: Size) {
        let items = lastItems.isEmpty ? project(size: viewportSize) : lastItems
        guard let item = AdaUIDebug3DLayout.pick(point, in: items) else {
            return
        }

        selectedRuntimeId = item.runtimeId
        invalidateProjection()
        resolveSelectedNode()
        highlightSelectedNode()
    }

    func resetCamera() {
        zoom = 0.44
        layerSpacing = 24
        depthLimit = 36
        pan = Point(48, 72)
        invalidateProjection()
    }

    func zoomBy(_ delta: Float) {
        zoom = min(2.5, max(0.2, zoom + delta))
        invalidateProjection()
    }

    func layerSpacingBy(_ delta: Float) {
        layerSpacing = min(140, max(6, layerSpacing + delta))
        invalidateProjection()
    }

    func depthLimitBy(_ delta: Int) {
        depthLimit = min(240, max(1, depthLimit + delta))
        invalidateProjection()
    }

    func setPan(_ newPan: Point) {
        pan = newPan
        invalidateProjection()
    }

    private func invalidateProjection() {
        cachedProjectionKey = nil
        sceneKey = nil
    }

    private func syncSceneIfNeeded(items: [AdaUIDebug3DLayout.Item], viewportSize: Size, key: ProjectionCacheKey) {
        guard sceneKey != key else {
            return
        }
        sceneKey = key
        rebuildScene(items: items, viewportSize: viewportSize)
    }

    private func rebuildScene(items: [AdaUIDebug3DLayout.Item], viewportSize: Size) {
        guard let world = sceneWorld,
              let device = world.getResource(RenderDeviceHandler.self) else {
            return
        }

        configureSceneCamera(viewportSize: viewportSize)

        let worldScale = sceneWorldScale(viewportSize: viewportSize)
        let mesh = makeBatchedLayerMesh(items: items, viewportSize: viewportSize, worldScale: worldScale, renderDevice: device.renderDevice)

        if let sceneEntityId, let entity = world.getEntityByID(sceneEntityId) {
            entity.components += Mesh2D(mesh: mesh, materials: [sceneMaterial])
            entity.components += Transform()
            return
        }

        let entity = world.spawn("AdaUI Debug Layers") {
            Mesh2D(mesh: mesh, materials: [sceneMaterial])
            Transform()
        }
        sceneEntityId = entity.id
        world.flush()
    }

    private func makeBatchedLayerMesh(
        items: [AdaUIDebug3DLayout.Item],
        viewportSize: Size,
        worldScale: Float,
        renderDevice: RenderDevice
    ) -> Mesh {
        var descriptor = MeshDescriptor(name: "AdaUI Debug Layers")
        descriptor.primitiveTopology = .triangleList

        var positions: [Vector3] = []
        var colors: [Color] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(items.count * 4)
        colors.reserveCapacity(items.count * 4)
        indices.reserveCapacity(items.count * 6)

        let sortedItems = items.sorted { lhs, rhs in
            if lhs.depth == rhs.depth {
                return lhs.rect.area > rhs.rect.area
            }
            return lhs.depth < rhs.depth
        }

        for item in sortedItems {
            let rect = item.rect
            guard rect.width > 0, rect.height > 0 else {
                continue
            }

            let depth = Float(item.depth)
            let depthOffset = depth * max(12, layerSpacing * 1.8)
            let parallax = depth * layerSpacing * 0.35
            let x = (rect.midX - viewportSize.width * 0.5 + parallax) * worldScale
            let y = (viewportSize.height * 0.5 - rect.midY + parallax * 0.22) * worldScale
            let z = -depthOffset * worldScale
            let fillAlpha: Float = item.isSelected ? 0.86 : (item.isInteractable ? 0.42 : 0.2)
            let color = item.isSelected ? Color.fromHex(0x2D7EFF).opacity(fillAlpha) : item.color.opacity(fillAlpha)

            let halfWidth = max(0.5, rect.width * worldScale * 0.5)
            let halfHeight = max(0.5, rect.height * worldScale * 0.5)
            let skew = halfWidth * 0.18
            let vertexStart = UInt32(positions.count)
            positions.append(contentsOf: [
                Vector3(x - halfWidth + skew, y - halfHeight, z),
                Vector3(x + halfWidth + skew, y - halfHeight, z),
                Vector3(x + halfWidth - skew, y + halfHeight, z),
                Vector3(x - halfWidth - skew, y + halfHeight, z)
            ])
            colors.append(contentsOf: [color, color, color, color])
            indices.append(contentsOf: [
                vertexStart, vertexStart + 1, vertexStart + 2,
                vertexStart + 2, vertexStart + 3, vertexStart
            ])
        }

        if positions.isEmpty {
            positions = [
                Vector3(-1, -1, -1),
                Vector3(1, -1, -1),
                Vector3(1, 1, -1),
                Vector3(-1, 1, -1)
            ]
            colors = Array(repeating: Color.clear, count: 4)
            indices = [0, 1, 2, 2, 3, 0]
        }

        descriptor.positions = MeshBuffer(positions)
        descriptor.colors = MeshBuffer(colors)
        descriptor.indicies = indices
        return Mesh.generate(from: [descriptor], renderDevice: renderDevice)
    }

    private func configureSceneCamera(viewportSize: Size) {
        guard let world = sceneWorld else {
            return
        }

        let safeWidth = max(1, viewportSize.width)
        let safeHeight = max(1, viewportSize.height)
        let distance = max(safeWidth, safeHeight) * max(1.0, 1.28 / max(0.2, zoom))

        for entity in world.getEntities() {
            guard var camera = entity.components[Camera.self],
                  var transform = entity.components[Transform.self] else {
                continue
            }

            var projection = PerspectiveProjection(near: 0.1, far: 10_000, fieldOfView: .degrees(54), aspectRation: safeWidth / safeHeight)
            projection.updateView(width: safeWidth, height: safeHeight)
            camera.projection = .perspective(projection)
            camera.backgroundColor = Color.fromHex(0x171A1F)
            transform.position = Vector3(0, 0, distance)
            transform.rotation = Quat.identity
            entity.components += camera
            entity.components += transform
            return
        }
    }

    private func sceneWorldScale(viewportSize: Size) -> Float {
        let safeWidth = max(1, viewportSize.width)
        let safeHeight = max(1, viewportSize.height)
        let distance = max(safeWidth, safeHeight) * max(1.0, 1.28 / max(0.2, zoom))
        let fieldOfView = Float(54.0 * .pi / 180.0)
        let focalLength = safeHeight / (2 * tan(fieldOfView * 0.5))
        return max(0.1, distance / max(1, focalLength))
    }

    private func resolveSelectedNode() {
        guard let selectedRuntimeId else {
            selectedNode = nil
            selectedPath = []
            return
        }

        for window in windows {
            for root in window.roots {
                if let path = root.path(toRuntimeId: selectedRuntimeId) {
                    selectedNode = path.last
                    selectedPath = path.map { $0.summary }
                    return
                }
            }
        }

        selectedNode = nil
        selectedPath = []
    }

    private func highlightSelectedNode() {
        guard let selectedRuntimeId else {
            return
        }

        for window in UIWindowManager.shared.windows.values {
            let sourceWindow = window.value
            guard sourceWindow.id != debugWindowId else {
                continue
            }

            for container in sourceWindow.uiInspectableContainers() {
                let matches = container.uiFindNodes(matching: .runtimeID(selectedRuntimeId))
                guard !matches.isEmpty else {
                    continue
                }
                container.uiSetDebugOverlay(.hitTestTarget)
                _ = container.uiHitTest(at: matches[0].absoluteFrame.center)
                return
            }
        }
    }
}

private struct ProjectionCacheKey: Hashable {
    let snapshotVersion: Int
    let projection: AdaUIDebug3DProjection
    let selectedRuntimeId: String?
}

struct AdaUIDebug3DWindowSnapshot: Hashable {
    let id: UIWindow.ID
    let title: String
    let frame: Rect
    let roots: [UINodeSnapshot]
}

struct AdaUIDebug3DProjection: Hashable {
    var zoom: Float
    var layerSpacing: Float
    var pan: Point
    var viewportSize: Size
    var depthLimit: Int
}

enum AdaUIDebug3DLayout {
    struct Item: Identifiable, Hashable {
        let id: String
        let windowId: UIWindow.ID
        let runtimeId: String
        let label: String
        let rect: Rect
        let sourceFrame: Rect
        let depth: Int
        let color: Color
        let isSelected: Bool
        let isInteractable: Bool
    }

    static func project(
        windows: [AdaUIDebug3DWindowSnapshot],
        projection: AdaUIDebug3DProjection,
        selectedRuntimeId: String? = nil
    ) -> [Item] {
        var items: [Item] = []
        var yOffset: Float = 0

        for window in windows {
            let windowOrigin = Point(projection.pan.x, projection.pan.y + yOffset)
            for root in window.roots {
                append(
                    node: root,
                    window: window,
                    depth: 0,
                    baseOrigin: windowOrigin,
                    projection: projection,
                    selectedRuntimeId: selectedRuntimeId,
                    items: &items
                )
            }

            let height = max(window.frame.height * projection.zoom + 160, 240)
            yOffset += height
        }

        return items.sorted { $0.depth < $1.depth }
    }

    static func pick(_ point: Point, in items: [Item]) -> Item? {
        items
            .filter { $0.rect.contains(point: point) }
            .sorted { lhs, rhs in
                if lhs.depth == rhs.depth {
                    return lhs.rect.area < rhs.rect.area
                }
                return lhs.depth > rhs.depth
            }
            .first
    }

    private static func append(
        node: UINodeSnapshot,
        window: AdaUIDebug3DWindowSnapshot,
        depth: Int,
        baseOrigin: Point,
        projection: AdaUIDebug3DProjection,
        selectedRuntimeId: String?,
        items: inout [Item]
    ) {
        guard depth <= projection.depthLimit else {
            return
        }

        let source = node.absoluteFrame
        if source.width > 0, source.height > 0 {
            let offset = Float(depth) * projection.layerSpacing
            let rect = Rect(
                x: baseOrigin.x + source.origin.x * projection.zoom + offset,
                y: baseOrigin.y + source.origin.y * projection.zoom - offset * 0.44,
                width: max(1, source.width * projection.zoom),
                height: max(1, source.height * projection.zoom)
            )

            let viewport = Rect(
                x: -320,
                y: -320,
                width: projection.viewportSize.width + 640,
                height: projection.viewportSize.height + 640
            )
            if rect.intersects(viewport) {
                items.append(Item(
                    id: "\(window.id.id)-\(node.runtimeId)",
                    windowId: window.id,
                    runtimeId: node.runtimeId,
                    label: shortType(node.viewType),
                    rect: rect,
                    sourceFrame: source,
                    depth: depth,
                    color: color(for: node),
                    isSelected: node.runtimeId == selectedRuntimeId,
                    isInteractable: node.isInteractable
                ))
            }
        }

        for child in node.children {
            append(
                node: child,
                window: window,
                depth: depth + 1,
                baseOrigin: baseOrigin,
                projection: projection,
                selectedRuntimeId: selectedRuntimeId,
                items: &items
            )
        }
    }

    private static func color(for node: UINodeSnapshot) -> Color {
        let hash = node.accessibilityIdentifier ?? node.viewType
        var value: UInt64 = 0xcbf29ce484222325
        for byte in hash.utf8 {
            value ^= UInt64(byte)
            value &*= 0x100000001b3
        }
        let hue = Int(value & 0x00FFFFFF)
        return Color.fromHex(hue).opacity(node.isInteractable ? 0.16 : 0.045)
    }
}

struct AdaUIDebug3DView: View {
    let model: AdaUIDebug3DModel
    @State private var revision = 0
    @State private var lastDragLocation: Point?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                toolbar
                viewport
            }
            .padding(12)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.fromHex(0x202327))

            inspector
                .frame(width: 360)
                .background(Color.fromHex(0x292D33))
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.fromHex(0x202327))
        .onInputEvent(KeyEvent.self) { event in
            handleKey(event)
        }
    }

    private var toolbar: some View {
        HStack(alignment: .center, spacing: 10) {
            toolbarButton("Refresh") {
                model.refresh()
                revision += 1
            }

            toolbarButton(model.autoRefresh ? "Auto On" : "Auto Off") {
                model.autoRefresh.toggle()
                revision += 1
            }

            toolbarButton("Reset") {
                model.resetCamera()
                revision += 1
            }

            Text("Zoom \(format(model.zoom))")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.82))

            toolbarButton("-", minWidth: 38) {
                model.zoomBy(-0.1)
                revision += 1
            }

            toolbarButton("+", minWidth: 38) {
                model.zoomBy(0.1)
                revision += 1
            }

            Text("Layer \(Int(model.layerSpacing))")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.82))

            toolbarButton("-", minWidth: 38) {
                model.layerSpacingBy(-6)
                revision += 1
            }

            toolbarButton("+", minWidth: 38) {
                model.layerSpacingBy(6)
                revision += 1
            }

            Text("Depth \(model.depthLimit)")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.82))

            toolbarButton("-", minWidth: 38) {
                model.depthLimitBy(-8)
                revision += 1
            }

            toolbarButton("+", minWidth: 38) {
                model.depthLimitBy(8)
                revision += 1
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.fromHex(0x171A1F))
        .border(Color.white.opacity(0.08), lineWidth: 1)
        .frame(height: 64, alignment: .leading)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .zIndex(10)
    }

    private func toolbarButton(_ title: String, minWidth: Float = 72, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: minWidth, minHeight: 36)
                .background(Color.fromHex(0x252A31))
                .border(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var viewport: some View {
        GeometryReader { proxy in
            viewportContent(size: proxy.size)
        }
        .background(Color.fromHex(0x1A1D21))
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    private func viewportContent(size: Size) -> some View {
        let _ = revision
        let _ = model.project(size: size)
        return ZStack {
            SceneView(setup: { world in
                model.attachSceneWorld(world)
            }) { context in
                context.viewport
            }

            Color.clear
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if let lastDragLocation {
                                model.setPan(Point(
                                    model.pan.x + value.location.x - lastDragLocation.x,
                                    model.pan.y + value.location.y - lastDragLocation.y
                                ))
                            }
                            lastDragLocation = value.location
                            revision += 1
                        }
                        .onEnded { value in
                            lastDragLocation = nil
                            if abs(value.translation.width) < 3, abs(value.translation.height) < 3 {
                                model.select(at: value.location, viewportSize: size)
                            }
                            revision += 1
                        }
                )
        }
        .background(Color.fromHex(0x1A1D21))
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Component Tree")
                .font(.system(size: 18))
                .foregroundColor(.white)

            Text("\(model.windows.count) windows  \(model.lastItems.count) layers")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.58))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.selectedDescriptionLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.82))
                }
            }
            .padding(10)
            .background(Color.fromHex(0x202327))

            Text("Path")
                .font(.system(size: 15))
                .foregroundColor(.white)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(model.selectedPathLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.72))
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }

    private func handleKey(_ event: KeyEvent) {
        guard event.status == .down else {
            return
        }

        switch event.keyCode {
        case .equals, .plus:
            model.zoomBy(0.1)
        case .minus:
            model.zoomBy(-0.1)
        default:
            return
        }
        revision += 1
    }
}

private struct AdaUIDebugVertexColorMaterial: CanvasMaterial {}

private extension UINodeSnapshot {
    var summary: UINodeSummary {
        UINodeSummary(
            runtimeId: runtimeId,
            accessibilityIdentifier: accessibilityIdentifier,
            nodeType: nodeType,
            viewType: viewType,
            frame: frame,
            absoluteFrame: absoluteFrame,
            canBecomeFocused: canBecomeFocused,
            isFocused: isFocused,
            isHidden: isHidden,
            isInteractable: isInteractable
        )
    }

    func path(toRuntimeId runtimeId: String) -> [UINodeSnapshot]? {
        if self.runtimeId == runtimeId {
            return [self]
        }

        for child in children {
            if let path = child.path(toRuntimeId: runtimeId) {
                return [self] + path
            }
        }

        return nil
    }
}

private extension Rect {
    var center: Point {
        Point(midX, midY)
    }

    var area: Float {
        width * height
    }
}

private func shortType(_ type: String) -> String {
    type.split(separator: ".").last.map(String.init) ?? type
}

private func format(_ rect: Rect) -> String {
    "x:\(Int(rect.origin.x)) y:\(Int(rect.origin.y)) w:\(Int(rect.width)) h:\(Int(rect.height))"
}

private func format(_ value: Float) -> String {
    let scaled = (value * 100).rounded() / 100
    return "\(scaled)"
}
