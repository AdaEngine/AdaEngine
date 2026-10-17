#if os(Linux)
import Foundation

/// Zenity uses the desktop's GTK file chooser without linking GTK into the engine.
@MainActor
enum LinuxProjectFilePicker {
    static func folder(title: String) async -> ProjectLocationPickerResult {
        switch await select(title: title, options: ["--directory"]) {
        case let .selected(urls): urls.first.map(ProjectLocationPickerResult.selected) ?? .cancelled
        case .cancelled: .cancelled
        case let .unavailable(message): .unavailable(message)
        }
    }

    static func files(
        title: String,
        extensions: [String] = [],
        allowsMultipleSelection: Bool = true,
        directory: URL? = nil
    ) async -> AssetFilePickerResult {
        var options: [String] = []
        if allowsMultipleSelection { options += ["--multiple", "--separator=\u{1F}"] }
        if let directory { options += ["--filename=\(directory.path)/"] }
        if !extensions.isEmpty { options += ["--file-filter=\(extensions.map { "*.\($0)" }.joined(separator: " "))"] }
        return await select(title: title, options: options)
    }

    private static func select(title: String, options: [String]) async -> AssetFilePickerResult {
        guard let executable = executable(named: "zenity") else {
            return .unavailable(L10n.text("Install Zenity to use Linux file dialogs."))
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--file-selection", "--title=\(title)"] + options
        // A temporary output file avoids pipe backpressure for large selections.
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("ada-picker-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: output.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: output) else {
            return .cancelled
        }
        defer {
            try? handle.close()
            try? FileManager.default.removeItem(at: output)
        }
        process.standardOutput = handle
        process.standardError = FileHandle.nullDevice
        let status: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch { continuation.resume(returning: -1) }
        }
        guard status == 0 else {
            return status == 1 ? .cancelled : .unavailable(L10n.text("The Linux file dialog could not be opened."))
        }
        guard var selection = try? String(contentsOf: output, encoding: .utf8) else {
            return .cancelled
        }
        if selection.hasSuffix("\n") { selection.removeLast() }
        let urls = selection.split(separator: "\u{1F}", omittingEmptySubsequences: true).map { URL(fileURLWithPath: String($0)) }
        return urls.isEmpty ? .cancelled : .selected(urls)
    }

    static func executable(named name: String) -> URL? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
        return path.split(separator: ":").map { URL(fileURLWithPath: String($0)).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
#endif
