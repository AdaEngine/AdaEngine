import AdaUI
import AdaUtils
import Gravity

@GSExportable("__AdaUIView")
final class AdaScriptViewBridge: @unchecked Sendable {
    @GSExportableIgnore
    let model: AdaScriptViewModel

    init() {
        self.model = AdaScriptViewModel(content: .empty)
    }

    @GSExportableIgnore
    private init(model: AdaScriptViewModel) {
        self.model = model
    }

    func accessibilityIdentifier(_ value: String) -> AdaScriptViewBridge {
        replacingStyle { $0.accessibilityIdentifier = value }
    }

    func background(_ value: String) -> AdaScriptViewBridge {
        replacingStyle { $0.background = value }
    }

    func button(_ title: String, _ action: String) -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: AdaScriptViewModel(content: .button(title: title, action: action)))
    }

    func child(_ value: AdaScriptViewBridge) -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: model.addingChild(value.model))
    }

    func divider() -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: AdaScriptViewModel(content: .divider))
    }

    func empty() -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: AdaScriptViewModel(content: .empty))
    }

    func fontSize(_ value: Double) -> AdaScriptViewBridge {
        replacingStyle { $0.fontSize = value.finiteNonnegativeFloat }
    }

    func foregroundColor(_ value: String) -> AdaScriptViewBridge {
        replacingStyle { $0.foregroundColor = value }
    }

    func frame(_ width: Double, _ height: Double) -> AdaScriptViewBridge {
        replacingStyle {
            $0.width = width.finiteNonnegativeFloat
            $0.height = height.finiteNonnegativeFloat
        }
    }

    func hStack() -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: AdaScriptViewModel(content: .hStack(children: [], spacing: nil)))
    }

    func opacity(_ value: Double) -> AdaScriptViewBridge {
        replacingStyle { $0.opacity = min(max(value.finiteFloat ?? 1, 0), 1) }
    }

    func padding(_ value: Double) -> AdaScriptViewBridge {
        replacingStyle { $0.padding = value.finiteNonnegativeFloat }
    }

    func spacer() -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: AdaScriptViewModel(content: .spacer(minLength: nil)))
    }

    func spacerMinLength(_ value: Double) -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: model.replacingSpacerMinLength(value.finiteNonnegativeFloat))
    }

    func spacing(_ value: Double) -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: model.replacingSpacing(value.finiteNonnegativeFloat))
    }

    func text(_ value: String) -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: AdaScriptViewModel(content: .text(value)))
    }

    func vStack() -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: AdaScriptViewModel(content: .vStack(children: [], spacing: nil)))
    }

    func zStack() -> AdaScriptViewBridge {
        AdaScriptViewBridge(model: AdaScriptViewModel(content: .zStack(children: [])))
    }

    private func replacingStyle(_ update: (inout AdaScriptViewStyle) -> Void) -> AdaScriptViewBridge {
        var style = model.style
        update(&style)
        return AdaScriptViewBridge(model: AdaScriptViewModel(content: model.content, style: style))
    }
}

struct AdaScriptViewModel: Sendable {
    indirect enum Content: Sendable {
        case button(title: String, action: String)
        case divider
        case empty
        case hStack(children: [AdaScriptViewModel], spacing: Float?)
        case spacer(minLength: Float?)
        case text(String)
        case vStack(children: [AdaScriptViewModel], spacing: Float?)
        case zStack(children: [AdaScriptViewModel])
    }

    let content: Content
    let style: AdaScriptViewStyle

    init(content: Content, style: AdaScriptViewStyle = AdaScriptViewStyle()) {
        self.content = content
        self.style = style
    }

    func addingChild(_ child: Self) -> Self {
        switch content {
        case let .hStack(children, spacing):
            Self(content: .hStack(children: children + [child], spacing: spacing), style: style)
        case let .vStack(children, spacing):
            Self(content: .vStack(children: children + [child], spacing: spacing), style: style)
        case .zStack(let children):
            Self(content: .zStack(children: children + [child]), style: style)
        default:
            self
        }
    }

    func replacingSpacerMinLength(_ minLength: Float?) -> Self {
        guard case .spacer = content else {
            return self
        }
        return Self(content: .spacer(minLength: minLength), style: style)
    }

    func replacingSpacing(_ spacing: Float?) -> Self {
        switch content {
        case .hStack(let children, _):
            Self(content: .hStack(children: children, spacing: spacing), style: style)
        case .vStack(let children, _):
            Self(content: .vStack(children: children, spacing: spacing), style: style)
        default:
            self
        }
    }
}

struct AdaScriptViewStyle: Sendable {
    var accessibilityIdentifier: String?
    var background: String?
    var fontSize: Float?
    var foregroundColor: String?
    var height: Float?
    var opacity: Float?
    var padding: Float?
    var width: Float?
}

@MainActor
struct AdaScriptRenderedView: View {
    let model: AdaScriptViewModel
    let performAction: @MainActor (String) -> Void

    var body: some View {
        var view = unstyledView
        if let fontSize = model.style.fontSize {
            view = AnyView(view.fontSize(Double(fontSize)))
        }
        if let color = model.style.foregroundColor.flatMap(AdaScriptColor.init) {
            view = AnyView(view.foregroundColor(color.value))
        }
        if let padding = model.style.padding {
            view = AnyView(view.padding(padding))
        }
        if model.style.width != nil || model.style.height != nil {
            view = AnyView(view.frame(width: model.style.width, height: model.style.height))
        }
        if let color = model.style.background.flatMap(AdaScriptColor.init) {
            view = AnyView(view.background(color.value))
        }
        if let opacity = model.style.opacity {
            view = AnyView(view.opacity(opacity))
        }
        if let identifier = model.style.accessibilityIdentifier {
            view = AnyView(view.accessibilityIdentifier(identifier))
        }
        return view
    }

    private var unstyledView: AnyView {
        switch model.content {
        case let .button(title, action):
            AnyView(Button(title) { performAction(action) })
        case .divider:
            AnyView(Divider())
        case .empty:
            AnyView(EmptyView())
        case let .hStack(children, spacing):
            AnyView(HStack(spacing: spacing) { AdaScriptViewList(children: children, performAction: performAction) })
        case .spacer(let minLength):
            AnyView(Spacer(minLength: minLength))
        case .text(let value):
            AnyView(Text(verbatim: value))
        case let .vStack(children, spacing):
            AnyView(VStack(spacing: spacing) { AdaScriptViewList(children: children, performAction: performAction) })
        case .zStack(let children):
            AnyView(ZStack { AdaScriptViewList(children: children, performAction: performAction) })
        }
    }
}

@MainActor
private struct AdaScriptViewList: View {
    let children: [AdaScriptViewModel]
    let performAction: @MainActor (String) -> Void

    var body: some View {
        ForEach(children.indices) { index in
            AdaScriptRenderedView(model: children[index], performAction: performAction)
        }
    }
}

private struct AdaScriptColor {
    let value: Color

    init?(_ source: String) {
        if let named = Self.named[source.lowercased()] {
            self.value = named
            return
        }
        guard let value = Self.hex(source) else {
            return nil
        }
        self.value = value
    }

    private static let named: [String: Color] = [
        "black": .black, "blue": .blue, "brown": .brown, "clear": .clear,
        "gray": .gray, "green": .green, "grey": .gray, "mint": .mint,
        "orange": .orange, "pink": .pink, "purple": .purple, "red": .red,
        "white": .white, "yellow": .yellow
    ]

    private static func hex(_ source: String) -> Color? {
        guard source.hasPrefix("#") else {
            return nil
        }
        let digits = source.dropFirst()
        guard let hex = Int(digits, radix: 16) else {
            return nil
        }
        if digits.count == 6 {
            return .fromHex(hex)
        }
        guard digits.count == 8 else {
            return nil
        }
        return Color(
            red: Float((hex >> 24) & 0xFF) / 255,
            green: Float((hex >> 16) & 0xFF) / 255,
            blue: Float((hex >> 8) & 0xFF) / 255,
            alpha: Float(hex & 0xFF) / 255
        )
    }
}

private extension Double {
    var finiteFloat: Float? {
        let converted = Float(self)
        return converted.isFinite ? converted : nil
    }

    var finiteNonnegativeFloat: Float? {
        finiteFloat.map { max($0, 0) }
    }
}
