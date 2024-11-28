//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

@_spi(AdaEngineEditor) import AdaEngine
import Observation

@Observable
class ViewModel {
    var color = Color.blue
    var isShown = false
}

struct NestedContent: View {

    @State var innerColor: Color = .red

    var body: some View {
        return HStack {
            innerColor
                .preference(key: SomeKey.self, value: "kek")
            Color.green
                .preference(key: SomeKey.self, value: "kek")
        }
    }
}

extension Text.Layout {
    var runs: some RandomAccessCollection<TextRun> {
        flatMap { line in
            line
        }
    }

    var flattenedRuns: some RandomAccessCollection<Glyph> {
        runs.flatMap { $0 }
    }
}

struct AnimatedSineWaveOffsetRender: TextRenderer {
    
    let timeOffset: Double // Time offset

    init(timeOffset: Double) {
        self.timeOffset = timeOffset
    }

    func draw(layout: Text.Layout, in context: inout UIGraphicsContext) {
        let count = layout.flattenedRuns.count // Count all RunSlices in the text layout
        let width = layout.first?.typographicBounds.rect.width ?? 0 // Get the width of the text line
        let height = layout.first?.typographicBounds.rect.height ?? 0 // Get the height of the text line
        // Iterate through each RunSlice and its index
        for (index, glyph) in layout.flattenedRuns.enumerated() {
            // Calculate the sine wave offset for the current character
            let offset = animatedSineWaveOffset(
                forCharacterAt: index,
                amplitude: Double(height) / 2, // Set amplitude to half the line height
                wavelength: Double(width),
                phaseOffset: timeOffset,
                totalCharacters: count
            )
            // Create a copy of the context and translate it
            var copy = context
            copy.translateBy(x: 0, y: Float(offset))
            // Draw the current RunSlice in the modified context
            copy.draw(glyph)
        }

        func animatedSineWaveOffset(forCharacterAt index: Int, amplitude: Double, wavelength: Double, phaseOffset: Double, totalCharacters: Int) -> Double {
            let x = Double(index)
            let position = (x / Double(totalCharacters)) * wavelength
            let radians = ((position + phaseOffset) / wavelength) * 2 * .pi
            return Math.sin(radians) * amplitude
        }
    }
}

struct SomeKey: PreferenceKey {
    static let defaultValue: String = ""
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
}

struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(.white)
            .font(Font.system(size: 13, weight: .bold))
            .background(self.background(in: configuration))
            .border(.black)
    }

    func background(in configuration: Configuration) -> Color {
        if configuration.state.isHighlighted {
            return Color(red: 244 / 255, green: 234 / 255, blue: 234 / 255)
        } else if configuration.state.isSelected {
            return Color.green
        } else {
            return Color(red: 18 / 255, green: 38 / 255, blue: 58 / 255)
        }
    }
}

struct ContentView: View {

    @State private var isAnimated: Bool = false

    var body: some View {
        VStack {
            Color.red
                .frame(width: 40, height: 40)
                .scaleEffect(isAnimated ? Vector2(1.3, 1.3) : Vector2.one)
                .animation(.linear(duration: 3), value: isAnimated)
                .border(.red)

            Button {
                isAnimated.toggle()
            } label: {
                Text("Animate")
            }
            .buttonStyle(CustomButtonStyle())
        }
        .accessibilityIdentifier("kek")
    }
}

class EditorWindow: UIWindow {

    weak var inspectableView: LayoutInspectableView?

    override func windowDidReady() {
        self.backgroundColor = .gray

        let inspectableView = LayoutInspectableView()
        inspectableView.backgroundColor = .white
        inspectableView.autoresizingRules = [.flexibleWidth, .flexibleHeight]
        self.addSubview(inspectableView)
        self.inspectableView = inspectableView

        let view = UIContainerView(rootView: ContentView())
        view.autoresizingRules = [.flexibleWidth, .flexibleHeight]
        inspectableView.addSubview(view)

        // FIXME: SceneView doesnt render when UI does
        //        let scene = TilemapScene()
        //        let sceneView = SceneView(scene: scene, frame: Rect(origin: Point(x: 60, y: 60), size: Size(width: 250, height: 250)))
        //        sceneView.backgroundColor = .red
        //        self.addSubview(sceneView)
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        let menu = UIMenu(title: "Debug")
        menu.add(MenuItem(
            title: "Layout Inspector",
            action: UIEventAction { [weak self] in
                self?.inspectableView?.inspectLayout.toggle()
            },
            keyEquivalent: .l,
            keyEquivalentModifierMask: .main
        ))
        menu.add(MenuItem(
            title: "Draw debug borders Inspector",
            action: UIEventAction { [weak self] in
                self?.inspectableView?.drawDebugBorders.toggle()
            },
            keyEquivalent: .d,
            keyEquivalentModifierMask: .main
        ))

        builder.insert(menu)
    }
}

class LayoutInspectableView: UIView {

    var speed: Float = 0.2
    var pitch: Angle = Angle.radians(0)
    var yaw: Angle = Angle.radians(-90)
    let sensitivity: Float = 0.1

    private var cameraTransform = Transform3D.identity
    private var cameraUp: Vector3 = Vector3(0, 1, 0)
    private var cameraFront: Vector3 = Vector3(0, 0, -1)
    private var viewMatrix: Transform3D = .identity

    var lastMousePosition: Point = .zero
    var inspectLayout = false
    var drawDebugBorders = false

    override func hitTest(_ point: Point, with event: InputEvent) -> UIView? {
        if let event = (event as? MouseEvent), inspectLayout {
            if event.button == .scrollWheel && event.modifierKeys.contains(.main) {
                return self
            }
        }

        return super.hitTest(point, with: event)
    }

    override func update(_ deltaTime: TimeInterval) async {
        if !inspectLayout {
            self.viewMatrix = .identity
            self.cameraTransform = .identity
            self.cameraFront = Vector3(0, 0, -1)
            return
        }

        if isViewMatrixDirty {
            self.viewMatrix = Transform3D.lookAt(
                eye: cameraTransform.origin,
                center: cameraTransform.origin + self.cameraFront,
                up: self.cameraUp
            )

            isViewMatrixDirty = false
        }

        self.handleView(deltaTime)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        if viewMatrix != .identity {
            context.concatenate(viewMatrix)
        }
        context._environment.drawDebugOutlines = drawDebugBorders
        super.draw(with: context)
    }

    private var zoom: Float = 1
    private var isViewMatrixDirty = true

    override func onMouseEvent(_ event: MouseEvent) {
        guard event.button == .scrollWheel, event.modifierKeys.contains(.main) else {
            return
        }

        self.cameraTransform.origin += event.scrollDelta.y * sensitivity * speed * cameraFront
        self.isViewMatrixDirty = true
    }

    private func handleView(_ deltaTime: TimeInterval) {

        if Input.isKeyPressed(.w) {
            cameraTransform.origin += speed * cameraFront * deltaTime
            self.isViewMatrixDirty = true
        }

        if Input.isKeyPressed(.a) {
            cameraTransform.origin -= cross(cameraFront, cameraUp).normalized * speed * deltaTime
            self.isViewMatrixDirty = true
        }

        if Input.isKeyPressed(.d) {
            cameraTransform.origin += cross(cameraFront, cameraUp).normalized * speed * deltaTime
            self.isViewMatrixDirty = true
        }

        if Input.isKeyPressed(.s) {
            cameraTransform.origin -= speed * cameraFront * deltaTime
            self.isViewMatrixDirty = true
        }

        guard Input.isMouseButtonPressed(.left) else {
            return
        }

        let position = Input.getMousePosition()
        var xoffset = position.x - self.lastMousePosition.x
        var yoffset = self.lastMousePosition.y - position.y
        self.lastMousePosition = position

        let sensitivity: Float = 0.1
        xoffset *= sensitivity
        yoffset *= sensitivity

        yaw   += xoffset
        pitch += yoffset

        if pitch.radians > 89.0 {
            pitch = 89.0
        } else if(pitch.radians < -89.0) {
           pitch = -89.0
        }

        var direction = Vector3()
        direction.x = Math.cos(yaw.radians) * Math.cos(pitch.radians)
        direction.y = Math.sin(pitch.radians)
        direction.z = Math.sin(yaw.radians) * Math.cos(pitch.radians)

        self.cameraFront = direction.normalized

        self.isViewMatrixDirty = true
    }
}
