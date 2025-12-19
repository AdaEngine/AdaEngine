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
            .font(Font.system(size: 13))
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
    private var zoom: Float = 1
    private var isViewMatrixDirty = true

    override func hitTest(_ point: Point, with event: any InputEvent) -> UIView? {
        if let event = (event as? MouseEvent), inspectLayout {
            if event.button == .scrollWheel && event.modifierKeys.contains(.main) {
                return self
            }
        }

        return super.hitTest(point, with: event)
    }

    override func update(_ deltaTime: TimeInterval) {
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
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        if viewMatrix != .identity {
            context.concatenate(viewMatrix)
        }
        context._environment.drawDebugOutlines = drawDebugBorders
        super.draw(with: context)
    }

    override func onMouseEvent(_ event: MouseEvent) {
        guard event.button == .scrollWheel, event.modifierKeys.contains(.main) else {
            return
        }

        self.cameraTransform.origin += event.scrollDelta.y * sensitivity * speed * cameraFront
        self.isViewMatrixDirty = true

        guard event.button == .left && event.phase != .began else {
            return
        }

        let position = event.mousePosition
        var xoffset = position.x - self.lastMousePosition.x
        var yoffset = self.lastMousePosition.y - position.y
        self.lastMousePosition = position

        let sensitivity: Float = 0.1
        xoffset *= sensitivity
        yoffset *= sensitivity

        yaw += xoffset
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

    override func onKeyPressed(_ event: Set<KeyEvent>) {
        for key in event where key.status == .down {
            switch key.keyCode {
            case .w:
                cameraTransform.origin += speed * cameraFront
                self.isViewMatrixDirty = true
            case .a:
                cameraTransform.origin -= cross(cameraFront, cameraUp).normalized * speed
                self.isViewMatrixDirty = true
            case .d:
                cameraTransform.origin += cross(cameraFront, cameraUp).normalized * speed
                self.isViewMatrixDirty = true
            case .s:
                cameraTransform.origin -= speed * cameraFront
                self.isViewMatrixDirty = true
            default:
                return
            }
        }
    }
}
