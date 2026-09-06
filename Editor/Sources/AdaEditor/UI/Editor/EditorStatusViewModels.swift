@_spi(AdaEngine) import AdaEngine
import AdaPackageManifestTool
import Foundation
import Observation

@Observable
@MainActor
final class EditorFooterViewModel {
    var leftItems: [String]
    var rightItems: [String]

    init(leftItems: [String] = AdaEngineStyleContent.footerLeft, rightItems: [String] = AdaEngineStyleContent.footerRight) {
        self.leftItems = leftItems
        self.rightItems = rightItems
    }

    func leftItems(hotReloadState: EditorHotReloadState) -> [String] {
        leftItems + [hotReloadState.footerTitle]
    }

    func setSourceControlFooterTitle(_ title: String) {
        var items = rightItems.filter { !$0.hasPrefix("Git:") }
        items.append(title)
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
    var snapshot: GitRepositorySnapshot
    var commitMessage: String
    var newBranchName: String
    var statusMessage: String
    var isRunning: Bool

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
        !isRunning && !trimmedNewBranchName.isEmpty
    }

    var hasChanges: Bool {
        snapshot.hasChanges
    }
}
