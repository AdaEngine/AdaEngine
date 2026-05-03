import AdaApp
import AdaECS
import AdaInput
import AdaText
import AdaUI
import AdaUtils
import Math

/// Opens a separate AdaUI debug window that visualizes live AdaUI trees as spaced 2.5D layers.
public struct AdaUIDebug3DPlugin: Plugin {
    private let title: String
    private let size: Size

    public init(
        title: String = "AdaUI 3D Debug View",
        size: Size = Size(width: 1280, height: 820)
    ) {
        self.title = title
        self.size = size
    }

    @MainActor
    public func setup(in app: borrowing AppWorlds) {
        let model = AdaUIDebug3DModel()
        let window = UIWindow(configuration: UIWindow.Configuration(
            title: title,
            frame: Rect(origin: .zero, size: size),
            minimumSize: Size(width: 900, height: 580),
            mode: .windowed,
            background: .opaque(Color.fromHex(0x202327)),
            showsImmediately: false,
            makeKey: false
        ))
        model.debugWindowId = window.id

        let container = UIContainerView(rootView: AdaUIDebug3DView(model: model))
        container.frame = Rect(origin: .zero, size: size)
        container.autoresizingRules = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = Color.fromHex(0x202327)
        window.addSubview(container)
        window.showWindow(makeFocused: false)

        model.refresh()
        app
            .insertResource(AdaUIDebug3DResource(model: model, window: window))
            .addSystem(UpdateAdaUIDebug3DSystem.self, on: .postUpdate)
    }
}

public final class AdaUIDebug3DResource: Resource, @unchecked Sendable {
    @MainActor let model: AdaUIDebug3DModel
    @MainActor weak var window: UIWindow?

    @MainActor
    init(model: AdaUIDebug3DModel, window: UIWindow) {
        self.model = model
        self.window = window
    }
}

@System
@MainActor
func UpdateAdaUIDebug3D(_ resource: Res<AdaUIDebug3DResource>) {
    let debug = resource.wrappedValue
    guard debug.model.autoRefresh else {
        return
    }

    debug.model.refresh()
    debug.window?.setNeedsLayout()
    debug.window?.setNeedsDisplay()
}

@MainActor
final class AdaUIDebug3DModel {
    var debugWindowId: UIWindow.ID?
    var autoRefresh = true
    var selectedRuntimeId: String?
    var zoom: Float = 0.72
    var layerSpacing: Float = 34
    var depthLimit: Int = 80
    var pan = Point(96, 112)

    private(set) var windows: [AdaUIDebug3DWindowSnapshot] = []
    private(set) var lastItems: [AdaUIDebug3DLayout.Item] = []
    private(set) var selectedNode: UINodeSnapshot?
    private(set) var selectedPath: [UINodeSummary] = []

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
            return
        }

        windows = manager.windows.values.compactMap { element in
            let window = element.value
            guard window.id != debugWindowId else {
                return nil
            }

            let roots = window.uiInspectableContainers().flatMap { container in
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
        lastItems = AdaUIDebug3DLayout.project(
            windows: windows,
            projection: projection,
            selectedRuntimeId: selectedRuntimeId
        )
        return lastItems
    }

    func select(at point: Point, viewportSize: Size) {
        let items = project(size: viewportSize)
        guard let item = AdaUIDebug3DLayout.pick(point, in: items) else {
            return
        }

        selectedRuntimeId = item.runtimeId
        resolveSelectedNode()
        highlightSelectedNode()
    }

    func resetCamera() {
        zoom = 0.72
        layerSpacing = 34
        pan = Point(96, 112)
    }

    func zoomBy(_ delta: Float) {
        zoom = min(2.5, max(0.2, zoom + delta))
    }

    func layerSpacingBy(_ delta: Float) {
        layerSpacing = min(140, max(6, layerSpacing + delta))
    }

    func depthLimitBy(_ delta: Int) {
        depthLimit = min(240, max(1, depthLimit + delta))
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

        return items
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
        return Color.fromHex(hue).opacity(node.isInteractable ? 0.34 : 0.18)
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
            .background(Color.fromHex(0x202327))

            inspector
                .frame(width: 360)
                .background(Color.fromHex(0x292D33))
        }
        .onInputEvent(KeyEvent.self) { event in
            handleKey(event)
        }
    }

    private var toolbar: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: {
                model.refresh()
                revision += 1
            }) {
                Text("Refresh")
                    .font(.system(size: 13))
            }

            Button(action: {
                model.autoRefresh.toggle()
                revision += 1
            }) {
                Text(model.autoRefresh ? "Auto On" : "Auto Off")
                    .font(.system(size: 13))
            }

            Button(action: {
                model.resetCamera()
                revision += 1
            }) {
                Text("Reset")
                    .font(.system(size: 13))
            }

            Text("Zoom \(format(model.zoom))")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.78))

            Button(action: {
                model.zoomBy(-0.1)
                revision += 1
            }) {
                Text("-")
                    .font(.system(size: 16))
            }

            Button(action: {
                model.zoomBy(0.1)
                revision += 1
            }) {
                Text("+")
                    .font(.system(size: 16))
            }

            Text("Layer \(Int(model.layerSpacing))")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.78))

            Button(action: {
                model.layerSpacingBy(-6)
                revision += 1
            }) {
                Text("-")
                    .font(.system(size: 16))
            }

            Button(action: {
                model.layerSpacingBy(6)
                revision += 1
            }) {
                Text("+")
                    .font(.system(size: 16))
            }

            Text("Depth \(model.depthLimit)")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.78))

            Button(action: {
                model.depthLimitBy(-8)
                revision += 1
            }) {
                Text("-")
                    .font(.system(size: 16))
            }

            Button(action: {
                model.depthLimitBy(8)
                revision += 1
            }) {
                Text("+")
                    .font(.system(size: 16))
            }

            Spacer()
        }
        .frame(height: 36)
    }

    private var viewport: some View {
        ZStack {
            Canvas { context, size in
                drawScene(context: &context, size: size)
            }

            Color.clear
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if let lastDragLocation {
                                model.pan = Point(
                                    model.pan.x + value.location.x - lastDragLocation.x,
                                    model.pan.y + value.location.y - lastDragLocation.y
                                )
                            }
                            lastDragLocation = value.location
                            revision += 1
                        }
                        .onEnded { value in
                            lastDragLocation = nil
                            if abs(value.translation.width) < 3, abs(value.translation.height) < 3 {
                                model.select(at: value.location, viewportSize: Size(width: 1, height: 1))
                            }
                            revision += 1
                        }
                )
        }
        .background(Color.fromHex(0x1A1D21))
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
    }

    private func drawScene(context: inout UIGraphicsContext, size: Size) {
        let _ = revision
        context.drawRect(Rect(origin: .zero, size: size), color: Color.fromHex(0x1A1D21))
        drawGrid(context: &context, size: size)

        let items = model.project(size: size)
        for item in items.sorted(by: { $0.depth < $1.depth }) {
            drawItem(item, context: &context)
        }

        if items.isEmpty {
            drawText("No AdaUI windows to inspect", in: Rect(x: 28, y: 36, width: 360, height: 28), color: Color.white.opacity(0.7), context: context)
        }
    }

    private func drawGrid(context: inout UIGraphicsContext, size: Size) {
        let color = Color.white.opacity(0.06)
        var x: Float = 0
        while x < size.width {
            context.drawLine(start: Vector2(x, 0), end: Vector2(x, -size.height), lineWidth: 1, color: color)
            x += 80
        }
        var y: Float = 0
        while y < size.height {
            context.drawLine(start: Vector2(0, -y), end: Vector2(size.width, -y), lineWidth: 1, color: color)
            y += 80
        }
    }

    private func drawItem(_ item: AdaUIDebug3DLayout.Item, context: inout UIGraphicsContext) {
        let rect = item.rect
        let stroke = item.isSelected ? Color.fromHex(0x2D7EFF) : Color.white.opacity(item.isInteractable ? 0.44 : 0.22)
        context.drawRect(rect, color: item.isSelected ? Color.fromHex(0x2D7EFF).opacity(0.22) : item.color)
        drawBorder(rect, color: stroke, lineWidth: item.isSelected ? 3 : 1, context: context)

        if rect.width > 42, rect.height > 18 {
            drawText(item.label, in: Rect(x: rect.origin.x + 5, y: rect.origin.y + 4, width: rect.width - 10, height: 18), color: Color.white.opacity(0.78), context: context)
        }
    }

    private func drawBorder(_ rect: Rect, color: Color, lineWidth: Float, context: UIGraphicsContext) {
        context.drawLine(start: Vector2(rect.minX, -rect.minY), end: Vector2(rect.maxX, -rect.minY), lineWidth: lineWidth, color: color)
        context.drawLine(start: Vector2(rect.minX, -rect.maxY), end: Vector2(rect.maxX, -rect.maxY), lineWidth: lineWidth, color: color)
        context.drawLine(start: Vector2(rect.minX, -rect.minY), end: Vector2(rect.minX, -rect.maxY), lineWidth: lineWidth, color: color)
        context.drawLine(start: Vector2(rect.maxX, -rect.minY), end: Vector2(rect.maxX, -rect.maxY), lineWidth: lineWidth, color: color)
    }

    private func drawText(_ string: String, in rect: Rect, color: Color, context: UIGraphicsContext) {
        var attributes = TextAttributeContainer()
        attributes.font = Font.system(size: 11)
        attributes.foregroundColor = color
        context.drawText(AttributedText(string, attributes: attributes), in: rect)
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
