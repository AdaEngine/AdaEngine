import AdaUtils
import Math

/// Window caption commands are supplied by the hosting window, rather than the active popup.
struct WindowCaptionPresentation: Sendable, Hashable {
    var isVisible = false
    var isResizable = true
    var isMaximized = false
    var target: WindowCaptionCommandTarget?

    @MainActor func action(_ action: WindowCaptionAction) {
        target?.perform(action)
    }
}

/// A stable command identity for an individual host. Keeping the window weak
/// avoids retaining its view tree through the environment.
@MainActor
final class WindowCaptionCommandTarget: Hashable {
    private weak var window: UIWindow?

    init(window: UIWindow) { self.window = window }

    func perform(_ action: WindowCaptionAction) { window?.systemWindow?.performCaptionAction(action) }

    nonisolated static func == (lhs: WindowCaptionCommandTarget, rhs: WindowCaptionCommandTarget) -> Bool { lhs === rhs }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

extension EnvironmentValues {
    @Entry var windowCaption: WindowCaptionPresentation = WindowCaptionPresentation()
}

/// Controls for a client-drawn Windows title bar. The maximize region also participates
/// in native non-client hit testing so Windows can display its Snap Layouts menu.
public struct WindowCaptionControls: View {
    @Environment(\.windowCaption) private var caption
    @Environment(\.foregroundColor) private var foreground
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if caption.isVisible {
            HStack(spacing: 0) {
                captionButton(action: .minimize, identifier: "Minimize")
                if caption.isResizable {
                    captionButton(action: .toggleMaximize, identifier: "Maximize")
                }
                captionButton(action: .close, identifier: "Close")
            }
        }
    }

    private func captionButton(action: WindowCaptionAction, identifier: String) -> some View {
        Button { caption.action(action) } label: {
            Canvas { context, _ in
                var path = Path()
                switch action {
                case .minimize:
                    path.move(to: Point(x: 18, y: 16))
                    path.addLine(to: Point(x: 28, y: 16))
                case .toggleMaximize:
                    if caption.isMaximized {
                        path.addRect(Rect(x: 20, y: 11, width: 8, height: 8))
                        path.addRect(Rect(x: 18, y: 13, width: 8, height: 8))
                    } else {
                        path.addRect(Rect(x: 18, y: 11, width: 10, height: 10))
                    }
                case .close:
                    path.move(to: Point(x: 18, y: 11))
                    path.addLine(to: Point(x: 28, y: 21))
                    path.move(to: Point(x: 28, y: 11))
                    path.addLine(to: Point(x: 18, y: 21))
                }
                context.stroke(path, with: foreground ?? (colorScheme == .dark ? .white : .black), style: .init(lineWidth: 1))
            }.frame(width: 46, height: 32)
        }
        .buttonStyle(WindowCaptionButtonStyle(isClose: identifier == "Close"))
        .accessibilityIdentifier("AdaUI.Caption." + identifier)
    }
}

private struct WindowCaptionButtonStyle: ButtonStyle {
    let isClose: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isHovered || configuration.isPressed ? (isClose ? Color.red : Color.gray.opacity(0.25)) : .clear)
            .onHover { isHovered = $0 }
    }
}
