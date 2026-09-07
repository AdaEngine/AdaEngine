@_spi(AdaEngine) import AdaEngine
import AdaPackageManifestTool
import Foundation
import Observation

@Observable
@MainActor
final class EditorFooterViewModel {
    var leftItems: [String]
    var rightItems: [String]

    init(leftItems: [String] = [], rightItems: [String] = []) {
        self.leftItems = leftItems
        self.rightItems = rightItems
    }

    func setSourceControlFooterTitle(_ title: String?) {
        var items = rightItems.filter { !$0.hasPrefix("Git:") }
        if let title {
            items.append(title)
        }
        rightItems = items
    }

    func setWorkspaceFooterTitle(_ title: String) {
        var items = leftItems.filter { !$0.hasPrefix("Workspace:") }
        items.append(title.hasPrefix("Workspace:") ? title : "Workspace: \(title)")
        leftItems = items
    }
}

@Observable
@MainActor
final class EditorSourceControlViewModel {
    var showsHistory = false
    var showsRepositoryActions = false
    var commits: [GitCommit] = []
    var historyHead: String?
    var hasMoreHistory = false
    var isLoadingHistory = false
    var isRefreshing = false
    var historyError: String?
    var commandError: String?
    var documents: [String: EditorGitDocument] = [:]
    @ObservationIgnored var historyGeneration = UUID()
    @ObservationIgnored var refreshGeneration = UUID()
    @ObservationIgnored var historyTask: Task<Void, Never>?
    @ObservationIgnored var refreshTask: Task<Void, Never>?

    var snapshot: GitRepositorySnapshot
    var commitMessage: String
    var newBranchName: String
    var statusMessage: String
    var isRunning: Bool {
        didSet {
            for document in documents.values { document.isRunningCommand = isRunning }
        }
    }

    init(
        snapshot: GitRepositorySnapshot = .empty,
        commitMessage: String = "",
        newBranchName: String = "",
        statusMessage: String = "Source Control is not loaded.",
        isRunning: Bool = false
    ) {
        self.snapshot = snapshot
        self.commitMessage = commitMessage
        self.newBranchName = newBranchName
        self.statusMessage = statusMessage
        self.isRunning = isRunning
    }

    var commitMessageBinding: Binding<String> {
        Binding(get: { self.commitMessage }, set: { self.commitMessage = $0 })
    }

    var newBranchNameBinding: Binding<String> {
        Binding(get: { self.newBranchName }, set: { self.newBranchName = $0 })
    }

    var trimmedCommitMessage: String {
        commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNewBranchName: String {
        newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canCommit: Bool {
        !isRunning && !trimmedCommitMessage.isEmpty && !snapshot.stagedFiles.isEmpty
    }

    var canCreateBranch: Bool {
        !isRunning && !trimmedNewBranchName.isEmpty && snapshot.rootURL != nil
    }

    var hasChanges: Bool {
        snapshot.hasChanges
    }
}
