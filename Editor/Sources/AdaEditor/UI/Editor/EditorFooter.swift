@_spi(AdaEngine) import AdaEngine
import Foundation

enum EditorActivityKind: Equatable, Sendable {
    case build
    case indexing
    case preview
    case run
    case sourceControl
    case test
    case workspace
}

struct EditorActivityEvent: Equatable, Sendable, Identifiable {
    let id: String
    let kind: EditorActivityKind
    let title: String
    let detail: String?
    let fractionCompleted: Float?

    init(
        id: String,
        kind: EditorActivityKind,
        title: String,
        detail: String? = nil,
        fractionCompleted: Float? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.fractionCompleted = fractionCompleted.map { min(max($0, 0), 1) }
    }

    var statusTitle: String {
        guard let fractionCompleted else {
            return title
        }
        return "\(title) · \(Int((fractionCompleted * 100).rounded()))%"
    }
}

@MainActor
enum EditorActivityPresentation {
    static func events(
        workspaceStatus: EditorWorkspaceStatus,
        previewStatus: EditorPreviewStatus,
        sourceControlIsRunning: Bool,
        sourceControlTitle: String
    ) -> [EditorActivityEvent] {
        var events = workspaceEvent(for: workspaceStatus).map { [$0] } ?? []

        if case .building(let declaration, let message) = previewStatus {
            events.append(
                EditorActivityEvent(
                    id: "preview",
                    kind: .preview,
                    title: "Building preview \(declaration.title)",
                    detail: message
                )
            )
        }

        if sourceControlIsRunning {
            events.append(
                EditorActivityEvent(
                    id: "source-control",
                    kind: .sourceControl,
                    title: sourceControlTitle
                )
            )
        }

        return events
    }

    private static func workspaceEvent(for status: EditorWorkspaceStatus) -> EditorActivityEvent? {
        switch status {
        case .resolving:
            return EditorActivityEvent(
                id: "workspace",
                kind: .workspace,
                title: "Resolving SwiftPM dependencies"
            )
        case .indexing:
            return EditorActivityEvent(
                id: "workspace",
                kind: .indexing,
                title: "Indexing Swift package"
            )
        case .preparing(let progress):
            guard progress.phase != .ready, progress.phase != .failed else {
                return nil
            }
            let fractionCompleted: Float? = if let completed = progress.completedFileCount,
                                               let total = progress.totalFileCount,
                                               total > 0 {
                Float(completed) / Float(total)
            } else {
                nil
            }
            return EditorActivityEvent(
                id: "workspace",
                kind: progress.phase == .indexingBuild ? .indexing : .workspace,
                title: progress.title,
                detail: progress.currentTarget ?? progress.currentFile ?? progress.detail,
                fractionCompleted: fractionCompleted
            )
        case .running(let title):
            return EditorActivityEvent(
                id: "workspace-command",
                kind: commandKind(for: title),
                title: title
            )
        case .cancelled, .failed, .idle, .ready:
            return nil
        }
    }

    private static func commandKind(for title: String) -> EditorActivityKind {
        let normalizedTitle = title.lowercased()
        if normalizedTitle.hasPrefix("build") {
            return .build
        }
        if normalizedTitle.hasPrefix("test") {
            return .test
        }
        if normalizedTitle.hasPrefix("run") || normalizedTitle.hasPrefix("play") {
            return .run
        }
        return .workspace
    }
}

struct EditorFooter: View {
    let hotReloadState: EditorHotReloadState
    let viewModel: EditorFooterViewModel
    let activities: [EditorActivityEvent]
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 14) {
            ForEach(viewModel.leftItems(hotReloadState: hotReloadState), id: \.self) {
                Text($0)
            }
            Spacer()
            if metrics.showsFooterRight {
                ForEach(viewModel.rightItems, id: \.self) {
                    Text($0)
                }
            }
            if let activity = activities.first {
                EditorActivityProgressView(
                    activity: activity,
                    additionalActivityCount: max(0, activities.count - 1),
                    width: metrics.size.width < 760 ? 132 : 220
                )
            }
        }
        .font(.system(size: 10))
        .foregroundColor(theme.editorColors.text)
        .padding(.horizontal, 10)
    }
}

private struct EditorActivityProgressView: View {
    let activity: EditorActivityEvent
    let additionalActivityCount: Int
    let width: Float

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(activity.statusTitle)
                    .lineLimit(1)
                if additionalActivityCount > 0 {
                    Text("+\(additionalActivityCount)")
                        .foregroundColor(theme.editorColors.blue)
                }
            }
            .frame(width: width, alignment: .trailing)

            EditorActivityProgressBar(
                fractionCompleted: activity.fractionCompleted,
                width: width
            )
        }
        .frame(width: width, height: 20, alignment: .bottomTrailing)
        .accessibilityIdentifier("AdaEditor.ActivityProgress")
    }
}

private struct EditorActivityProgressBar: View {
    let fractionCompleted: Float?
    let width: Float

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(anchor: .leading) {
            RoundedRectangleShape(cornerRadius: 1)
                .fill(theme.editorColors.border.opacity(0.55))
                .frame(width: width, height: 2)

            if let fractionCompleted {
                RoundedRectangleShape(cornerRadius: 1)
                    .fill(theme.editorColors.blue)
                    .frame(width: width * fractionCompleted, height: 2)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let phase = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2)
                    let segmentWidth = width * 0.32
                    RoundedRectangleShape(cornerRadius: 1)
                        .fill(theme.editorColors.blue)
                        .frame(width: segmentWidth, height: 2)
                        .offset(x: (width + segmentWidth) * phase - segmentWidth)
                }
                .frame(width: width, height: 2)
                .mask(RectangleShape())
            }
        }
        .frame(width: width, height: 2)
        .accessibilityIdentifier("AdaEditor.ActivityProgress.Bar")
    }
}
