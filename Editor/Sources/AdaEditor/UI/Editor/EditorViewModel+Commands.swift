@_spi(AdaEngine) import AdaEngine
import AdaPackageManifestTool
import Foundation
import Observation

extension EditorViewModel {
    func startEditorSessionIfNeeded() {
        guard !didStartEditorSession else {
            return
        }

        didStartEditorSession = true
        bootstrapWorkspaceIfNeeded()
        refreshSourceControl()
    }

    func bootstrapWorkspaceIfNeeded(force: Bool = false) {
        guard workspaceTask == nil, let projectURL else {
            return
        }
        guard force || workspaceStatus == .idle || packageModel == nil else {
            return
        }

        if let settings = try? ProjectSystem.loadProject(at: projectURL, fileManager: fileManager) {
            if settings.build.system == .adaScript {
                buildAdaScriptProject(settings, at: projectURL, statusTitle: "Prepare AdaScript Workspace")
                return
            }
            #if os(iOS)
            do {
                try ProjectSystem.validateRunCompatibility(
                    of: settings,
                    at: projectURL,
                    destination: .iPadOS,
                    fileManager: fileManager
                )
            } catch {
                workspaceStatus = .failed(error.message)
                footer.setWorkspaceFooterTitle(workspaceStatus.title)
                appendOutput(error.message)
                return
            }
            #endif
        }

        workspaceStatus = .resolving
        buildActivity = EditorBuildActivity(title: "Prepare Workspace")
        footer.setWorkspaceFooterTitle("Workspace: Preparing")
        lastLoggedWorkspaceProgressPhase = nil
        appendOutput("Loading \(ProjectSystem.metadataFileName) and resolving SwiftPM dependencies...")

        workspaceTask = Task { [weak self] in
            guard let self else { return }
            await self.workspaceService.setDiagnosticsHandler { [weak self] uri, diagnostics in
                await MainActor.run {
                    self?.receiveSourceDiagnostics(diagnostics, uri: uri)
                }
            }
            let result = await self.workspaceService.bootstrap(projectURL: projectURL) { progress in
                await MainActor.run {
                    self.handleWorkspaceProgress(progress)
                }
            }
            await MainActor.run {
                self.packageModel = result.packageModel
                self.replaceBuildDiagnostics(with: result.diagnostics)
                self.showProblemsIfNeeded()
                let failureOutput = result.describeResult.combinedOutput.isEmpty
                    ? result.resolveResult.combinedOutput
                    : result.describeResult.combinedOutput
                self.workspaceStatus = result.succeeded ? .ready : .failed(failureOutput)
                self.footer.setWorkspaceFooterTitle(self.workspaceStatus.title)
                self.selectedRunProduct = self.selectedRunProduct ?? self.runProducts.first
                self.appendOutput(result.resolveResult)
                self.appendOutput(result.describeResult)
                if let indexBuildResult = result.indexBuildResult {
                    self.workspaceStatus = indexBuildResult.succeeded ? .ready : .failed(indexBuildResult.combinedOutput)
                    self.footer.setWorkspaceFooterTitle(self.workspaceStatus.title)
                    self.appendOutput(indexBuildResult)
                }
                self.buildActivity?.finish(
                    succeeded: result.succeeded && result.indexBuildResult?.succeeded != false
                )
                self.workspaceTask = nil
                self.refreshPreviewForActiveDocument()
            }
        }
    }

    func refreshSourceControl() {
        guard let projectURL else {
            sourceControl.snapshot = .empty
            sourceControl.statusMessage = "No project is open."
            footer.setSourceControlFooterTitle("Git: unavailable")
            return
        }

        sourceControlTask?.cancel()
        sourceControl.isRunning = true
        sourceControl.statusMessage = "Refreshing source control..."

        sourceControlTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.sourceControlService.snapshot(projectURL: projectURL)
            await MainActor.run {
                self.sourceControl.snapshot = result.snapshot
                self.sourceControl.statusMessage = self.sourceControlStatusMessage(for: result)
                self.sourceControl.isRunning = false
                self.footer.setSourceControlFooterTitle(result.snapshot.footerTitle)
                if !result.succeeded {
                    self.appendOutput(result.statusResult)
                    if let branchResult = result.branchResult, !branchResult.succeeded {
                        self.appendOutput(branchResult)
                    }
                }
                self.sourceControlTask = nil
            }
        }
    }

    func stageSourceControlFile(_ path: String) {
        executeSourceControlCommand(.stage(paths: [path]), statusTitle: "Stage \(path)")
    }

    func stageAllSourceControlFiles() {
        executeSourceControlCommand(.stage(paths: []), statusTitle: "Stage All")
    }

    func unstageSourceControlFile(_ path: String) {
        executeSourceControlCommand(.unstage(paths: [path]), statusTitle: "Unstage \(path)")
    }

    func unstageAllSourceControlFiles() {
        executeSourceControlCommand(.unstage(paths: []), statusTitle: "Unstage All")
    }

    func stashSourceControlChanges() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        executeSourceControlCommand(.stash(message: "AdaEditor stash \(timestamp)"), statusTitle: "Stash")
    }

    func commitSourceControlChanges() {
        let message = sourceControl.trimmedCommitMessage
        guard !message.isEmpty else {
            sourceControl.statusMessage = "Enter a commit message."
            return
        }

        guard !sourceControl.snapshot.stagedFiles.isEmpty else {
            sourceControl.statusMessage = "Stage files before committing."
            return
        }

        executeSourceControlCommand(.commit(message: message), statusTitle: "Commit", clearsCommitMessage: true)
    }

    func pullSourceControlChanges() {
        executeSourceControlCommand(.pull, statusTitle: "Pull")
    }

    func pushSourceControlChanges() {
        executeSourceControlCommand(.push, statusTitle: "Push")
    }

    func checkoutSourceControlBranch(_ branch: GitBranch) {
        guard !branch.isCurrent else {
            return
        }

        executeSourceControlCommand(.checkout(branch: branch.name), statusTitle: "Checkout \(branch.name)")
    }

    func createSourceControlBranch() {
        let branchName = sourceControl.trimmedNewBranchName
        guard !branchName.isEmpty else {
            sourceControl.statusMessage = "Enter a branch name."
            return
        }

        executeSourceControlCommand(.createBranch(name: branchName), statusTitle: "Create Branch \(branchName)", clearsNewBranchName: true)
    }

    func buildAll() {
        if let projectURL,
           let settings = try? ProjectSystem.loadProject(at: projectURL, fileManager: fileManager),
           settings.build.system == .adaScript {
            buildAdaScriptProject(settings, at: projectURL, statusTitle: "Build AdaScript Project")
            return
        }
        executeWorkspaceCommand(.build(target: nil, buildTests: true), statusTitle: "Build")
    }

    func buildTarget(_ target: String) {
        if let projectURL,
           let settings = try? ProjectSystem.loadProject(at: projectURL, fileManager: fileManager),
           settings.build.system == .adaScript {
            buildAdaScriptProject(settings, at: projectURL, statusTitle: "Build AdaScript Project")
            return
        }
        executeWorkspaceCommand(.build(target: target, buildTests: false), statusTitle: "Build \(target)")
    }

    func runSelectedTarget() {
        let product = selectedRunProduct ?? runProducts.first
        if workbench.activeDocument?.isDirty == true {
            guard saveActiveDocumentIfNeeded() else {
                let detail = workbench.activeDocumentSaveFailureDescription ?? "the active document could not be saved"
                workspaceStatus = .failed("Run blocked: \(detail)")
                footer.setWorkspaceFooterTitle(workspaceStatus.title)
                appendOutput("Run blocked: \(detail)")
                return
            }
        }
        let projectSettings = projectURL.flatMap {
            try? ProjectSystem.loadProject(at: $0, fileManager: fileManager)
        }
        if let projectURL,
           let settings = projectSettings,
           settings.build.system == .adaScript {
            let projectName = settings.project.displayName ?? settings.project.name ?? project?.name ?? "AdaScript Project"
            buildAdaScriptProject(
                settings,
                at: projectURL,
                statusTitle: "Build AdaScript Project"
            ) { [weak self] artifact in
                self?.launchAdaScriptProject(artifact, projectName: projectName)
            }
            return
        }
        switch selectedRunDestination {
        case .macOS:
            executeWorkspaceCommand(
                .run(target: product, arguments: projectSettings?.run.arguments ?? []),
                statusTitle: product.map { "Run \($0) on macOS" } ?? "Run on macOS"
            )
        case .web:
            guard let product else {
                workspaceStatus = .failed("Select an executable product before running for Web.")
                return
            }
            executeWorkspaceCommand(
                .runWeb(target: product, outputPath: "dist/web", serve: true),
                statusTitle: "Run \(product) on Web · http://127.0.0.1:8080"
            )
        case .iPadOS:
            guard let projectURL,
                  let settings = try? ProjectSystem.loadProject(at: projectURL, fileManager: fileManager) else {
                workspaceStatus = .failed("Unable to load project settings for iPadOS.")
                return
            }
            do {
                try ProjectSystem.validateRunCompatibility(of: settings, at: projectURL, destination: .iPadOS, fileManager: fileManager)
            } catch {
                workspaceStatus = .failed(error.message)
                footer.setWorkspaceFooterTitle(workspaceStatus.title)
                appendOutput(error.message)
            }
        }
    }

    func buildAdaScriptProject(
        _ settings: AdaProject,
        at projectURL: URL,
        statusTitle: String,
        onSuccess: @escaping @MainActor (EditorAdaScriptProjectBuildArtifact) -> Void = { _ in }
    ) {
        guard workspaceTask == nil else {
            return
        }
        workspaceStatus = .running(statusTitle)
        buildActivity = EditorBuildActivity(title: statusTitle)
        footer.setWorkspaceFooterTitle(workspaceStatus.title)
        appendOutput("Compiling AdaScript sources (SwiftPM disabled)...")
        let destination = selectedRunDestination.adaProjectDestination
        workspaceTask = Task { [weak self] in
            let outcome = await Task.detached(priority: .userInitiated) {
                Self.prepareAdaScriptProject(
                    settings,
                    at: projectURL,
                    destination: destination
                )
            }.value
            guard !Task.isCancelled, let self else {
                return
            }
            self.workspaceTask = nil
            switch outcome {
            case .success(let artifact):
                self.finishAdaScriptProjectBuild(artifact)
                onSuccess(artifact)
            case .projectFailure(let error):
                self.finishAdaScriptProjectBuildFailure(message: error.message)
            case .failure(let message):
                self.finishAdaScriptProjectBuildFailure(message: message)
            }
        }
    }

    nonisolated private static func prepareAdaScriptProject(
        _ settings: AdaProject,
        at projectURL: URL,
        destination: AdaProjectRunDestination
    ) -> EditorAdaScriptProjectBuildOutcome {
        let fileManager = FileManager()
        do {
            try ProjectSystem.validateRunCompatibility(
                of: settings,
                at: projectURL,
                destination: destination,
                fileManager: fileManager
            )
            return .success(
                try EditorAdaScriptProjectBuilder(fileManager: fileManager).prepare(
                    project: settings,
                    at: projectURL
                )
            )
        } catch let error as ProjectSystemError {
            return .projectFailure(error)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    func finishAdaScriptProjectBuild(_ artifact: EditorAdaScriptProjectBuildArtifact) {
        let report = artifact.report
        packageModel = nil
        workspaceStatus = .ready
        footer.setWorkspaceFooterTitle(workspaceStatus.title)
        buildActivity?.finish(succeeded: true)
        appendOutput(
            "AdaScript build succeeded: \(report.sourceCount) source(s), \(report.systemCount) system(s), \(report.viewCount) view(s), entry \(report.entryDescription)."
        )
        appendOutput("Runtime plugins: \(report.pluginIDs.joined(separator: ", "))")
        refreshPreviewForActiveDocument()
    }

    func finishAdaScriptProjectBuildFailure(message: String) {
        workspaceStatus = .failed(message)
        footer.setWorkspaceFooterTitle(workspaceStatus.title)
        buildActivity?.finish(succeeded: false)
        appendOutput(message)
    }

    func launchAdaScriptProject(
        _ artifact: EditorAdaScriptProjectBuildArtifact,
        projectName: String
    ) {
        do {
            let runtimeView = try EditorAdaScriptProjectRuntimeView(artifact: artifact)
            let windowManager = try requireWindowManager()
            adaScriptRuntimeWindow?.close()
            let windowSettings = artifact.window
            let width = Float(windowSettings.size.width)
            let height = Float(windowSettings.size.height)
            let windowTitle = windowSettings.title?.nilIfEmpty ?? projectName
            let configuration = UIWindow.Configuration(
                title: windowTitle,
                frame: Rect(x: 0, y: 0, width: width, height: height),
                minimumSize: Size(width: min(640, width), height: min(420, height)),
                mode: .windowed,
                showsImmediately: false,
                makeKey: true,
                isResizable: windowSettings.isResizable,
                scenePresentation: .new
            )
            let window = windowManager.spawnWindow(configuration: configuration) {
                runtimeView
            }
            window.onDidDisappear = { [weak self, weak window] in
                guard let self, self.adaScriptRuntimeWindow === window else {
                    return
                }
                self.adaScriptRuntimeWindow = nil
                self.workspaceStatus = .ready
                self.footer.setWorkspaceFooterTitle(self.workspaceStatus.title)
                self.appendOutput("AdaScript project \(windowTitle) stopped.")
            }
            window.showWindow(makeFocused: true)
            adaScriptRuntimeWindow = window
            workspaceStatus = .running("Run \(windowTitle)")
            footer.setWorkspaceFooterTitle(workspaceStatus.title)
            appendOutput("Running AdaScript project \(windowTitle) in a separate window scene.")
        } catch {
            workspaceStatus = .failed(error.localizedDescription)
            footer.setWorkspaceFooterTitle(workspaceStatus.title)
            appendOutput("AdaScript launch failed: \(error.localizedDescription)")
        }
    }

    func requireWindowManager() throws -> UIWindowManager {
        guard let windowManager = UIWindowManager.shared else {
            throw EditorAdaScriptRuntimeError.windowManagerUnavailable
        }
        return windowManager
    }

    var isProjectRunning: Bool {
        if case .running = workspaceStatus {
            return true
        }
        return false
    }

    var activeActivities: [EditorActivityEvent] {
        EditorActivityPresentation.events(
            workspaceStatus: workspaceStatus,
            buildActivity: buildActivity,
            previewStatus: workbench.previewStatus,
            sourceControlIsRunning: sourceControl.isRunning,
            sourceControlTitle: sourceControl.statusMessage
        )
    }

    func runActiveSceneInEditor() {
        guard !playModeState.isPlaying else {
            return
        }
        reloadScriptableObjectSupport()

        guard let document = sceneDocumentForPlay() else {
            return
        }

        guard EditorSceneFileLoader.model(from: document.content) != nil else {
            failPlayMode("Unable to play \(document.title): scene document is invalid.")
            return
        }

        workbench.open(.scene(document))
        toolbar.sceneName = URL(fileURLWithPath: document.title).deletingPathExtension().lastPathComponent
        playModeState = .playing(sceneDocumentID: document.id, title: document.title)
        workspaceStatus = .running("Play \(document.title)")
        appendOutput("Playing \(document.relativePath)")
    }

    func runFromToolbar() {
        if workbench.activeSceneDocument != nil {
            runActiveSceneInEditor()
        } else {
            runSelectedTarget()
        }
    }

    func stopFromToolbar() {
        if playModeState.isPlaying {
            stopPlayMode()
        } else {
            cancelWorkspaceCommand()
        }
    }

    func presentSceneInspector() {
        toolStrip.activeRightTool = "inspector"
        showRightPanel = true
    }

    func stopPlayMode() {
        guard playModeState.isPlaying else {
            return
        }

        playModeState = .editing
        workspaceStatus = .ready
        appendOutput("Stopped Play Mode")
    }

    func runTests(filter: String? = nil) {
        executeWorkspaceCommand(.test(filter: filter ?? selectedTestFilter.nilIfEmpty), statusTitle: "Test")
    }

    func updateDependencies() {
        executeWorkspaceCommand(.update, statusTitle: "Update Dependencies")
    }

    func cleanPackageCache() {
        executeWorkspaceCommand(.clean, statusTitle: "Clean")
    }

    func resetPackageCache() {
        executeWorkspaceCommand(.reset, statusTitle: "Reset")
    }

    func cancelWorkspaceCommand() {
        if playModeState.isPlaying {
            stopPlayMode()
            return
        }
        if let adaScriptRuntimeWindow {
            adaScriptRuntimeWindow.close()
            self.adaScriptRuntimeWindow = nil
            workspaceStatus = .ready
            footer.setWorkspaceFooterTitle(workspaceStatus.title)
            appendOutput("Stopped AdaScript project.")
            return
        }
        workspaceTask?.cancel()
        workspaceTask = nil
        workspaceStatus = .cancelled
        Task {
            await workspaceService.cancel()
        }
    }

    @discardableResult
    func handleMenuCommand(_ command: EditorMenuCommand) -> Bool {
        switch command {
        case .showSettings:
            presentSettings(.general)
        case .newFile:
            presentNewFileDialog()
        case .newProject:
            ProjectEditorLauncher.openWelcome(beginCreatingProject: true)
        case .openProject:
            openProjectFromMenu()
        case .importAssets:
            importAssets()
        case .save:
            saveActiveDocument()
        case .saveAll:
            if workbench.saveAllDocuments() {
                refreshSourceControl()
                reloadScriptableObjectSupport()
            }
        case .findInProject:
            findInProjectRoot()
            _ = EditorSearchShortcutMonitor.shared.focusSearchField()
        case .navigateBack:
            navigateBack()
        case .navigateForward:
            navigateForward()
        case .showProjectNavigator:
            toolStrip.activeLeftTopTool = "fileTree"
            showLeftPanel = true
        case .showInspector:
            toolStrip.activeRightTool = "inspector"
            showRightPanel = true
        case .showBuildOutput:
            showBuildOutput()
        case .showProblems:
            showBottomPanel = true
            selectOutputTab("Problems")
        case .refreshProjectFiles:
            refreshProjectFiles()
        case .revealProject:
            if let projectURL { _ = EditorPlatformFileActions.reveal(projectURL) }
        case .openProjectInTerminal:
            if let projectURL { _ = EditorPlatformFileActions.openInTerminal(projectURL) }
        case .showProjectSettings:
            presentSettings(.project)
        case .showProjectDependencies:
            toolStrip.activeRightTool = "projectDependencies"
            showRightPanel = true
        case .showPackageTasks:
            toolStrip.activeRightTool = "swiftPackageTasks"
            showRightPanel = true
        case .build:
            buildAll()
        case .run:
            if workbench.activeSceneDocument != nil {
                runActiveSceneInEditor()
            } else {
                runSelectedTarget()
            }
        case .runTests:
            runTests()
        case .stop:
            cancelWorkspaceCommand()
        case .clean:
            cleanPackageCache()
        case .updateDependencies:
            updateDependencies()
        case .rebuildPreview:
            rebuildSelectedPreview()
        case .closeEditorTab:
            workbench.closeDocument(id: workbench.activeDocumentID)
        case .closeAllEditorTabs:
            workbench.closeAllDocuments()
        case .increaseCodeFontSize:
            workbench.increaseCodeFontSize()
        case .decreaseCodeFontSize:
            workbench.decreaseCodeFontSize()
        case .resetCodeFontSize:
            workbench.resetCodeFontSize()
        case .closeEditor, .undo, .redo, .cut, .copy, .paste, .selectAll, .enterFullScreen,
             .minimizeWindow, .zoomWindow, .bringAllToFront, .showDocumentation, .showSourceRepository:
            return false
        }
        return true
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
