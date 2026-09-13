import AdaEngine

@Previewable(title: "Star Quest · Kenney UI")
public struct StarQuestView: View {
    @State private var model: StarQuestModel?
    @State private var error: String?
    public init() {}

    public var body: some View {
        Group {
            if let model {
                QuestShell(model: model)
            } else {
                Text(error ?? "Loading Star Quest…")
            }
        }
        .foregroundColor(.white)
        .task { @MainActor in
            guard model == nil else { return }
            do { model = try StarQuestModel() }
            catch { self.error = error.localizedDescription }
        }
        .drawingGroup(cachesContents: false)
    }
}

private struct QuestShell: View {
    let model: StarQuestModel
    var body: some View {
        VStack(spacing: 20) {
            QuestHeader(model: model)
            Spacer()
            QuestStage(model: model)
            Spacer()
            Text("Kenney UI Pack · 9-slice · One game, two UI implementations").fontSize(13)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { QuestBackdrop(model: model) }
    }
}

private struct QuestHeader: View {
    let model: StarQuestModel
    var body: some View {
        HStack(spacing: 16) {
            Text("STAR QUEST / ADAUI").fontSize(14)
            Spacer()
            Button(model.usesDesigner ? "UI: .ui / Switch" : "UI: Swift / Switch") { model.usesDesigner.toggle() }
                .padding(10).background(Color(0.18, 0.30, 0.42, 1))
        }
    }
}

private struct QuestBackdrop: View {
    let model: StarQuestModel
    var body: some View {
        model.alternateBackdrop ? Color(0.07, 0.20, 0.18, 1) : Color(0.06, 0.12, 0.20, 1)
    }
}

private struct QuestStage: View {
    let model: StarQuestModel
    var body: some View {
        ZStack {
            QuestDocument(model: model).opacity(model.usesDesigner ? 1 : 0).allowsHitTesting(model.usesDesigner)
            NativeQuestScreen(model: model).opacity(model.usesDesigner ? 0 : 1).allowsHitTesting(!model.usesDesigner)
        }.frame(width: model.widePanel ? 500 : 380, height: 570)
    }
}

private struct QuestDocument: View {
    let model: StarQuestModel
    var body: some View {
        if let error = model.error { Text(error).foregroundColor(.red) }
        if let session = model.session { UISceneView(session: session) }
    }
}

private struct NativeQuestScreen: View {
    let model: StarQuestModel
    var body: some View {
        VStack(spacing: 16) {
            switch model.screen {
            case .menu:
                heading("STAR QUEST", "A tiny adventure in textured UI")
                button("Continue", "continue", disabled: !model.hasAdventure)
                button("New adventure", "new")
                button("Settings", "settings")
                button("Credits", "credits")
                detail("Best expedition: \(model.best) / 5 stars")
            case .play:
                heading("STAR HUNT", "Find all five to complete the expedition")
                ForEach(0..<5, id: \.self) { index in
                    button("Collect star \(index + 1)", "collect\(index)", disabled: model.collected.contains(index))
                }.id(model.collected.count)
                detail("Stars collected: \(model.collected.count) / 5")
                button("Pause", "pause")
            case .pause:
                heading("TAKE A BREATH", "Your expedition is waiting")
                button("Resume", "continue")
                button("Restart", "new")
                button("Main menu", "home")
            case .result:
                heading("ALL STARS FOUND", "Five stars. One great adventure.")
                if let star = try? model.image("star") { star.resizable().frame(width: 80, height: 80) }
                detail("Stars collected: \(model.collected.count) / 5")
                button("Play again", "new")
                button("Main menu", "home")
            case .settings:
                heading("MAKE IT YOURS", "Settings apply to both UI implementations")
                detail(model.alternateBackdrop ? "Backdrop: forest" : "Backdrop: midnight")
                button("Change backdrop", "theme")
                detail(model.widePanel ? "Panel: wide" : "Panel: compact")
                button("Change panel width", "size")
                button("Back", "home")
            case .credits:
                heading("MADE WITH ADAUI", "Kenney UI Pack · CC0")
                detail("Swift views + editable .ui scenes")
                detail("Nine-slice panels · button states")
                button("Back", "home")
            }
        }
        .padding(28)
        .background {
            if let panel = try? model.image("panel") { panel.resizable(capInsets: .init(8)) }
        }
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        Group { detail(title, size: 32); detail(subtitle, size: 16) }
    }
    private func detail(_ text: String, size: Double = 18) -> some View {
        Text(text).fontSize(size).foregroundColor(Color(0.125, 0.196, 0.278, 1))
    }
    private func button(_ title: String, _ action: String, disabled: Bool = false) -> some View {
        Group {
            if let normal = try? model.image("normal") {
                Button(action: { model.perform(action) }) {
                    HStack(spacing: 12) {
                        if action.hasPrefix("collect"), let star = try? model.image("star") {
                            star.resizable().frame(width: 28, height: 28)
                        }
                        Text(title)
                    }.frame(width: 300, height: 48)
                }
                    .buttonStyle(TextureButtonStyle(normal: normal, highlighted: try? model.image("highlighted"), pressed: try? model.image("pressed"), disabled: try? model.image("disabled"), capInsets: .init(8), selectionEffect: true))
                    .disabled(disabled)
            }
        }
    }
}
