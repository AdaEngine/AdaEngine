import AdaRender
import AdaText
import AdaUIDescription
import AdaUtils
import Math

extension UICatalog {
    public static var standard: Self {
        // Built-in identifiers are unique by construction; custom catalogs use the throwing initializer.
        Self(builtinViews: builtinViews, builtinModifiers: builtinModifiers)
    }

    private init(builtinViews: [UINativeViewDescriptor], builtinModifiers: [UINativeModifierDescriptor]) {
        views = Dictionary(uniqueKeysWithValues: builtinViews.map { ($0.signature.id, $0) })
        modifiers = Dictionary(uniqueKeysWithValues: builtinModifiers.map { ($0.signature.id, $0) })
    }

    static func number(_ name: String, _ value: Double? = nil) -> UIParameter {
        UIParameter(name, type: .number, defaultValue: value.map(UIValue.number))
    }
    static func string(_ name: String, _ value: String = "") -> UIParameter {
        UIParameter(name, type: .string, defaultValue: .string(value))
    }
    static func bool(_ name: String, _ value: Bool = false) -> UIParameter {
        UIParameter(name, type: .bool, defaultValue: .bool(value))
    }

    private static var builtinViews: [UINativeViewDescriptor] {
        func view(_ name: String, _ parameters: [UIParameter] = [], content: UIContentShape = .none,
                  actions: [UIActionSignature] = [], _ make: @escaping @MainActor (UIFactoryContext) throws -> AnyView) -> UINativeViewDescriptor {
            .init(signature: .init(id: name, name: name, parameters: parameters, actions: actions, content: content), makeView: make)
        }
        let stack = [number("spacing", 8), string("alignment", "center")]
        return [
            view("Text", [string("text", "Text")]) { AnyView(Text($0.string("text"))) },
            view("Image", [string("path"), bool("resizable", true), bool("template")]) { c in
                guard let resources = c.resources else { throw UIDiagnostic("Image requires a UI resource context.") }
                var image = try resources.image(c.string("path"), relativeTo: c.sourceURL)
                if c.bool("resizable") { image = image.resizable() }
                if c.bool("template") { image = image.renderMode(.template) }
                return AnyView(image)
            },
            view("LinearGradient", [string("startColor", "#ffffffff"), string("endColor", "#000000ff"), bool("horizontal")]) { c in
                AnyView(LinearGradient(colors: [try c.color("startColor"), try c.color("endColor")], startPoint: c.bool("horizontal") ? .leading : .top, endPoint: c.bool("horizontal") ? .trailing : .bottom))
            },
            view("NavigationStack", content: .single) { c in AnyView(NavigationStack { c.content }) },
            view("NavigationLink", [string("value"), string("title", "Open")], content: .children) { c in
                AnyView(NavigationLink(value: c.string("value")) {
                    if c.children.isEmpty { AnyView(Text(c.string("title"))) } else { AnyView(c.content) }
                })
            },
            view("EmptyView") { _ in AnyView(EmptyView()) },
            view("Spacer", [number("minLength", 0)]) { AnyView(Spacer(minLength: $0.float("minLength"))) },
            view("Divider") { _ in AnyView(Divider()) },
            view("HStack", stack, content: .children) { c in AnyView(HStack(alignment: c.verticalAlignment, spacing: c.float("spacing")) { c.content }) },
            view("VStack", stack, content: .children) { c in AnyView(VStack(alignment: c.horizontalAlignment, spacing: c.float("spacing")) { c.content }) },
            view("ZStack", [string("alignment", "center")], content: .children) { c in AnyView(ZStack(anchor: c.anchor) { c.content }) },
            view("Group", content: .children) { AnyView($0.content) },
            view("Grid", [number("columns", 2), number("horizontalSpacing", 8), number("verticalSpacing", 8), string("alignment", "topLeading")], content: .children) { c in
                guard c.number("columns") >= 1, c.number("columns") <= 1024, c.number("columns").rounded() == c.number("columns") else {
                    throw UIDiagnostic("Grid columns must be an integer between 1 and 1024.")
                }
                return AnyView(Grid(columns: Int(c.number("columns")), horizontalSpacing: c.float("horizontalSpacing"), verticalSpacing: c.float("verticalSpacing"), alignment: c.alignment) { c.content })
            },
            view("LazyVStack", stack + [number("estimatedRowHeight", 72)], content: .children) { c in
                AnyView(LazyVStack(c.children, alignment: c.horizontalAlignment, spacing: c.float("spacing"), estimatedRowHeight: Float(c.number("estimatedRowHeight"))) { $0.view })
            },
            view("ScrollView", [string("axis", "vertical")], content: .single) { c in AnyView(ScrollView(c.string("axis") == "horizontal" ? .horizontal : .vertical) { c.content }) },
            view("Button", [string("title", "Button")], content: .children, actions: [.init("action")]) { c in
                if c.children.isEmpty { return AnyView(Button(c.string("title")) { c.perform("action") }) }
                return AnyView(Button(action: { c.perform("action") }) { c.content })
            },
            view("TextField", [string("placeholder"), .init("text", type: .string, defaultValue: .string(""), isBinding: true)]) { c in
                AnyView(TextField(c.string("placeholder"), text: c.textBinding("text")))
            },
            view("TextEditor", [.init("text", type: .string, defaultValue: .string(""), isBinding: true)]) { AnyView(TextEditor(text: $0.textBinding("text"))) },
            view("SearchBar", [string("prompt", "Search"), .init("text", type: .string, defaultValue: .string(""), isBinding: true)]) { AnyView(SearchBar(text: $0.textBinding("text"), prompt: $0.string("prompt"))) },
            view("Rectangle", [string("color", "#ffffffff")]) { AnyView(RectangleShape().fill(try $0.color("color"))) },
            view("RoundedRectangle", [number("cornerRadius", 8), string("color", "#ffffffff")]) { AnyView(RoundedRectangleShape(cornerRadius: Float($0.number("cornerRadius"))).fill(try $0.color("color"))) },
            view("Circle", [string("color", "#ffffffff")]) { AnyView(Circle().fill(try $0.color("color"))) },
            view("Color", [string("color", "#ffffffff")]) { AnyView(try $0.color("color")) },
            // Structural entries are interpreted by UISceneSession, with the same metadata used by the editor.
            view("If", [.init("condition", type: .bool, defaultValue: .bool(true))], content: .children) { AnyView($0.content) },
            view("ForEach", [.init("items", type: .array, defaultValue: .array([])), string("idKey", "id")], content: .single) { AnyView($0.content) },
            view("UI", [string("path")]) { _ in AnyView(EmptyView()) }
        ]
    }
}

extension UIFactoryContext {
    var horizontalAlignment: HorizontalAlignment {
        switch string("alignment") { case "leading": .leading; case "trailing": .trailing; default: .center }
    }
    var verticalAlignment: VerticalAlignment {
        switch string("alignment") { case "top": .top; case "bottom": .bottom; default: .center }
    }
    var alignment: Alignment {
        switch string("alignment") {
        case "leading": .leading; case "trailing": .trailing; case "top": .top; case "bottom": .bottom
        case "topLeading": .topLeading; case "topTrailing": .topTrailing
        case "bottomLeading": .bottomLeading; case "bottomTrailing": .bottomTrailing
        default: .center
        }
    }
    var anchor: AnchorPoint {
        switch string("alignment") {
        case "leading": .leading; case "trailing": .trailing; case "top": .top; case "bottom": .bottom
        case "topLeading": .topLeading; case "topTrailing": .topTrailing
        case "bottomLeading": .bottomLeading; case "bottomTrailing": .bottomTrailing
        default: .center
        }
    }
}
