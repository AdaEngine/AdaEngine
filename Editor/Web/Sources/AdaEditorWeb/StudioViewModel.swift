import AdaScriptCompilerCore
import AdaStudioCore
import Foundation
import Observation

enum StudioTab: String, CaseIterable { case game = "Игра", scene = "Сцена", code = "Код" }

@MainActor @Observable final class StudioViewModel {
    var accountID: String?
    var accountName = ""
    var projects: [StudioWorkspace] = []
    var workspace: StudioWorkspace?
    var document: StudioDocument?
    var tab = StudioTab.game
    var prompt = ""
    var activeFile = "Sources/Game.ada"
    var selectedCode = ""
    var status = "Загрузка…"
    var error: String?
    var providers: [StudioValue] = []
    var providerID = ""
    var modelID = ""
    var billingMode = "ada"
    var apiKey = "" // Deliberately outside every Codable project/recovery model.
    var isRunning = false
    var agentText = ""
    var isAgentRunning = false
    var isLoading = false
    var showsHistory = false
    var showsSettings = false
    var checkpoints: [StudioCheckpoint] = []
    var releases: [StudioValue] = []
    var publicationStatus: String?
    var publishingEnabled = false
    var attachmentPaths: [String] = []
    var codeSelection: String?
    let browser: StudioBrowser
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored var agentTask: Task<Void, Never>?
    @ObservationIgnored private var savedGeneration = -1
    @ObservationIgnored private var saveInFlight = false
    @ObservationIgnored private var saveWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var checkpointPending = false
    @ObservationIgnored private var recoveryTask: Task<Void, Never>?
    @ObservationIgnored private var previewRequest = UUID()
    @ObservationIgnored private var scenePreviewTask: Task<Void, Never>?
    @ObservationIgnored private var retrySaveTask: Task<Void, Never>?

    init(browser: StudioBrowser) { self.browser = browser }
    var models: [StudioValue] { providers.first { $0["id"].string == providerID }?["models"].array ?? [] }
    var visibleMessages: [StudioMessage] { document?.snapshot.messages.filter { $0.role != "tool" && !$0.content.isEmpty } ?? [] }
    var scene: StudioScene? {
        guard let document, let file = document.snapshot.file(document.snapshot.scenePath) else { return nil }
        return try? StudioScene(data: file.data)
    }
    var selectedEntity: StudioValue? { scene?.entities.first { $0["id"].string == document?.selection } }

    func start() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let me = try StudioValue.decode(await browser.request(path: "/v1/me"))
            guard let id = me["id"].string else { throw StudioError.unavailable("Войдите в Ada Cloud.") }
            accountID = id; accountName = me["name"].string ?? "Ada Creator"
            let config = try StudioValue.decode(await browser.request(path: "/v1/ai/studio-config"))
            guard config["enabled"] == .bool(true) else { throw StudioError.unavailable("Ada Studio Web пока недоступен в этом окружении.") }
            publishingEnabled = config["publishingEnabled"] != .bool(false)
            providers = try StudioValue.decode(await browser.request(path: "/v1/ai/providers")).array
            providerID = providers.first?["id"].string ?? ""
            modelID = models.first?["id"].string ?? ""
            try await refreshProjects()
            status = "Готово"
        } catch StudioError.authenticationRequired { accountID = nil; error = nil; status = "Войдите в Ada Cloud" }
        catch { self.error = error.localizedDescription; status = "Нет соединения" }
    }
    func refreshProjects() async throws { projects = try JSONDecoder().decode([StudioWorkspace].self, from: await browser.request(path: "/v1/workspaces")) }
    func signIn() {
        browser.fire("signin")
        status = "Войдите в открывшейся вкладке Ada Cloud"
        Task {
            do { _ = try await browser.perform("auth.wait"); await start() }
            catch { self.error = error.localizedDescription }
        }
    }
    func home() {
        guard !isLoading else { return }
        isLoading = true
        stopAgent(); stop()
        Task {
            defer { isLoading = false }
            await agentTask?.value
            await save()
            saveTask?.cancel(); retrySaveTask?.cancel()
            document = nil; workspace = nil
            try? await refreshProjects()
        }
    }

    func create(_ template: StudioTemplate, title: String? = nil) async {
        do { try await create(snapshot: template.makeProject(title: title)) } catch { self.error = error.localizedDescription }
    }
    private func portable(_ snapshot: StudioSnapshot) throws -> StudioSnapshot {
        var snapshot = snapshot; snapshot.files = try snapshot.exportFiles(); return snapshot
    }
    private func create(snapshot: StudioSnapshot) async throws {
        let snapshot = try portable(snapshot)
        let input = StudioValue.object(["operationID": .string(UUID().uuidString.lowercased()), "snapshot": try StudioValue.decode(JSONEncoder().encode(snapshot))])
        let record = try JSONDecoder().decode(StudioWorkspace.self, from: await browser.request(path: "/v1/workspaces", method: "POST", body: input.encoded()))
        workspace = record; document = try StudioDocument(snapshot: snapshot); savedGeneration = 0; status = "Сохранено"; tab = .game
        isRunning = false; browser.stop()
        try await refreshProjects()
    }
    func open(_ project: StudioWorkspace) async {
        guard !isLoading else { return }
        stopAgent(); stop(); isLoading = true
        defer { isLoading = false }
        do {
            await agentTask?.value
            await save()
            let record = try JSONDecoder().decode(StudioWorkspace.self, from: await browser.request(path: "/v1/workspaces/" + project.id))
            guard let snapshot = record.snapshot else { throw StudioError.invalid("Проект не содержит исходников.") }
            workspace = record; document = try StudioDocument(snapshot: snapshot); savedGeneration = 0; status = "Сохранено"; tab = .game
            if let accountID, let data = try await browser.load(account: accountID, project: record.id) {
                let recovery = try JSONDecoder().decode(StudioRecovery.self, from: data)
                if recovery.snapshot != snapshot {
                    if recovery.revision == record.revision {
                        try document?.replace(recovery.snapshot); changed()
                    } else {
                        var copy = recovery.snapshot; copy.title += " — восстановлено"
                        try await create(snapshot: copy)
                        error = "Найдены несохранённые изменения. Они восстановлены отдельным проектом."
                    }
                }
            }
        } catch { self.error = error.localizedDescription; status = "Нет соединения" }
    }

    func changed(checkpoint: Bool = false) {
        checkpointPending = checkpointPending || checkpoint
        guard let document, workspace != nil else { return }
        guard savedGeneration != document.generation || checkpointPending else { status = "Сохранено"; return }
        status = "Сохраняется…"
        // Serialize recovery writes so a slower old IndexedDB transaction cannot replace a newer draft.
        let previous = recoveryTask
        if let accountID, let workspace {
            let snapshot = document.snapshot
            recoveryTask = Task { [browser] in
                await previous?.value
                do { try await browser.save(account: accountID, project: workspace.id, data: JSONEncoder().encode(StudioRecovery(revision: workspace.revision, snapshot: snapshot))) }
                catch { self.error = "Не удалось сохранить локальное восстановление: \(error.localizedDescription)" }
            }
        }
        saveTask?.cancel()
        saveTask = Task {
            do { try await Task.sleep(for: .seconds(1)); try Task.checkCancellation(); await save() } catch { }
        }
    }
    func save(checkpoint: Bool = false) async {
        checkpointPending = checkpointPending || checkpoint
        if saveInFlight {
            await withCheckedContinuation { saveWaiters.append($0) }
            await save()
            return
        }
        guard let workspace, let document else { return }
        guard savedGeneration != document.generation || checkpointPending else { return }
        saveInFlight = true
        defer {
            saveInFlight = false
            let waiters = saveWaiters; saveWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
        }
        let generation = document.generation, snapshot = document.snapshot, checkpoint = checkpointPending
        checkpointPending = false
        do {
            let input: StudioValue = .object(["operationID": .string(UUID().uuidString.lowercased()), "expectedRevision": .int(workspace.revision),
                "checkpoint": .bool(checkpoint), "snapshot": try StudioValue.decode(JSONEncoder().encode(portable(snapshot)))])
            let record = try JSONDecoder().decode(StudioWorkspace.self, from: await browser.request(path: "/v1/workspaces/" + workspace.id, method: "PUT", body: input.encoded()))
            guard self.workspace?.id == workspace.id else { return }
            self.workspace = record; savedGeneration = generation
            if document.generation == generation && !checkpointPending {
                status = "Сохранено"
                await recoveryTask?.value
                if let accountID, document.generation == generation { try await browser.remove(account: accountID, project: record.id) }
            } else { changed() }
        } catch StudioError.authenticationRequired {
            guard self.workspace?.id == workspace.id, self.document === document else { return }
            stopAgent(); accountID = nil; status = "Войдите в Ada Cloud"; self.error = nil
        } catch StudioError.conflict {
            guard self.workspace?.id == workspace.id, self.document === document else { return }
            stopAgent()
            do {
                var copy = document.snapshot; copy.title += " — копия"
                try await create(snapshot: copy)
                error = "Проект изменён в другой вкладке. Ваши изменения сохранены отдельным проектом."
            } catch { self.error = error.localizedDescription; status = "Нет соединения" }
        } catch {
            guard self.workspace?.id == workspace.id, self.document === document else { return }
            checkpointPending = checkpointPending || checkpoint; self.error = error.localizedDescription; status = "Нет соединения"
            retrySaveTask?.cancel()
            retrySaveTask = Task {
                do {
                    _ = try await browser.perform("network.wait")
                    try Task.checkCancellation()
                    guard self.workspace?.id == workspace.id else { return }
                    await save()
                } catch { }
            }
        }
    }

    func importProject() async {
        do {
            guard let archive = try await browser.open(accept: ".zip") else { return }
            let files = try StudioArchive.decode(archive.data)
            let metadata = try files.first(where: { $0.path == ".ada/project.json" }).map { try StudioValue.decode($0.data) }
            let snapshot = StudioSnapshot(title: metadata?["project"]["displayName"].string ?? "Импортированная игра", files: files)
            try await create(snapshot: snapshot.importedCopy())
        } catch { self.error = error.localizedDescription }
    }
    func download() {
        do {
            guard let snapshot = document?.snapshot else { return }
            try browser.download(name: "AdaStudio-Project.zip", data: StudioArchive.encode(snapshot.exportFiles()))
        } catch { self.error = error.localizedDescription }
    }
    func attachAsset() async {
        do {
            if document == nil { try await create(snapshot: StudioTemplate.game2D.makeProject()) }
            guard let file = try await browser.open(accept: ".png,.jpg,.jpeg,.wav,.ogg,.glb") else { return }
            let name = file.path.replacingOccurrences(of: " ", with: "_")
            let path = "Assets/Imports/" + UUID().uuidString.lowercased() + "_" + name
            try document?.write(path, data: file.data); attachmentPaths.append(path); changed()
        } catch { self.error = error.localizedDescription }
    }
    func writeCode(_ text: String) {
        do { try document?.write(activeFile, data: Data(text.utf8)); changed() } catch { self.error = error.localizedDescription }
    }
    func undo() { document?.undo(); changed(); refreshScenePreview() }
    func redo() { document?.redo(); changed(); refreshScenePreview() }
    func setSceneField(component: String, field: String, text: String) {
        do {
            guard var scene, let id = document?.selection, let document else { return }
            let value = (try? StudioValue.decode(Data(text.utf8))) ?? .string(text)
            try scene.set(entity: id, component: component, field: field, value: value)
            try document.write(document.snapshot.scenePath, data: scene.encoded()); changed()
            refreshScenePreview()
        } catch { self.error = error.localizedDescription }
    }
    func addEntity() {
        do {
            guard var scene, let document else { return }
            let id = try scene.add(name: "Object", components: ["AdaTransform.Transform": StudioTemplate.transform()])
            try document.write(document.snapshot.scenePath, data: scene.encoded()); document.select(id); changed()
            refreshScenePreview()
        } catch { self.error = error.localizedDescription }
    }
    func removeSelectedEntity() {
        do {
            guard var scene, let document, let selection = document.selection else { return }
            scene.remove(selection)
            try document.write(document.snapshot.scenePath, data: scene.encoded()); document.select(nil); changed(); refreshScenePreview()
        } catch { self.error = error.localizedDescription }
    }
    func history() async {
        do {
            guard let workspace else { return }
            checkpoints = try JSONDecoder().decode([StudioCheckpoint].self, from: await browser.request(path: "/v1/workspaces/\(workspace.id)/history"))
            if publishingEnabled, let pageID = workspace.pageID {
                releases = try StudioValue.decode(await browser.request(path: "/v1/game-releases?pageId=" + pageID)).array
            } else { releases = [] }
            showsHistory = true; isRunning = false; browser.stop()
        } catch { self.error = error.localizedDescription }
    }
    func restore(_ checkpoint: StudioCheckpoint) async {
        do {
            guard let workspace else { return }
            let input: StudioValue = .object(["operationID": .string(UUID().uuidString.lowercased()), "revision": .int(checkpoint.revision), "expectedRevision": .int(workspace.revision)])
            _ = try await browser.request(path: "/v1/workspaces/\(workspace.id)/restore", method: "POST", body: input.encoded())
            await recoveryTask?.value
            if let accountID { try await browser.remove(account: accountID, project: workspace.id) }
            showsHistory = false; await open(workspace)
        } catch { self.error = error.localizedDescription }
    }
    func activateRelease(_ release: StudioValue) async {
        guard publishingEnabled else { return }
        do {
            guard let id = release["id"].string else { return }
            _ = try await browser.request(path: "/v1/game-releases/\(id)/activate", method: "POST", body: Data("{}".utf8))
            publicationStatus = "Опубликованная версия восстановлена"
        } catch { self.error = error.localizedDescription }
    }
    func deleteProject(_ project: StudioWorkspace) async {
        do {
            _ = try await browser.request(path: "/v1/workspaces/" + project.id, method: "DELETE")
            if let accountID { try await browser.remove(account: accountID, project: project.id) }
            try await refreshProjects()
        } catch { self.error = error.localizedDescription }
    }
    func play() async {
        let request = UUID(); previewRequest = request
        do {
            guard let snapshot = document?.snapshot else { return }
            let diagnostics = validateSources()
            guard diagnostics.isEmpty else { throw StudioError.invalid(diagnostics) }
            isRunning = true
            browser.editMode = tab == .scene
            try await browser.load(snapshot)
        } catch { if previewRequest == request { self.error = error.localizedDescription; isRunning = false } }
    }
    func stop() { scenePreviewTask?.cancel(); previewRequest = UUID(); browser.stop(); isRunning = false }
    private func refreshScenePreview() {
        guard tab == .scene else { return }
        scenePreviewTask?.cancel()
        scenePreviewTask = Task {
            do { try await Task.sleep(for: .milliseconds(500)); try Task.checkCancellation(); await play() } catch { }
        }
    }
    func validateSources() -> String {
        guard let snapshot = document?.snapshot else { return "Нет проекта." }
        do {
            let sources = snapshot.sources.map { AdaScriptCompilerSource(path: $0.path, source: $0.text) }
            let schemas = try AdaScriptSchemaParser.parse(sources: sources)
            var environment = AdaScriptTypeEnvironment.standard; environment.register(schemas: schemas)
            try AdaScriptAnalyzer.analyze(sources: sources, environment: environment).requireValidTypes(mode: .strict)
            _ = try StudioScene(data: requireScene(snapshot))
            return ""
        } catch { return error.localizedDescription }
    }
    private func requireScene(_ snapshot: StudioSnapshot) throws -> Data {
        guard let data = snapshot.file(snapshot.scenePath)?.data else { throw StudioError.invalid("Нет сцены.") }
        return data
    }
}

private struct StudioRecovery: Codable { let revision: Int; let snapshot: StudioSnapshot }
