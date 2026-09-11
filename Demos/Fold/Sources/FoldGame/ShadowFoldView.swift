import AdaApp
import AdaECS
import AdaEngine
import AdaInput
import AdaRender
import AdaScene
import AdaUI
import AdaUtils
import Math
import Observation

/// Presents a ShadowLevel across two articulated surfaces while retaining one scene runtime.
public struct ShadowFoldView: View {
    private let pose: Binding<FoldPose>
    private let make: @MainActor (inout AppWorlds) -> Void
    private let onPoseChangeEnd: @MainActor () -> Void
    @State private var session = ShadowFoldSession()

    public init(pose: Binding<FoldPose>, onPoseChangeEnd: @escaping @MainActor () -> Void = {},
                make: @escaping @MainActor (inout AppWorlds) -> Void) {
        self.pose = pose; self.make = make; self.onPoseChangeEnd = onPoseChangeEnd
    }

    public var body: some View {
        let _ = session.configure(pose: pose, onPoseChangeEnd: onPoseChangeEnd)
        GeometryReader { geometry in
            let _ = session.viewportSize = geometry.size
            ZStack {
                SceneView(make: { app in
                    app.addPlugin(ShadowPlatformerPlugin())
                    app.main.insertResource(pose.wrappedValue)
                    make(&app)
                }, updateContent: { world, delta in session.update(world: world, delta: delta) })
                    .frame(width: geometry.size.width, height: geometry.size.height).allowsHitTesting(false)
                ShadowSurface(session: session, simulation: session.simulation).accessibilityIdentifier("ShadowFold.Stage")
                if let controls = session.controlsView { ShadowControlsSurface(view: controls) }
                if let error = session.error { Text(error).foregroundColor(.red).padding(30) }
            }
        }
    }
}

@MainActor @Observable
final class ShadowFoldSession {
    var simulation: ShadowSimulation?
    var controlsView: UIView?
    var error: String?
    @ObservationIgnored var viewportSize = Size.zero
    @ObservationIgnored private var lighting = FoldLightingScene()
    @ObservationIgnored var keyboard = ShadowKeyboardInput()
    @ObservationIgnored var lastSentAngle: Float?
    @ObservationIgnored var heldKeys: Set<KeyCode> = []
    @ObservationIgnored var pose = Binding<FoldPose>.constant(FoldPose())
    @ObservationIgnored var onPoseChangeEnd: @MainActor () -> Void = {}

    func configure(pose: Binding<FoldPose>, onPoseChangeEnd: @escaping @MainActor () -> Void) {
        self.pose = pose; self.onPoseChangeEnd = onPoseChangeEnd
    }

    func update(world: World, delta: Float) {
        if let game = world.getResource(ShadowRuntime.self)?.simulation, let sent = lastSentAngle,
           abs(pose.wrappedValue.angle - sent) < 0.01, abs(game.pose.angle - sent) > 0.01 {
            pose.wrappedValue = game.pose
        }
        var requested = pose.wrappedValue
        let direction: Float = (heldKeys.contains(.e) ? 1 : 0) - (heldKeys.contains(.q) ? 1 : 0)
        if direction != 0 { requested.angle = min(180, max(45, requested.angle + direction * delta * 75)); pose.wrappedValue = requested }
        requested.showsOuter = world.getResource(FoldPose.self)?.showsOuter ?? false
        lastSentAngle = requested.angle
        world.insertResource(requested)
        keyboard.value.moveX = (heldKeys.contains(.d) ? 1 : 0) - (heldKeys.contains(.a) ? 1 : 0)
        world.insertResource(keyboard)
        keyboard.outerDrag = nil
        if let runtime = world.getResource(ShadowRuntime.self) {
            simulation = runtime.simulation
            if let simulation { lighting.update(world: world, game: simulation, size: viewportSize) }
            if error != runtime.error { error = runtime.error }
        }
        if controlsView == nil {
            for entity in world.getEntities() {
                guard let panel = entity.components[CompanionPanel.self] else { continue }
                do { controlsView = try panel.ui.resolveView(runtime: world.getResource(UIComponentRuntimeResource.self)?.runtime) }
                catch { self.error = error.localizedDescription }
                break
            }
        }
    }

    func key(_ event: KeyEvent) {
        if event.status == .up { heldKeys.remove(event.keyCode); onPoseChangeEnd(); return }
        heldKeys.insert(event.keyCode)
        guard !event.isRepeated else { return }
        switch event.keyCode {
        case .space: keyboard.value.jump &+= 1
        case .f: keyboard.value.flip &+= 1
        case .t: keyboard.value.transfer &+= 1
        case .r: keyboard.value.restart &+= 1
        case .escape: heldKeys.removeAll(); keyboard.value.moveX = 0
        default: break
        }
    }
}

private struct ShadowSurface: UIViewRepresentable {
    let session: ShadowFoldSession
    let simulation: ShadowSimulation?
    func makeUIView(in context: Context) -> ShadowFoldHost {
        let view = ShadowFoldHost(); view.backgroundColor = .clear; return view
    }
    func updateUIView(_ view: ShadowFoldHost, in context: Context) { view.session = session; view.simulation = simulation; view.setNeedsDisplay() }
}

private struct ShadowControlsSurface: UIViewRepresentable {
    let view: UIView
    func makeUIView(in context: Context) -> UIView { view }
    func updateUIView(_ view: UIView, in context: Context) {}
}

final class ShadowFoldHost: UIView {
    var session: ShadowFoldSession?
    var simulation: ShadowSimulation?
    private var dragging = false
    private var angleDrag = false
    private var contact: RID?
    override var acceptsKeyboardFocus: Bool { true }

    override func draw(in rect: Rect, with context: UIGraphicsContext) {
        guard let game = simulation else { return }
        drawGame(game, in: rect, context: context)
    }

    override func onKeyEvent(_ event: KeyEvent) { session?.key(event) }

    override func onFocusChanged(isFocused: Bool) {
        if !isFocused { session?.heldKeys.removeAll(); session?.keyboard.value.moveX = 0; finish() }
    }

    override func onMouseEvent(_ event: MouseEvent) {
        switch event.phase {
        case .began: begin(event.mousePosition)
        case .changed: move(event.mousePosition)
        case .ended, .cancelled: finish()
        }
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        for touch in touches {
            if touch.phase == .began, contact == nil { contact = touch.contactID; begin(touch.location) }
            guard touch.contactID == contact else { continue }
            if touch.phase == .ended || touch.phase == .cancelled { finish(); contact = nil }
            else { move(touch.location) }
        }
    }

    private func begin(_ point: Point) {
        guard let game = session?.simulation else { return }
        angleDrag = !game.pose.showsOuter && abs(point.y - (bounds.height - 145)) < 24
        if game.pose.showsOuter, !game.transferred {
            let mapping = ShadowScreenMapping(size: bounds.size, pose: game.pose)
            let item = mapping.outer(Vector2(game.plate.position.x, game.plate.position.y))
            dragging = abs(point.x - item.x) < 50 && abs(point.y - item.y) < 50
        }
        move(point)
    }

    private func move(_ point: Point) {
        guard let session else { return }
        if angleDrag {
            var pose = session.pose.wrappedValue
            pose.angle = min(180, max(45, 45 + (point.x - bounds.width / 2 + 160) / 320 * 135))
            session.pose.wrappedValue = pose
        }
        if dragging, let game = session.simulation {
            session.keyboard.outerDrag = ShadowScreenMapping(size: bounds.size, pose: game.pose).outerLocal(Vector2(point.x, point.y))
        }
        setNeedsDisplay()
    }

    private func finish() { dragging = false; angleDrag = false; session?.onPoseChangeEnd() }
}
