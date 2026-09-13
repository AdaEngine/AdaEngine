import AdaEngine
import Foundation

@main
struct TextureMenuExample: App {
    var body: some AppScene {
        WindowGroup { TextureMenuLoader() }
            .windowMode(.windowed)
    }
}

private struct TextureMenuLoader: View {
    @State private var content = AnyView(Text("Loading menu…"))

    private func load() {
        do {
            guard let root = Bundle.module.resourceURL else { throw CocoaError(.fileNoSuchFile) }
            let assets = root.appendingPathComponent("KenneyUI")
            let resources = UISceneResources(rootURL: assets)
            let source = assets.appendingPathComponent("Menu.ui")
            let context = UIBindingContext()
            for index in 0..<4 {
                context.on("action\(index)") { _ in print("UI menu action \(index)") }
            }
            let session = try UISceneInstance(document: resources.load(source), context: context, resources: resources, sourceURL: source)
            let style = try TextureButtonStyle(
                normal: resources.image("normal.png"), highlighted: resources.image("highlighted.png"),
                pressed: resources.image("pressed.png"), disabled: resources.image("disabled.png"), capInsets: .init(8)
            )
            let panel = try resources.image("panel.png")
            content = AnyView(HStack(spacing: 40) {
                VStack(spacing: 12) {
                    Text("Swift")
                    TextureCodeMenu(style: style, panel: panel).frame(width: 288, height: 340)
                }
                VStack(spacing: 12) {
                    Text("UI Designer (.ui)")
                    UISceneView(session: session).frame(width: 288, height: 340)
                }
            }
            .padding(32)
            .foregroundColor(.white)
            .background(Color(0.08, 0.14, 0.22, 1)))
        } catch {
            content = AnyView(Text("Unable to load menu: \(error.localizedDescription)").foregroundColor(.white).frame(width: 700, height: 300))
        }
    }

    var body: some View { content.task { await load() } }
}

private struct TextureCodeMenu: View {
    let style: TextureButtonStyle
    let panel: Image

    var body: some View {
        VStack(spacing: 16) {
            Text("GUI Demo").fontSize(28).foregroundColor(Color(0.12, 0.17, 0.24, 1))
            menuButton("Continue")
            menuButton("New Game")
            menuButton("Settings")
            menuButton("Quit").disabled(true)
        }
        .padding(24)
        .background { panel.resizable(capInsets: .init(8)) }
    }

    private func menuButton(_ title: String) -> some View {
        Button(action: { print("Swift menu: \(title)") }) {
            Text(title).frame(width: 240, height: 48)
        }
        .buttonStyle(style)
    }
}
