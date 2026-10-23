@_spi(AdaEngine) import AdaEngine
import Foundation

enum EditorAchievementFilter: String, CaseIterable {
    case all = "All"
    case earned = "Earned"
    case locked = "Not earned"
}

struct EditorAchievementSettings: View {
    var center: EditorAchievementCenter = .shared
    @State private var filter = EditorAchievementFilter.all
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("\(center.earnedCount) / \(EditorAchievement.catalog.count) achievements earned"))
                .font(.system(size: 20, weight: .semibold))
            Text(L10n.text("Explore AdaEditor, build your worlds, and discover a few secrets along the way."))
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.muted)
            Text(center.status)
                .font(.system(size: 12))
                .accessibilityIdentifier("AdaEditor.Achievements.Connection")
            if !center.isConnected {
                Text(center.snapshot.guestOwner == nil
                        ? L10n.text("Your local achievements will be added to the first Game Center account you connect.")
                        : L10n.text("Offline progress stays with its local profile. Achievements from different accounts are kept separate."))
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            }
            if let error = center.storageError {
                Text(error).font(.system(size: 12))
            }
            HStack(spacing: 12) {
                Button(center.isConnected ? L10n.text("Sync Game Center") : L10n.text("Connect Game Center")) {
                    if center.isConnected {
                        center.synchronize()
                    } else {
                        center.connect()
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.blue.opacity(0.18)))
                .disabled(center.isSyncing)
                .accessibilityIdentifier("AdaEditor.Achievements.Connect")
                if center.isConnected {
                    Button(L10n.text("Open Game Center")) { center.showGameCenter() }
                        .font(.system(size: 12))
                        .accessibilityIdentifier("AdaEditor.Achievements.OpenGameCenter")
                }
            }
            Button(center.notificationsEnabled ? L10n.text("Achievement notifications: On") : L10n.text("Achievement notifications: Off")) {
                center.setNotificationsEnabled(!center.notificationsEnabled)
            }
            .font(.system(size: 12))
            .accessibilityIdentifier("AdaEditor.Achievements.Notifications")
            HStack(spacing: 8) {
                ForEach(EditorAchievementFilter.allCases, id: \.rawValue) { item in
                    Button(L10n.tr(item.rawValue)) { filter = item }
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangleShape(cornerRadius: 5)
                                .fill(
                                    filter == item ? theme.editorColors.blue.opacity(0.18) : theme.editorColors.surface
                                )
                        )
                        .foregroundColor(filter == item ? theme.editorColors.blue : theme.editorColors.text)
                        .accessibilityIdentifier("AdaEditor.Achievements.Filter.\(item.rawValue)")
                }
            }
            ForEach(visibleAchievements) { achievement in row(achievement) }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("AdaEditor.Achievements")
    }

    private var visibleAchievements: [EditorAchievement] {
        EditorAchievement.catalog.filter {
            let earned = center.progress($0.id).earnedAt != nil
            return filter == .all || (filter == .earned ? earned : !earned)
        }
    }

    private func row(_ achievement: EditorAchievement) -> some View {
        let progress = center.progress(achievement.id)
        let hidden = achievement.secret && progress.earnedAt == nil
        return HStack(alignment: .top, spacing: 14) {
            Text(hidden ? "\u{E897}" : "\u{EA23}")
                .font(AdaEditorMaterialSymbolFont.font(size: 30))
                .foregroundColor(progress.earnedAt == nil ? theme.editorColors.muted : theme.editorColors.blue)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 5) {
                Text(hidden ? L10n.text("Secret achievement") : achievement.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(hidden ? L10n.text("Keep exploring to discover this achievement.") : achievement.detail)
                    .font(.system(size: 12))
                    .foregroundColor(theme.editorColors.muted)
                if let date = progress.earnedAt {
                    Text(L10n.text("Earned · \(date.formatted(date: .abbreviated, time: .omitted))"))
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.blue)
                } else if !hidden, achievement.goal > 1 {
                    Text("\(progress.value) / \(achievement.goal)")
                        .font(.system(size: 11))
                }
            }
            Spacer()
            if !hidden {
                Text(L10n.text("Points: \(achievement.points)")).font(.system(size: 11))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangleShape(cornerRadius: 8).fill(theme.editorColors.surface))
        // Use an opaque index for locked secrets so accessibility doesn't disclose their names.
        .accessibilityIdentifier("AdaEditor.Achievements.Row.\(EditorAchievement.catalog.firstIndex(where: { $0.id == achievement.id }) ?? 0)")
    }
}
