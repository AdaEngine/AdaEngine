import AdaEngine
import AdaStudioCore
import Foundation

@main @MainActor
struct AdaEditorWeb: App {
    var body: some AppScene {
        WindowGroup { StudioRootView() }
            .windowTitle("Ada Studio")
            .windowMode(.windowed)
    }
}

@MainActor struct StudioRootView: View {
    @State private var model = StudioViewModel(browser: StudioBrowser())
    private let background = Color.fromHex(0x0d131b)
    private let panel = Color.fromHex(0x151e29)
    private let muted = Color.fromHex(0x98a6ba)
    private let blue = Color.fromHex(0x2585ff)

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header.frame(height: 80).background(Color.fromHex(0x171f2a))
                HStack(spacing: 0) {
                    navigation.frame(width: 72).background(panel)
                    if model.accountID == nil {
                        VStack(spacing: 24) {
                            Text("Ваша игровая студия в браузере").font(.system(size: 32, weight: .bold))
                            Text("Войдите в Ada Cloud, чтобы создавать и сохранять игры.").foregroundColor(muted)
                            action("Войти в Ada Cloud", accent: true, model.signIn)
                            Text(model.status).font(.system(size: 12)).foregroundColor(muted)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if model.document != nil {
                        chat.frame(width: 360)
                        workbench
                    } else {
                        home
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let error = model.error {
                    HStack {
                        Text(error).font(.system(size: 12)).foregroundColor(Color.fromHex(0xffbf80))
                        Spacer()
                        action("Закрыть") { model.error = nil }
                    }.padding(.horizontal, 18).frame(height: 36).background(panel)
                }
            }
            .foregroundColor(.white)
            .textFieldStyle(PlainTextFieldStyle())
            .textEditorColors(TextEditorColors(background: panel, border: Color.fromHex(0x2a384c), focusedBorder: blue,
                gutter: muted, gutterRule: Color.fromHex(0x2a384c), currentLineBackground: blue.opacity(0.08), selection: blue.opacity(0.3)))
            .background(background)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear { layoutPreview(geometry.size) }
            .onChange(of: geometry.size) { _, size in layoutPreview(size) }
            .onChange(of: previewLayoutKey) { _, _ in layoutPreview(geometry.size) }
        }
        .task { await model.start() }
        .accessibilityIdentifier("AdaStudio.Web")
    }

    private var previewLayoutKey: String { "\(model.tab.rawValue):\(model.isRunning):\(model.showsHistory):\(model.showsSettings):\(model.error != nil):\(model.document != nil)" }
    private func layoutPreview(_ size: Size) {
        model.browser.previewBounds(x: 448, y: 156, width: size.width - 464 - (model.tab == .scene ? 280 : 0),
            height: size.height - 242 - (model.error == nil ? 0 : 36),
            visible: model.isRunning && model.tab != .code && !model.showsHistory && !model.showsSettings && model.document != nil)
    }

    private var header: some View {
        HStack(spacing: 22) {
            Text("Λ").font(.system(size: 34, weight: .bold)).foregroundColor(.white)
            Text("Ada Studio").font(.system(size: 24, weight: .semibold))
            Text(model.document?.snapshot.title ?? "Создаём игру").font(.system(size: 16, weight: .semibold))
            if model.document != nil { Text(model.status).font(.system(size: 13)).foregroundColor(model.status == "Сохранено" ? Color.fromHex(0x36d58a) : muted) }
            Spacer()
            if model.document != nil {
                action("История") { Task { await model.history() } }
                action("Скачать", model.download)
                if model.publishingEnabled { action("Опубликовать  PRO", accent: true) { Task { await model.publish() } } }
            }
            if model.accountID == nil { action("Войти", accent: true, model.signIn) }
            else { Text(String(model.accountName.prefix(1))).font(.system(size: 17, weight: .bold)).padding(12).background(panel) }
        }
        .padding(.horizontal, 24)
        .background(Color.fromHex(0x171f2a))
    }

    private var navigation: some View {
        VStack(spacing: 20) {
            navigationAction(.home, model.home)
            navigationAction(.chat) { model.tab = .game }
            navigationAction(.scene) { model.tab = .scene; Task { await model.play() } }
            navigationAction(.play) { model.tab = .game; Task { await model.play() } }
            Spacer()
            navigationAction(.settings) { model.showsSettings.toggle(); model.showsHistory = false }
        }.padding(.vertical, 22).frame(maxHeight: .infinity).background(panel)
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("Какую игру создадим?").font(.system(size: 36, weight: .bold))
            Text("Опишите идею. Создавайте, пробуйте и улучшайте её вместе с агентом.").foregroundColor(muted)
            composer.frame(height: 130)
            HStack(spacing: 14) {
                action("+  2D-игра", accent: true) { Task { await model.create(.game2D) } }
                action("+  3D-игра") { Task { await model.create(.game3D) } }
                action("Загрузить проект") { Task { await model.importProject() } }
            }
            Text("Мои проекты").font(.system(size: 20, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.projects, id: \.id) { project in
                        HStack {
                            action(project.title) { Task { await model.open(project) } }
                            action("Удалить") { Task { await model.deleteProject(project) } }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 220)
            Spacer()
        }.padding(48).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var chat: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Создаём игру").font(.system(size: 24, weight: .semibold)).padding(.top, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(model.visibleMessages, id: \.id) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message.role == "user" ? "Вы" : "Λ  Ada").font(.system(size: 12, weight: .semibold)).foregroundColor(muted)
                            Text(message.content).font(.system(size: 14))
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(message.role == "user" ? Color.fromHex(0x22334e) : panel)
                    }
                    if model.isAgentRunning { Text(model.agentText.isEmpty ? "Агент работает…" : model.agentText).font(.system(size: 14)).padding(16).background(panel) }
                }
            }.frame(maxHeight: .infinity)
            if let selection = model.document?.selection { Text("В контексте: " + (model.selectedEntity?["name"].string ?? selection)).font(.system(size: 11)).foregroundColor(muted) }
            if !model.attachmentPaths.isEmpty { Text("Ассеты: \(model.attachmentPaths.count)").font(.system(size: 11)).foregroundColor(muted) }
            composer.frame(height: 120)
        }.padding(.horizontal, 18).padding(.bottom, 20).frame(maxHeight: .infinity).background(Color.fromHex(0x101821))
    }

    private var composer: some View {
        VStack(spacing: 8) {
            TextEditor("Что изменим в игре?", text: Binding(get: { model.prompt }, set: { model.prompt = $0 }), showsLineNumbers: false, wrapsLines: true)
                .font(.system(size: 14)).frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                action("+") { Task { await model.attachAsset() } }
                action(model.billingMode == "ada" ? "Ada AI" : "Свой ключ") { model.showsSettings.toggle() }
                Spacer()
                if model.isAgentRunning { action("Стоп", model.stopAgent) }
                else { action("Отправить", accent: true, model.sendPrompt) }
            }
        }.padding(10).background(panel)
    }

    private var workbench: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if let publication = model.publicationStatus { Text(publication).font(.system(size: 12)).foregroundColor(muted) }
                ForEach(StudioTab.allCases, id: \.rawValue) { tab in
                    action(tab.rawValue, accent: model.tab == tab) {
                        model.tab = tab; model.showsSettings = false; model.showsHistory = false
                        if tab != .code { Task { await model.play() } }
                    }
                }
                Spacer()
                action(model.isRunning ? "Перезапустить" : "Запустить") { Task { await model.play() } }
                if model.isRunning { action("Стоп", model.stop) }
            }.padding(.horizontal, 16).frame(height: 64)
            if model.showsSettings { settings }
            else if model.showsHistory { history }
            else if model.tab == .code { code }
            else {
                HStack(spacing: 16) {
                    VStack(spacing: 14) {
                        Spacer()
                        if !model.isRunning {
                            Text("Ваша игра появится здесь").font(.system(size: 23, weight: .semibold))
                            Text("Нажмите «Запустить», чтобы попробовать текущую версию.").foregroundColor(muted)
                            action("Запустить", accent: true) { Task { await model.play() } }
                        }
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).background(panel)
                    if model.tab == .scene { inspector.frame(width: 264) }
                }.padding(.horizontal, 16).padding(.top, 12).frame(maxHeight: .infinity)
                HStack(spacing: 16) {
                    action("Добавить цель") { model.prompt = "Добавь понятную цель игры и условие победы"; model.sendPrompt() }
                    action("Улучшить окружение") { model.prompt = "Улучши окружение, сохрани управление и правила игры"; model.sendPrompt() }
                    action("Отменить", model.undo)
                    action("Повторить", model.redo)
                }.frame(height: 86)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var code: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(model.document?.snapshot.sources ?? [], id: \.path) { file in action(file.path) { model.activeFile = file.path } }
                Spacer()
                action("Проверить") { let result = model.validateSources(); model.error = result.isEmpty ? "Ошибок не найдено." : result }
            }
            TextEditor(text: Binding(get: { model.document?.snapshot.file(model.activeFile)?.text ?? "" }, set: model.writeCode),
                sourceInteraction: TextEditorSourceInteraction(onSelectionChange: { _, text in model.codeSelection = text }),
                foldingStyle: .braces, showsIndentationGuides: true)
                .font(.system(size: 14)).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Сцена").font(.system(size: 16, weight: .semibold))
                ForEach(model.scene?.entities ?? [], id: \.text) { entity in
                    action(entity["name"].string ?? "Object", accent: model.document?.selection == entity["id"].string) { model.document?.select(entity["id"].string) }
                }
                action("+ Объект", model.addEntity)
                if let entity = model.selectedEntity {
                    Text("Инспектор").font(.system(size: 16, weight: .semibold)).padding(.top, 12)
                    action("Удалить объект", model.removeSelectedEntity)
                    ForEach(entity["components"].object.keys.sorted(), id: \.self) { component in
                        Text(component.components(separatedBy: ".").last ?? component).font(.system(size: 13, weight: .semibold)).foregroundColor(muted)
                        ForEach(entity["components"][component].object.keys.sorted(), id: \.self) { field in
                            Text(field).font(.system(size: 11)).foregroundColor(muted)
                            TextField(field, text: Binding(get: { model.selectedEntity?["components"][component][field].text ?? "" },
                                set: { model.setSceneField(component: component, field: field, text: $0) })).font(.system(size: 12))
                        }
                    }
                }
                Text("Ассеты").font(.system(size: 16, weight: .semibold)).padding(.top, 12)
                action("Загрузить ассет") { Task { await model.attachAsset() } }
                ForEach(model.document?.snapshot.files.filter { $0.path.hasPrefix("Assets/") } ?? [], id: \.path) { file in
                    Text(file.path).font(.system(size: 11)).foregroundColor(muted)
                }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxHeight: .infinity).background(panel)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Подключение агента").font(.system(size: 24, weight: .semibold))
            HStack {
                action("Ada AI", accent: model.billingMode == "ada") { model.billingMode = "ada" }
                action("Свой API-ключ", accent: model.billingMode == "byok") { model.billingMode = "byok" }
            }
            ForEach(model.providers, id: \.text) { provider in
                action(provider["title"].string ?? provider["id"].text, accent: provider["id"].string == model.providerID) {
                    model.providerID = provider["id"].string ?? ""; model.modelID = model.models.first?["id"].string ?? ""
                }
            }
            ForEach(model.models, id: \.text) { modelInfo in
                action(modelInfo["title"].string ?? modelInfo["id"].text, accent: modelInfo["id"].string == model.modelID) { model.modelID = modelInfo["id"].string ?? "" }
            }
            if model.billingMode == "byok" {
                TextField("API-ключ", text: Binding(get: { model.apiKey }, set: { model.apiKey = $0 }))
                Text("Ключ используется Cloud-прокси для запросов к выбранному провайдеру. Он хранится только в памяти этой вкладки и не входит в проект.").foregroundColor(muted)
            } else { Text(model.publishingEnabled ? "Используются AI-кредиты Ada. Cloud Pro оплачивает публикацию отдельно." : "Используется выбранный сервис агента.").foregroundColor(muted) }
            action("Готово", accent: true) { model.showsSettings = false }
            Spacer()
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("История проекта").font(.system(size: 24, weight: .semibold))
            action("Сохранить контрольную версию", accent: true) { Task { await model.save(checkpoint: true); await model.history() } }
            ForEach(model.checkpoints, id: \.id) { checkpoint in
                action("Версия \(checkpoint.revision) — восстановить") { Task { await model.restore(checkpoint) } }
            }
            if !model.releases.isEmpty {
                Text("Публикации").font(.system(size: 18, weight: .semibold))
                ForEach(model.releases, id: \.text) { release in
                    HStack {
                        Text("Версия " + release["number"].text + " · " + release["status"].text).font(.system(size: 13))
                        if release["status"].string == "approved" { action("Активировать") { Task { await model.activateRelease(release) } } }
                    }
                }
            }
            action("Закрыть") { model.showsHistory = false }
            Spacer()
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func action(_ title: String, accent: Bool = false, _ callback: @escaping () -> Void) -> some View {
        Button(action: callback) { Text(title).font(.system(size: 13, weight: .regular)).padding(.horizontal, 12).padding(.vertical, 10)
            .foregroundColor(.white).background(RoundedRectangleShape(cornerRadius: 7).fill(accent ? blue : panel)) }
            .buttonStyle(DefaultButtonStyle())
    }
    private func navigationAction(_ icon: StudioIcon, _ callback: @escaping () -> Void) -> some View {
        Button(action: callback) { StudioIconShape(icon: icon).stroke(muted, lineWidth: 1.8).frame(width: 22, height: 22).padding(12) }
            .buttonStyle(DefaultButtonStyle())
    }
}

private enum StudioIcon { case home, chat, scene, play, settings }
private struct StudioIconShape: Shape {
    typealias AnimatableData = EmptyAnimatableData
    let icon: StudioIcon
    func path(in rect: Rect) -> Path {
        var path = Path()
        func line(_ points: [(Float, Float)], close: Bool = false) {
            for (index, point) in points.enumerated() {
                let value = Point(rect.minX + point.0 * rect.width, rect.minY + point.1 * rect.height)
                if index == 0 { path.move(to: value) } else { path.addLine(to: value) }
            }
            if close { path.closeSubpath() }
        }
        switch icon {
        case .home:
            line([(0.05,0.45),(0.5,0.08),(0.95,0.45)])
            line([(0.18,0.36),(0.18,0.92),(0.42,0.92),(0.42,0.63),(0.64,0.63),(0.64,0.92),(0.82,0.92),(0.82,0.36)])
        case .chat:
            line([(0.08,0.12),(0.92,0.12),(0.92,0.75),(0.35,0.75),(0.08,0.96)], close: true)
            line([(0.25,0.33),(0.75,0.33)]); line([(0.25,0.52),(0.6,0.52)])
        case .scene:
            line([(0.5,0.04),(0.94,0.27),(0.94,0.76),(0.5,0.98),(0.06,0.76),(0.06,0.27)], close: true)
            line([(0.06,0.27),(0.5,0.5),(0.94,0.27)]); line([(0.5,0.5),(0.5,0.98)])
        case .play: line([(0.22,0.08),(0.88,0.5),(0.22,0.92)], close: true)
        case .settings:
            for y: Float in [0.2,0.5,0.8] { line([(0.05,y),(0.95,y)]) }
            line([(0.3,0.08),(0.3,0.32)]); line([(0.7,0.38),(0.7,0.62)]); line([(0.4,0.68),(0.4,0.92)])
        }
        return path
    }
}
