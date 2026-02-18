//
//  KanbanBoardExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 05.02.2026.
//

import AdaEngine

@main
struct KanbanBoardExample: App {
    var body: some AppScene {
        WindowGroup {
            KanbanBoardView()
//                ._debugDrawing(.drawViewOverlays)
        }
        .windowMode(.windowed)
    }
}

struct KanbanBoardView: View {

    @State private var tasks: [TaskItem] = TaskItem.sample

    var body: some View {
        let _ = Self._printChanges()

        ZStack {
            BoardPalette.background

            VStack(alignment: .leading, spacing: 16) {
                BoardHeaderView(totalCount: tasks.count, onAdd: addTask)

                Divider()

                ScrollView([.vertical, .horizontal]) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            KanbanColumnView(
                                status: status,
                                tasks: tasks.filter { $0.status == status },
                                onMoveLeft: { move($0, direction: -1) },
                                onMoveRight: { move($0, direction: 1) }
                            )
                            .frame(width: 260)
                        }
                    }
                    .padding(16)
                }
            }
            .padding(16)
        }
    }

    private func addTask() {
        let template = TaskItem.Template.examples.randomElement() ?? TaskItem.Template(
            title: "New Task",
            detail: "Describe the work to be done",
            tag: "General"
        )

        let newTask = TaskItem(
            title: template.title,
            detail: template.detail,
            status: .backlog,
            tag: template.tag
        )

        tasks.insert(newTask, at: 0)
    }

    private func move(_ task: TaskItem, direction: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }

        let currentStatus = tasks[index].status
        let newStatus = currentStatus.shifted(by: direction)

        guard newStatus != currentStatus else {
            return
        }

        tasks[index].status = newStatus
    }
}

struct BoardHeaderView: View {
    let totalCount: Int
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Kanban Board")
                    .fontSize(22)

                Text("Minimal demo with stateful cards")
                    .fontSize(12)
                    .foregroundColor(BoardPalette.textSecondary)
            }

            Spacer()

            Text("Tasks: \(totalCount)")
                .fontSize(12)
                .foregroundColor(BoardPalette.textSecondary)

            Button(action: onAdd) {
                Text("New Task")
                    .fontSize(12)
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                    .background(BoardPalette.primary)
                    .border(BoardPalette.primaryDark)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
    }
}

struct KanbanColumnView: View {
    let status: TaskStatus
    let tasks: [TaskItem]
    let onMoveLeft: (TaskItem) -> Void
    let onMoveRight: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                StatusBadgeView(text: status.title, color: status.color)

                Spacer()

                Text("\(tasks.count)")
                    .fontSize(12)
                    .foregroundColor(BoardPalette.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(tasks) { task in
                    TaskCardView(
                        task: task,
                        canMoveLeft: status.canMoveLeft,
                        canMoveRight: status.canMoveRight,
                        onMoveLeft: { onMoveLeft(task) },
                        onMoveRight: { onMoveRight(task) }
                    )
                    .accessibilityIdentifier("task list \(task.tag ?? task.title)")
                }
            }

            Spacer(minLength: 4)
        }
        .padding(12)
        .background(BoardPalette.columnBackground)
        .border(BoardPalette.columnBorder)
    }
}

struct TaskCardView: View {
    let task: TaskItem
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Text(task.title)
                    .fontSize(14)

                Spacer()

                if let tag = task.tag {
                    TagView(text: tag, color: task.status.color)
                }
            }

            Text(task.detail)
                .fontSize(11)
                .foregroundColor(BoardPalette.textSecondary)

            HStack(alignment: .center, spacing: 6) {
                if canMoveLeft {
                    MiniButton(title: "<", action: onMoveLeft)
                        .accessibilityIdentifier(task.title + "<")
                }

                Spacer()

                if canMoveRight {
                    MiniButton(title: ">", action: onMoveRight)
                        .accessibilityIdentifier(task.title + ">")
                }
            }
        }
        .padding(10)
        .background(BoardPalette.cardBackground)
        .border(BoardPalette.cardBorder)
        .overlay {
            Canvas { context, size in
                let stripeWidth: Float = 3
                let rect = Rect(origin: .zero, size: Size(width: stripeWidth, height: size.height))
                context.drawRect(rect, color: task.status.color)
            }
        }
    }
}

struct StatusBadgeView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .fontSize(11)
            .foregroundColor(color)
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .background(color.opacity(0.12))
            .border(color.opacity(0.4))
    }
}

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .fontSize(10)
            .foregroundColor(color)
            .padding(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
            .background(color.opacity(0.12))
            .border(color.opacity(0.35))
    }
}

struct MiniButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontSize(12)
                .foregroundColor(BoardPalette.textPrimary)
                .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .background(BoardPalette.buttonBackground)
                .border(BoardPalette.buttonBorder)
        }
    }
}

struct TaskItem: Identifiable {
    let id: UUID = UUID()
    let title: String
    let detail: String
    var status: TaskStatus
    let tag: String?
}

extension TaskItem {
    struct Template {
        let title: String
        let detail: String
        let tag: String

        static let examples: [Template] = [
            Template(title: "Design empty states", detail: "Create lightweight placeholders", tag: "Design"),
            Template(title: "Sync API changes", detail: "Align UI fields with backend", tag: "Backend"),
            Template(title: "Animation pass", detail: "Add subtle transitions", tag: "Motion"),
            Template(title: "Review typography", detail: "Audit headings and body", tag: "UI"),
            Template(title: "Optimize layout", detail: "Reduce nested stacks", tag: "Perf")
        ]
    }

    static let sample: [TaskItem] = [
        TaskItem(title: "Wireframe onboarding", detail: "Outline first session flow", status: .backlog, tag: "UX"),
        TaskItem(title: "Tokenize colors", detail: "Define palette tokens", status: .backlog, tag: "Design"),
        TaskItem(title: "Board layout", detail: "Implement column grid", status: .inProgress, tag: "UI"),
        TaskItem(title: "Task transitions", detail: "Move cards between states", status: .inProgress, tag: "Logic"),
        TaskItem(title: "Notifications", detail: "Decide on alerts", status: .review, tag: "Product"),
        TaskItem(title: "Release checklist", detail: "Finalize demo scope", status: .done, tag: "PM")
    ]
}

enum TaskStatus: Int, CaseIterable {
    case backlog
    case inProgress
    case review
    case done

    var title: String {
        switch self {
        case .backlog:
            return "Backlog"
        case .inProgress:
            return "In Progress"
        case .review:
            return "Review"
        case .done:
            return "Done"
        }
    }

    var color: Color {
        switch self {
        case .backlog:
            return BoardPalette.backlog
        case .inProgress:
            return BoardPalette.inProgress
        case .review:
            return BoardPalette.review
        case .done:
            return BoardPalette.done
        }
    }

    var canMoveLeft: Bool {
        self != TaskStatus.allCases.first
    }

    var canMoveRight: Bool {
        self != TaskStatus.allCases.last
    }

    func shifted(by direction: Int) -> TaskStatus {
        let statuses = TaskStatus.allCases
        guard let index = statuses.firstIndex(of: self) else {
            return self
        }

        let newIndex = max(0, min(statuses.count - 1, index + direction))
        return statuses[newIndex]
    }
}

enum BoardPalette {
    static let background = Color.fromHex(0xF4F6FA)
    static let columnBackground = Color.fromHex(0xFFFFFF)
    static let columnBorder = Color.fromHex(0xE1E5EC)
    static let cardBackground = Color.fromHex(0xFFFFFF)
    static let cardBorder = Color.fromHex(0xE6E9F0)
    static let buttonBackground = Color.fromHex(0xF0F3F8)
    static let buttonBorder = Color.fromHex(0xD6DBE5)
    static let textPrimary = Color.fromHex(0x1F2937)
    static let textSecondary = Color.fromHex(0x6B7280)
    static let primary = Color.fromHex(0x2563EB)
    static let primaryDark = Color.fromHex(0x1D4ED8)

    static let backlog = Color.fromHex(0x64748B)
    static let inProgress = Color.fromHex(0x2563EB)
    static let review = Color.fromHex(0x7C3AED)
    static let done = Color.fromHex(0x16A34A)
}
