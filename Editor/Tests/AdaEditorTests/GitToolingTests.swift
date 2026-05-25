@testable import AdaEditor
import Foundation
import Testing

@Suite("Git source control tooling")
struct GitToolingTests {
    @Test("Git status parser extracts branch tracking and changed files")
    func statusParserExtractsChanges() throws {
        let snapshot = GitRepositorySnapshot.parseStatus(from: """
        ## feature/source-control...origin/feature/source-control [ahead 1, behind 2]
        M  Sources/App.swift
         M Sources/View.swift
        MM Sources/Editor.swift
        R  Sources/Old.swift -> Sources/New.swift
        ?? Assets/Icon.png
        """)

        #expect(snapshot.branchName == "feature/source-control")
        #expect(snapshot.upstreamName == "origin/feature/source-control")
        #expect(snapshot.aheadCount == 1)
        #expect(snapshot.behindCount == 2)
        #expect(snapshot.stagedFiles.map(\.path) == ["Sources/App.swift", "Sources/Editor.swift", "Sources/New.swift"])
        #expect(snapshot.changedFiles.map(\.path) == ["Sources/View.swift", "Sources/Editor.swift"])
        #expect(snapshot.untrackedFiles.map(\.path) == ["Assets/Icon.png"])
        #expect(snapshot.files.first(where: { $0.path == "Sources/New.swift" })?.originalPath == "Sources/Old.swift")
    }

    @Test("Git branch parser extracts current branch and upstream")
    func branchParserExtractsCurrentAndUpstream() {
        let branches = GitRepositorySnapshot.parseBranches(from: """
        \tmain\torigin/main
        *\tfeature/source-control\torigin/feature/source-control
        \trelease\t
        """)

        #expect(branches.map(\.name) == ["main", "feature/source-control", "release"])
        #expect(branches.first(where: \.isCurrent)?.name == "feature/source-control")
        #expect(branches[0].upstream == "origin/main")
        #expect(branches[2].upstream == nil)
    }

    @Test("Git service constructs expected commands")
    func gitCommandConstruction() {
        let service = GitRepositoryService(processRunner: GitFakeProcessRunner(results: []))
        let projectURL = URL(fileURLWithPath: "/tmp/Game", isDirectory: true)

        #expect(service.makeCommand(.status, projectURL: projectURL).arguments == ["git", "status", "--porcelain=v1", "-b"])
        #expect(service.makeCommand(.branches, projectURL: projectURL).arguments == ["git", "branch", "--format=%(HEAD)%09%(refname:short)%09%(upstream:short)"])
        #expect(service.makeCommand(.stage(paths: ["Sources/App.swift"]), projectURL: projectURL).arguments == ["git", "add", "--", "Sources/App.swift"])
        #expect(service.makeCommand(.stage(paths: []), projectURL: projectURL).arguments == ["git", "add", "-A"])
        #expect(service.makeCommand(.unstage(paths: ["Sources/App.swift"]), projectURL: projectURL).arguments == ["git", "restore", "--staged", "--", "Sources/App.swift"])
        #expect(service.makeCommand(.unstage(paths: []), projectURL: projectURL).arguments == ["git", "restore", "--staged", "--", "."])
        #expect(service.makeCommand(.stash(message: "AdaEditor stash"), projectURL: projectURL).arguments == ["git", "stash", "push", "-u", "-m", "AdaEditor stash"])
        #expect(service.makeCommand(.commit(message: "Initial"), projectURL: projectURL).arguments == ["git", "commit", "-m", "Initial"])
        #expect(service.makeCommand(.pull, projectURL: projectURL).arguments == ["git", "pull"])
        #expect(service.makeCommand(.push, projectURL: projectURL).arguments == ["git", "push"])
        #expect(service.makeCommand(.checkout(branch: "main"), projectURL: projectURL).arguments == ["git", "checkout", "main"])
        #expect(service.makeCommand(.createBranch(name: "feature"), projectURL: projectURL).arguments == ["git", "checkout", "-b", "feature"])
    }

    @Test("Editor view model refreshes source control snapshot")
    @MainActor
    func viewModelRefreshesSourceControlSnapshot() async throws {
        let projectURL = URL(fileURLWithPath: "/tmp/Game", isDirectory: true)
        let project = EditorProjectReference(name: "Game", path: projectURL.path, lastOpenedAt: Date())
        let service = GitFakeRepositoryService(
            loadResult: GitRepositoryLoadResult(
                snapshot: GitRepositorySnapshot.parseStatus(from: """
                ## main...origin/main
                 M Sources/App.swift
                """),
                statusResult: GitFakeRepositoryService.result(.status, projectURL: projectURL, output: "## main\n"),
                branchResult: nil
            )
        )
        let viewModel = EditorViewModel(project: project, sourceControlService: service)

        viewModel.refreshSourceControl()
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.sourceControl.snapshot.branchName == "main")
        #expect(viewModel.sourceControl.snapshot.changedFiles.map(\.path) == ["Sources/App.swift"])
        #expect(viewModel.footer.rightItems.contains("Git: main*"))
    }

    @Test("Editor startup runs workspace and source control bootstrap once")
    @MainActor
    func editorStartupRunsBootstrapOnce() async throws {
        let projectURL = URL(fileURLWithPath: "/tmp/Game", isDirectory: true)
        let project = EditorProjectReference(name: "Game", path: projectURL.path, lastOpenedAt: Date())
        let workspaceService = EditorStartupFakeWorkspaceService()
        let sourceControlService = GitFakeRepositoryService(
            loadResult: GitRepositoryLoadResult(
                snapshot: GitRepositorySnapshot.parseStatus(from: "## main\n"),
                statusResult: GitFakeRepositoryService.result(.status, projectURL: projectURL, output: "## main\n"),
                branchResult: nil
            )
        )
        let viewModel = EditorViewModel(
            project: project,
            workspaceService: workspaceService,
            sourceControlService: sourceControlService
        )

        viewModel.startEditorSessionIfNeeded()
        viewModel.startEditorSessionIfNeeded()
        try await Task.sleep(for: .milliseconds(50))

        #expect(await workspaceService.bootstrapCallCount == 1)
        #expect(await sourceControlService.snapshotCallCount == 1)
    }
}

private actor GitFakeProcessRunner: EditorProcessRunning {
    private var results: [EditorProcessResult]

    init(results: [EditorProcessResult]) {
        self.results = results
    }

    func run(_ command: EditorProcessCommand) async -> EditorProcessResult {
        if !results.isEmpty {
            return results.removeFirst()
        }
        return EditorProcessResult(command: command, exitCode: 0, standardOutput: "", standardError: "")
    }

    func cancelAll() {}
}

private actor GitFakeRepositoryService: GitRepositoryServicing {
    var loadResult: GitRepositoryLoadResult
    var executeResults: [EditorProcessResult]
    private(set) var snapshotCallCount = 0

    init(loadResult: GitRepositoryLoadResult, executeResults: [EditorProcessResult] = []) {
        self.loadResult = loadResult
        self.executeResults = executeResults
    }

    nonisolated func makeCommand(_ kind: GitCommandKind, projectURL: URL) -> EditorProcessCommand {
        GitRepositoryService().makeCommand(kind, projectURL: projectURL)
    }

    func snapshot(projectURL: URL) async -> GitRepositoryLoadResult {
        snapshotCallCount += 1
        return loadResult
    }

    func execute(_ kind: GitCommandKind, projectURL: URL) async -> EditorProcessResult {
        if !executeResults.isEmpty {
            return executeResults.removeFirst()
        }
        return Self.result(kind, projectURL: projectURL)
    }

    static func result(_ kind: GitCommandKind, projectURL: URL, output: String = "") -> EditorProcessResult {
        let command = GitRepositoryService().makeCommand(kind, projectURL: projectURL)
        return EditorProcessResult(command: command, exitCode: 0, standardOutput: output, standardError: "")
    }
}

private actor EditorStartupFakeWorkspaceService: SwiftPMWorkspaceServicing {
    private(set) var bootstrapCallCount = 0

    nonisolated func makeCommand(_ kind: SwiftPMCommandKind, projectURL: URL, toolchain: SwiftToolchain) -> EditorProcessCommand {
        SwiftPMWorkspaceService().makeCommand(kind, projectURL: projectURL, toolchain: toolchain)
    }

    func bootstrap(projectURL: URL) async -> SwiftPMBootstrapResult {
        bootstrapCallCount += 1
        let toolchain = SwiftToolchain(swiftExecutablePath: "swift", sourceKitLSPExecutablePath: nil)
        return SwiftPMBootstrapResult(
            toolchain: toolchain,
            resolveResult: Self.result(.resolve, projectURL: projectURL, toolchain: toolchain),
            packageModel: nil,
            describeResult: Self.result(.describe, projectURL: projectURL, toolchain: toolchain),
            indexBuildResult: nil,
            diagnostics: []
        )
    }

    func execute(_ kind: SwiftPMCommandKind, projectURL: URL) async -> EditorProcessResult {
        Self.result(kind, projectURL: projectURL)
    }

    func semanticTokens(fileURL: URL, language: EditorSourceLanguage, text: String) async -> [EditorSemanticToken] {
        []
    }

    func definition(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorSourceSymbolTarget] {
        []
    }

    func references(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorSourceReference] {
        []
    }

    func hover(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> EditorSymbolHover? {
        nil
    }

    func documentHighlights(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorDocumentHighlight] {
        []
    }

    func cancel() {}

    static func result(
        _ kind: SwiftPMCommandKind,
        projectURL: URL,
        toolchain: SwiftToolchain = SwiftToolchain(swiftExecutablePath: "swift", sourceKitLSPExecutablePath: nil)
    ) -> EditorProcessResult {
        let command = SwiftPMWorkspaceService().makeCommand(kind, projectURL: projectURL, toolchain: toolchain)
        return EditorProcessResult(command: command, exitCode: 0, standardOutput: "", standardError: "")
    }
}
