@testable import AdaEditor
import Foundation
import Testing

@Suite("EditorProjectStore")
struct EditorProjectStoreTests {
    @Test("default storage URL points to Application Support AdaEditor projects json")
    func defaultStorageURL() {
        let url = EditorProjectStore.defaultStorageURL()

        #expect(url.lastPathComponent == "projects.json")
        #expect(url.deletingLastPathComponent().lastPathComponent == "AdaEditor")
    }

    @Test("create project writes SwiftPM package, Ada metadata, and recent projects")
    func createProjectPersistsRecentProject() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectStore")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let storageURL = rootURL.appendingPathComponent("Application Support/AdaEditor/projects.json")
        let projectsRoot = rootURL.appendingPathComponent("Projects", isDirectory: true)
        let store = EditorProjectStore(storageURL: storageURL)
        let openedAt = try #require(ISO8601DateFormatter().date(from: "2026-02-19T10:00:00Z"))

        let reference = try store.createProject(named: "My Game", at: projectsRoot, openedAt: openedAt)
        let projectURL = projectsRoot.appendingPathComponent("My-Game", isDirectory: true)

        #expect(reference.name == "My-Game")
        #expect(reference.path == projectURL.standardizedFileURL.path)
        #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path))
        #expect(ProjectSystem.isAdaProject(at: projectURL))
        #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("README.md").path))
        #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("Assets", isDirectory: true).appendingPathComponent(".gitkeep").path))
        let sceneURL = projectURL.appendingPathComponent("Assets/Scenes/Main.ascn", isDirectory: false)
        #expect(FileManager.default.fileExists(atPath: sceneURL.path))
        #expect(try String(contentsOf: sceneURL, encoding: .utf8).contains("format: ada.scene"))
        let loadedProjects = try store.loadProjects()
        #expect(loadedProjects == [reference])
    }

    @Test("open existing SwiftPM project creates Ada metadata and moves project to top")
    func openProjectCreatesMetadataAndDeduplicatesRecentProjects() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectStoreOpen")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let storageURL = rootURL.appendingPathComponent("Application Support/AdaEditor/projects.json")
        let store = EditorProjectStore(storageURL: storageURL)
        let projectURL = rootURL.appendingPathComponent("Existing", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try "// swift-tools-version: 6.2\n".write(to: projectURL.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let firstDate = try #require(ISO8601DateFormatter().date(from: "2026-02-19T10:00:00Z"))
        let secondDate = try #require(ISO8601DateFormatter().date(from: "2026-02-20T10:00:00Z"))

        _ = try store.openProject(at: projectURL, openedAt: firstDate)
        let secondReference = try store.openProject(at: projectURL, openedAt: secondDate)
        let projects = try store.loadProjects()

        #expect(ProjectSystem.isAdaProject(at: projectURL))
        #expect(try ProjectSystem.loadProject(at: projectURL).editor.startupScene == "Assets/Scenes/Main.ascn")
        #expect(projects.count == 1)
        #expect(projects.first == secondReference)
        #expect(projects.first?.lastOpenedAt == secondDate)
    }

    @Test("open existing requires SwiftPM manifest")
    func openRequiresSwiftPMManifest() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectStoreMissingManifest")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let store = EditorProjectStore(storageURL: rootURL.appendingPathComponent("projects.json"))

        do {
            _ = try store.openProject(at: rootURL)
            Issue.record("Expected openProject to throw")
        } catch let error as ProjectSystemError {
            #expect(error == .swiftPackageManifestMissing(path: "Package.swift"))
        }
    }

    @Test("view model filters recent projects and abbreviates home paths")
    @MainActor
    func projectOpeningViewModelFiltersAndFormatsProjects() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectViewModel")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let storageURL = rootURL.appendingPathComponent("projects.json")
        let store = EditorProjectStore(storageURL: storageURL)
        let firstDate = try #require(ISO8601DateFormatter().date(from: "2026-02-19T10:00:00Z"))
        let secondDate = try #require(ISO8601DateFormatter().date(from: "2026-02-20T10:00:00Z"))
        let projects = [
            EditorProjectReference(name: "NeonNights_RPG", path: rootURL.appendingPathComponent("NeonNights_RPG").path, lastOpenedAt: secondDate),
            EditorProjectReference(name: "ArchViz_Interior", path: rootURL.appendingPathComponent("ArchViz_Interior").path, lastOpenedAt: firstDate),
        ]
        try store.saveProjects(projects)

        let viewModel = ProjectOpeningViewModel(store: store)
        viewModel.searchQuery = "neon"

        #expect(viewModel.filteredRecentProjects.map(\.name) == ["NeonNights_RPG"])
        #expect(viewModel.detailProject == nil)
        viewModel.selectProject(projects[0])
        #expect(viewModel.detailProject?.name == "NeonNights_RPG")
        #expect(ProjectOpeningViewModel.abbreviatedPath(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("AdaProjects/Neon").path).hasPrefix("~/"))
    }

    @Test("create blank template requires explicit location before editor handoff")
    @MainActor
    func projectOpeningViewModelRequiresLocationBeforeCreate() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectViewModelRequiresLocation")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let storageURL = rootURL.appendingPathComponent("projects.json")
        let store = EditorProjectStore(storageURL: storageURL)
        let viewModel = ProjectOpeningViewModel(store: store)
        viewModel.projectName = "Lost Project"
        viewModel.beginCreateNewProject()

        #expect(viewModel.projectLocation.isEmpty)
        #expect(viewModel.canCreateProject == false)

        viewModel.createBlankTemplateProject()

        #expect(viewModel.detailProject == nil)
        #expect(viewModel.projectToOpenInEditor == nil)
        #expect(viewModel.projectToOpenInEditorToken == 0)
        #expect(viewModel.statusMessage == "Choose a project name and location before creating.")
        #expect(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("Lost-Project", isDirectory: true).path) == false)
    }

    @Test("create blank template creates project and requests editor handoff")
    @MainActor
    func projectOpeningViewModelCreatesProjectForEditorHandoff() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectViewModelCreateHandoff")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let storageURL = rootURL.appendingPathComponent("projects.json")
        let store = EditorProjectStore(storageURL: storageURL)
        let viewModel = ProjectOpeningViewModel(store: store)
        viewModel.projectName = "Editor Flow"
        viewModel.setProjectLocation(rootURL)

        viewModel.createBlankTemplateProject()

        let projectURL = rootURL.appendingPathComponent("Editor-Flow", isDirectory: true)
        #expect(viewModel.detailProject?.path == projectURL.standardizedFileURL.path)
        #expect(viewModel.projectToOpenInEditor?.path == projectURL.standardizedFileURL.path)
        #expect(viewModel.projectToOpenInEditorToken == 1)
        #expect(ProjectSystem.isAdaProject(at: projectURL))
        #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("Sources", isDirectory: true).appendingPathComponent("Editor_Flow", isDirectory: true).appendingPathComponent("main.swift").path))

        let handoffProject = try #require(viewModel.consumeProjectToOpenInEditor())
        #expect(handoffProject.path == projectURL.standardizedFileURL.path)
        #expect(viewModel.projectToOpenInEditor == nil)
    }

    @Test("launcher layout matches design and fits minimum window")
    func projectOpeningLayoutFitsMinimumWindow() {
        #expect(ProjectOpeningLayout.windowWidth == 1024)
        #expect(ProjectOpeningLayout.windowHeight == 700)
        #expect(ProjectOpeningLayout.columnsWidth == ProjectOpeningLayout.windowWidth)
        #expect(ProjectOpeningLayout.detailContentWidth == 556)
        #expect(ProjectOpeningLayout.trafficLightOffsetY == 0)
        #expect(ProjectOpeningLayout.logoTopPadding > ProjectOpeningLayout.trafficLightOffsetY)
        #expect(ProjectOpeningAssets.adaEngineLogoResourceName == "AdaEngine")
        #expect(ProjectOpeningAssets.adaEngineLogoSubdirectory == "Assets")
        #expect(ProjectOpeningLayout.fixedDetailContentHeight <= ProjectOpeningLayout.windowHeight - ProjectOpeningLayout.detailPadding * 2)
        #expect(ProjectOpeningWindowConfiguration.isResizable == false)
        #expect(ProjectOpeningWindowConfiguration.hasShadow == true)
        #expect(ProjectOpeningLayout.detailActionButtonCount == 0)
        #expect(ProjectOpeningLayout.searchUsesGradient == false)
        #expect(ProjectOpeningLayout.searchCapsuleWidth == 280)
        #expect(ProjectOpeningLayout.searchCapsuleHeight > ProjectOpeningLayout.actionButtonHeight)
        #expect(ProjectOpeningLayout.searchBottomPadding == 20)
        #expect(ProjectOpeningLayout.usesNavigationSplitView == true)
        #expect(ProjectOpeningLayout.detailUsesNavigationStack == true)
        #expect(ProjectOpeningLayout.detailUsesSearchable == true)
    }

    @Test("empty project landing exposes logo and required actions")
    func emptyProjectLandingSpecMatchesRequestedActions() {
        #expect(ProjectOpeningLandingSpec.primaryButtonTitles == ["Create new project", "Open project"])
        #expect(ProjectOpeningLandingSpec.footerButtonTitles == ["Report issues", "Support", "Github"])
        #expect(ProjectOpeningLandingSpec.logoSize == 128)
        #expect(ProjectOpeningLandingSpec.primaryButtonWidth > ProjectOpeningLandingSpec.logoSize)
        #expect(ProjectOpeningLandingSpec.primaryButtonHeight > ProjectOpeningLandingSpec.footerButtonHeight)
        #expect(ProjectOpeningLandingSpec.footerButtonHeight < ProjectOpeningLayout.actionButtonHeight)
    }

    @Test("AdaEngineStyle UI layout matches requested reference")
    func editorGlassLayoutMatchesRequestedReference() {
        #expect(AdaEngineStyleLayoutSpec.windowWidth == 1280)
        #expect(AdaEngineStyleLayoutSpec.windowHeight == 820)
        #expect(AdaEngineStyleLayoutSpec.topToolbarHeight == 52)
        #expect(AdaEngineStyleLayoutSpec.toolStripWidth == 40)
        #expect(AdaEngineStyleLayoutSpec.projectSidebarWidth == 260)
        #expect(AdaEngineStyleLayoutSpec.inspectorWidth == 300)
        #expect(AdaEngineStyleLayoutSpec.outputPanelHeight == 42)
        #expect(AdaEngineStyleLayoutSpec.footerHeight == 24)
        #expect(AdaEngineStyleLayoutSpec.aiFlightBoxWidth == 560)
        #expect(AdaEngineStyleContent.logLines.count == 4)
    }

    @Test("project open picker resolves selected package manifest to project directory")
    func projectOpenPickerResolvesManifestToProjectDirectory() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "ProjectOpenPickerManifest")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let manifestURL = rootURL.appendingPathComponent("Package.swift", isDirectory: false)
        try "// swift-tools-version: 6.2\n".write(to: manifestURL, atomically: true, encoding: .utf8)

        #expect(ProjectOpenPicker.projectDirectoryURL(fromPickerSelection: manifestURL) == rootURL.standardizedFileURL)
    }

    @Test("project open picker keeps selected directory as project directory")
    func projectOpenPickerKeepsSelectedDirectory() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "ProjectOpenPickerDirectory")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        #expect(ProjectOpenPicker.projectDirectoryURL(fromPickerSelection: rootURL) == rootURL.standardizedFileURL)
    }

    @Test("project location picker resolves files to their containing directory")
    func projectLocationPickerResolvesFilesToContainingDirectory() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "ProjectLocationPickerFile")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let fileURL = rootURL.appendingPathComponent("note.txt", isDirectory: false)
        try "location".write(to: fileURL, atomically: true, encoding: .utf8)

        #expect(ProjectOpenPicker.projectLocationURL(fromPickerSelection: fileURL) == rootURL.standardizedFileURL)
    }

    @Test("view model opens project from picked URL and requests editor handoff")
    @MainActor
    func projectOpeningViewModelOpensPickedProjectURL() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectViewModelPickedURL")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let storageURL = rootURL.appendingPathComponent("projects.json")
        let store = EditorProjectStore(storageURL: storageURL)
        let projectURL = rootURL.appendingPathComponent("PickedProject", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try "// swift-tools-version: 6.2\n".write(to: projectURL.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let viewModel = ProjectOpeningViewModel(store: store)
        viewModel.openProject(at: projectURL)

        #expect(viewModel.existingProjectPath == projectURL.path)
        #expect(viewModel.detailProject?.path == projectURL.standardizedFileURL.path)
        #expect(viewModel.projectToOpenInEditor?.path == projectURL.standardizedFileURL.path)
        #expect(viewModel.projectToOpenInEditorToken == 1)
        #expect(viewModel.statusMessage.hasPrefix("Opened project:"))
    }

    @Test("view model opens recent project and requests editor handoff")
    @MainActor
    func projectOpeningViewModelOpensRecentProjectForEditorHandoff() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectViewModelOpenRecent")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let storageURL = rootURL.appendingPathComponent("projects.json")
        let store = EditorProjectStore(storageURL: storageURL)
        let projectURL = rootURL.appendingPathComponent("RecentProject", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try "// swift-tools-version: 6.2\n".write(to: projectURL.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        let recentProject = EditorProjectReference(name: "RecentProject", path: projectURL.standardizedFileURL.path)
        try store.saveProjects([recentProject])

        let viewModel = ProjectOpeningViewModel(store: store)
        viewModel.openRecentProject(recentProject)

        #expect(viewModel.detailProject?.path == projectURL.standardizedFileURL.path)
        #expect(viewModel.projectToOpenInEditor?.path == projectURL.standardizedFileURL.path)
        #expect(viewModel.projectToOpenInEditorToken == 1)
        #expect(viewModel.statusMessage.hasPrefix("Opened project:"))
    }

    @Test("view model opens last available project on launch")
    @MainActor
    func projectOpeningViewModelOpensLastAvailableProjectOnLaunch() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectViewModelOpenLast")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let storageURL = rootURL.appendingPathComponent("projects.json")
        let store = EditorProjectStore(storageURL: storageURL)
        let olderProjectURL = rootURL.appendingPathComponent("OlderProject", isDirectory: true)
        let latestProjectURL = rootURL.appendingPathComponent("LatestProject", isDirectory: true)
        try createSwiftPMManifest(at: olderProjectURL)
        try createSwiftPMManifest(at: latestProjectURL)

        let olderDate = try #require(ISO8601DateFormatter().date(from: "2026-02-19T10:00:00Z"))
        let latestDate = try #require(ISO8601DateFormatter().date(from: "2026-02-20T10:00:00Z"))
        try store.saveProjects([
            EditorProjectReference(name: "OlderProject", path: olderProjectURL.standardizedFileURL.path, lastOpenedAt: olderDate),
            EditorProjectReference(name: "LatestProject", path: latestProjectURL.standardizedFileURL.path, lastOpenedAt: latestDate),
        ])

        let viewModel = ProjectOpeningViewModel(store: store)
        let didOpen = viewModel.openLastProjectIfAvailable()

        #expect(didOpen)
        #expect(viewModel.detailProject?.path == latestProjectURL.standardizedFileURL.path)
        #expect(viewModel.projectToOpenInEditor?.path == latestProjectURL.standardizedFileURL.path)
        #expect(viewModel.projectToOpenInEditorToken == 1)
        #expect(viewModel.statusMessage.hasPrefix("Opened project:"))
    }

    @Test("view model leaves welcome visible when last project is missing")
    @MainActor
    func projectOpeningViewModelSkipsMissingLastProjectOnLaunch() throws {
        let rootURL = try makeEditorStoreTemporaryDirectory(named: "EditorProjectViewModelMissingLast")
        defer { removeEditorStoreTemporaryDirectory(rootURL) }

        let storageURL = rootURL.appendingPathComponent("projects.json")
        let store = EditorProjectStore(storageURL: storageURL)
        let missingProjectURL = rootURL.appendingPathComponent("MissingProject", isDirectory: true)
        try store.saveProjects([
            EditorProjectReference(name: "MissingProject", path: missingProjectURL.standardizedFileURL.path)
        ])

        let viewModel = ProjectOpeningViewModel(store: store)
        let didOpen = viewModel.openLastProjectIfAvailable()

        #expect(!didOpen)
        #expect(viewModel.detailProject == nil)
        #expect(viewModel.projectToOpenInEditor == nil)
        #expect(viewModel.projectToOpenInEditorToken == 0)
        #expect(viewModel.statusMessage.hasPrefix("Last project is no longer available:"))
    }
}

private func makeEditorStoreTemporaryDirectory(named name: String? = nil) throws -> URL {
    let directoryName = name ?? "EditorProjectStoreTests-\(UUID().uuidString)"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(directoryName, isDirectory: true)
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func removeEditorStoreTemporaryDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

private func createSwiftPMManifest(at projectURL: URL) throws {
    try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
    try "// swift-tools-version: 6.2\n".write(
        to: projectURL.appendingPathComponent("Package.swift"),
        atomically: true,
        encoding: .utf8
    )
}
