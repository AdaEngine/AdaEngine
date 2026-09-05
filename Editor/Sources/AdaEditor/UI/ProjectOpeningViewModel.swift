//
//  ProjectOpeningViewModel.swift
//  AdaEngine
//

@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation

enum ProjectOpeningSection: String, CaseIterable, Equatable, Sendable {
    case projects
    case templates
    case samples

    var title: String {
        rawValue.capitalized
    }
}

struct ProjectOpeningDiagnostic: Equatable, Identifiable, Sendable {
    var id: String { code + ":" + (fieldPath ?? "") + ":" + message }
    var code: String
    var fieldPath: String?
    var message: String
    var recoverySuggestion: String

    init(error: ProjectSystemError) {
        self.code = error.code
        self.fieldPath = error.fieldPath
        self.message = error.message
        self.recoverySuggestion = error.recoverySuggestion
    }
}

@Observable
@MainActor
final class ProjectOpeningViewModel {
    var recentProjects: [EditorProjectReference] = []
    var projectName: String = "AdaGame"
    var projectLocation: String = ""
    var isCreatingNewProject = false
    var existingProjectPath: String = ""
    var searchQuery: String = ""
    var selectedSection = ProjectOpeningSection.projects
    var selectedTemplate = EditorProjectTemplate.adaScript
    var selectedProject: EditorProjectReference?
    var statusMessage: String = "Select a recent Ada project, create a blank one, or open an existing project."
    var validationDiagnostics: [ProjectOpeningDiagnostic] = []
    var projectToOpenInEditor: EditorProjectReference?
    var projectToOpenInEditorToken = 0
    var isOpeningLastProject = false

    var projectNameBinding: Binding<String> {
        Binding(get: { self.projectName }, set: { self.projectName = $0 })
    }

    var projectLocationBinding: Binding<String> {
        Binding(get: { self.projectLocation }, set: { self.projectLocation = $0 })
    }

    var existingProjectPathBinding: Binding<String> {
        Binding(get: { self.existingProjectPath }, set: { self.existingProjectPath = $0 })
    }

    var searchQueryBinding: Binding<String> {
        Binding(get: { self.searchQuery }, set: { self.searchQuery = $0 })
    }

    var filteredRecentProjects: [EditorProjectReference] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return recentProjects
        }

        return recentProjects.filter { project in
            project.name.localizedCaseInsensitiveContains(query)
                || project.path.localizedCaseInsensitiveContains(query)
        }
    }

    var detailProject: EditorProjectReference? {
        selectedProject
    }

    var validationSummary: String? {
        validationDiagnostics.first.map { diagnostic in
            if let fieldPath = diagnostic.fieldPath {
                return "\(diagnostic.code) at \(fieldPath)"
            }
            return diagnostic.code
        }
    }

    var hasValidProjectName: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canCreateProject: Bool {
        hasValidProjectName && !projectLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var projectLocationDisplayText: String {
        let trimmed = projectLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Choose a folder"
        }
        return Self.abbreviatedPath(trimmed)
    }

    private let store: EditorProjectStore

    init(store: EditorProjectStore = EditorProjectStore()) {
        self.store = store
        reloadRecentProjects()
    }

    func reloadRecentProjects() {
        do {
            recentProjects = try store.loadProjects()
            if let selectedProject,
               recentProjects.contains(where: { $0.path == selectedProject.path }) {
                self.selectedProject = recentProjects.first(where: { $0.path == selectedProject.path })
            } else {
                selectedProject = nil
            }
        } catch {
            setFailureStatus(prefix: "Failed to load recent projects", error: error)
        }
    }

    /// Opens the most recent project without performing potentially blocking filesystem I/O on the main actor.
    @discardableResult
    func openLastProjectIfAvailable() async -> Bool {
        guard !isOpeningLastProject else {
            return false
        }

        reloadRecentProjects()
        guard let lastProject = recentProjects.first else {
            clearValidationDiagnostics()
            statusMessage = "Select a recent Ada project, create a blank one, or open an existing project."
            return false
        }

        isOpeningLastProject = true
        defer { isOpeningLastProject = false }
        let selectedPathBeforeOpening = selectedProject?.path
        let storageURL = store.storageURL
        let adaEnginePackageURL = store.adaEnginePackageURL

        // Foundation does not provide asynchronous file reads here. Keep the blocking project validation
        // and manifest update off the UI actor so unavailable or cloud-backed paths cannot freeze the window.
        let result = await Task.detached(priority: .userInitiated) {
            let backgroundStore = EditorProjectStore(
                storageURL: storageURL,
                fileManager: FileManager(),
                adaEnginePackageURL: adaEnginePackageURL
            )
            guard backgroundStore.fileManager.fileExists(atPath: lastProject.path) else {
                return BackgroundProjectOpenResult.unavailable
            }

            do {
                let openedProject = try backgroundStore.openProject(
                    at: URL(fileURLWithPath: lastProject.path, isDirectory: true)
                )
                return .opened(openedProject)
            } catch let error as ProjectSystemError {
                return .projectFailure(error)
            } catch {
                return .failure(error.localizedDescription)
            }
        }.value

        guard selectedProject?.path == selectedPathBeforeOpening, projectToOpenInEditor == nil else {
            return false
        }

        return applyBackgroundProjectOpenResult(result, lastProject: lastProject)
    }

    private func applyBackgroundProjectOpenResult(
        _ result: BackgroundProjectOpenResult,
        lastProject: EditorProjectReference
    ) -> Bool {
        switch result {
        case let .opened(openedProject):
            isCreatingNewProject = false
            selectedProject = openedProject
            clearValidationDiagnostics()
            statusMessage = "Opened project: \(openedProject.path)"
            reloadRecentProjects()
            projectToOpenInEditor = openedProject
            projectToOpenInEditorToken += 1
            return true
        case .unavailable:
            selectedProject = nil
            clearValidationDiagnostics()
            statusMessage = "Last project is no longer available: \(lastProject.path)"
        case let .projectFailure(error):
            selectedProject = nil
            setFailureStatus(prefix: "Failed to open project", error: error)
        case let .failure(message):
            selectedProject = nil
            clearValidationDiagnostics()
            statusMessage = "Failed to open project: \(message)"
        }
        return false
    }

    func selectProject(_ reference: EditorProjectReference) {
        isCreatingNewProject = false
        selectedProject = reference
        existingProjectPath = reference.path
        clearValidationDiagnostics()
        statusMessage = "Ready to open \(reference.name)."
    }

    func createProject(openInEditor: Bool = false) {
        guard canCreateProject else {
            clearValidationDiagnostics()
            statusMessage = "Choose a project name and location before creating."
            return
        }

        do {
            let createdProject = try store.createProject(
                named: projectName,
                at: URL(fileURLWithPath: projectLocation, isDirectory: true),
                template: selectedTemplate
            )
            isCreatingNewProject = false
            selectedProject = createdProject
            clearValidationDiagnostics()
            statusMessage = "Created project: \(createdProject.path)"
            reloadRecentProjects()
            if openInEditor {
                projectToOpenInEditor = createdProject
                projectToOpenInEditorToken += 1
            }
        } catch {
            setFailureStatus(prefix: "Failed to create project", error: error)
        }
    }

    func openProject() {
        openProject(atPath: existingProjectPath, openInEditor: true)
    }

    func openProject(at url: URL) {
        existingProjectPath = url.path
        openProject(atPath: url.path, openInEditor: true)
    }

    func openSelectedProject() {
        guard let project = detailProject else {
            statusMessage = "Select a project first."
            return
        }
        openProject(atPath: project.path, openInEditor: true)
    }

    func openRecentProject(_ reference: EditorProjectReference) {
        selectProject(reference)
        openProject(atPath: reference.path, openInEditor: true)
    }

    func beginCreateNewProject(
        template: EditorProjectTemplate? = nil,
        suggestedName: String? = nil
    ) {
        selectedProject = nil
        if let template {
            selectedTemplate = template
        }
        if let suggestedName {
            projectName = suggestedName
        }
        isCreatingNewProject = true
        clearValidationDiagnostics()
        statusMessage = "Choose a name and location for the new Ada project."
    }

    func setProjectLocation(_ url: URL) {
        projectLocation = url.standardizedFileURL.path
        statusMessage = "Project location: \(projectLocationDisplayText)"
    }

    func createBlankTemplateProject() {
        if projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            projectName = "BlankAdaProject"
        }
        createProject(openInEditor: true)
    }

    func selectSection(_ section: ProjectOpeningSection) {
        selectedSection = section
        isCreatingNewProject = false
        selectedProject = nil
        clearValidationDiagnostics()
        statusMessage = "Browse \(section.title.lowercased())."
    }

    func abbreviatedPath(for project: EditorProjectReference) -> String {
        Self.abbreviatedPath(project.path)
    }

    func engineVersion(for project: EditorProjectReference?) -> String {
        guard let project else {
            return "Ada SwiftPM"
        }
        let metadataURL = ProjectSystem.metadataURL(forProjectAt: URL(fileURLWithPath: project.path, isDirectory: true))
        guard let data = try? Data(contentsOf: metadataURL),
              let adaProject = try? ProjectSystem.loadProject(from: data)
        else {
            return "Ada SwiftPM"
        }
        return adaProject.engine.minimumVersion.map { "Ada \($0)" } ?? "Ada SwiftPM"
    }

    func lastOpenedText(for project: EditorProjectReference?) -> String {
        guard let project else {
            return "Never"
        }
        return Self.relativeDateFormatter.localizedString(for: project.lastOpenedAt, relativeTo: Date())
    }

    func consumeProjectToOpenInEditor() -> EditorProjectReference? {
        defer { projectToOpenInEditor = nil }
        return projectToOpenInEditor
    }

    private func openProject(atPath path: String, openInEditor: Bool = false) {
        do {
            isCreatingNewProject = false
            selectedProject = try store.openProject(at: URL(fileURLWithPath: path, isDirectory: true))
            clearValidationDiagnostics()
            statusMessage = "Opened project: \(selectedProject?.path ?? "")"
            reloadRecentProjects()
            if openInEditor, let selectedProject {
                projectToOpenInEditor = selectedProject
                projectToOpenInEditorToken += 1
            }
        } catch {
            selectedProject = nil
            setFailureStatus(prefix: "Failed to open project", error: error)
        }
    }

    private func setFailureStatus(prefix: String, error: Error) {
        if let projectError = error as? ProjectSystemError {
            let diagnostic = ProjectOpeningDiagnostic(error: projectError)
            validationDiagnostics = [diagnostic]
            statusMessage = "\(prefix): \(projectError.message) \(projectError.recoverySuggestion)"
        } else {
            validationDiagnostics = []
            statusMessage = "\(prefix): \(error.localizedDescription)"
        }
    }

    private func clearValidationDiagnostics() {
        validationDiagnostics = []
    }

    static func abbreviatedPath(_ path: String) -> String {
        let homePath = NSHomeDirectory()
        if path == homePath {
            return "~"
        }
        if path.hasPrefix(homePath + "/") {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

extension ProjectOpeningViewModel {
    func applyProjectLocationPickerResult(_ result: ProjectLocationPickerResult) {
        switch result {
        case .selected(let url):
            setProjectLocation(url)
        case .cancelled:
            statusMessage = "Project location selection cancelled."
        case .unavailable(let message):
            statusMessage = "Could not choose a project location: \(message)"
        }
    }
}

private enum BackgroundProjectOpenResult: Sendable {
    case opened(EditorProjectReference)
    case unavailable
    case projectFailure(ProjectSystemError)
    case failure(String)
}
