//
//  ProjectOpeningViewModel.swift
//  AdaEngine
//

@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation

@Observable
@MainActor
final class ProjectOpeningViewModel {
    var recentProjects: [EditorProjectReference] = []
    var projectName: String = "AdaGame"
    var projectLocation: String = ""
    var isCreatingNewProject = false
    var existingProjectPath: String = ""
    var searchQuery: String = ""
    var selectedProject: EditorProjectReference?
    var statusMessage: String = "Select a recent SwiftPM Ada project, create a blank one, or open an existing package."
    var projectToOpenInEditor: EditorProjectReference?
    var projectToOpenInEditorToken = 0

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

    var hasValidProjectName: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var needsProjectLocation: Bool {
        projectLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canCreateProject: Bool {
        hasValidProjectName && !needsProjectLocation
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
            statusMessage = "Failed to load recent projects: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func openLastProjectIfAvailable() -> Bool {
        reloadRecentProjects()

        guard let lastProject = recentProjects.first else {
            statusMessage = "Select a recent SwiftPM Ada project, create a blank one, or open an existing package."
            return false
        }

        guard FileManager.default.fileExists(atPath: lastProject.path) else {
            selectedProject = nil
            statusMessage = "Last project is no longer available: \(lastProject.path)"
            return false
        }

        openProject(atPath: lastProject.path, openInEditor: true)
        return projectToOpenInEditor != nil
    }

    func selectProject(_ reference: EditorProjectReference) {
        isCreatingNewProject = false
        selectedProject = reference
        existingProjectPath = reference.path
        statusMessage = "Ready to open \(reference.name)."
    }

    func createProject(openInEditor: Bool = false) {
        guard canCreateProject else {
            statusMessage = "Choose a project name and location before creating."
            return
        }

        do {
            let createdProject = try store.createProject(
                named: projectName,
                at: URL(fileURLWithPath: projectLocation, isDirectory: true)
            )
            isCreatingNewProject = false
            selectedProject = createdProject
            statusMessage = "Created project: \(createdProject.path)"
            reloadRecentProjects()
            if openInEditor {
                projectToOpenInEditor = createdProject
                projectToOpenInEditorToken += 1
            }
        } catch {
            statusMessage = "Failed to create project: \(error.localizedDescription)"
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

    func beginCreateNewProject() {
        selectedProject = nil
        isCreatingNewProject = true
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
            statusMessage = "Opened project: \(selectedProject?.path ?? "")"
            reloadRecentProjects()
            if openInEditor, let selectedProject {
                projectToOpenInEditor = selectedProject
                projectToOpenInEditorToken += 1
            }
        } catch {
            statusMessage = "Failed to open project: \(error.localizedDescription)"
        }
    }

    static func abbreviatedPath(_ path: String) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
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
