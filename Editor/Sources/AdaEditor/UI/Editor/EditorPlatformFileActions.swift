import Foundation

#if canImport(AppKit)
    import AppKit
#elseif os(Linux)
    import AdaEngine
#elseif os(Windows)
    import AdaEngine
    import WinSDK
#endif

@MainActor
enum EditorPlatformFileActions {
    @discardableResult
    static func copyToClipboard(_ value: String) -> Bool {
        #if canImport(AppKit)
            NSPasteboard.general.clearContents()
            return NSPasteboard.general.setString(value, forType: .string)
        #elseif os(Windows)
            UIClipboard.setString(value)
            return UIClipboard.getString() == value
        #elseif os(Linux)
            UIClipboard.setString(value)
            return UIClipboard.getString() == value
        #else
            return false
        #endif
    }

    @discardableResult
    static func reveal(_ url: URL) -> Bool {
        #if canImport(AppKit)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return true
        #elseif os(Windows)
            guard url.isFileURL else { return false }
            return shellOpen("explorer.exe", arguments: "/select,\"\(url.path)\"")
        #elseif os(Linux)
            guard url.isFileURL else { return false }
            return linuxOpen("xdg-open", arguments: [(url.hasDirectoryPath ? url : url.deletingLastPathComponent()).path])
        #else
            return false
        #endif
    }

    @discardableResult
    static func openInDefaultApplication(_ url: URL) -> Bool {
        #if canImport(AppKit)
            return NSWorkspace.shared.open(url)
        #elseif os(Windows)
            return shellOpen(url.isFileURL ? url.path : url.absoluteString)
        #elseif os(Linux)
            return linuxOpen("xdg-open", arguments: [url.isFileURL ? url.path : url.absoluteString])
        #else
            return false
        #endif
    }

    @discardableResult
    static func openInTerminal(_ url: URL) -> Bool {
        #if os(macOS)
            let directoryURL = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open", isDirectory: false)
            process.arguments = ["-a", "Terminal", directoryURL.path]
            do {
                try process.run()
                return true
            } catch {
                return false
            }
        #elseif os(Windows)
            guard url.isFileURL else { return false }
            let directory = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
            return shellOpen("powershell.exe", arguments: "-NoExit", directory: directory.path)
        #elseif os(Linux)
            guard url.isFileURL else { return false }
            return linuxOpen("x-terminal-emulator", directory: url.hasDirectoryPath ? url : url.deletingLastPathComponent())
        #else
            return false
        #endif
    }

    #if os(Linux)
    private static func linuxOpen(_ name: String, arguments: [String] = [], directory: URL? = nil) -> Bool {
        guard let executable = LinuxProjectFilePicker.executable(named: name) else { return false }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }
    #endif

    #if os(Windows)
    private static func shellOpen(_ target: String, arguments: String? = nil, directory: String? = nil) -> Bool {
        target.withCString(encodedAs: UTF16.self) { target in
            (arguments ?? "").withCString(encodedAs: UTF16.self) { parameters in
                (directory ?? "").withCString(encodedAs: UTF16.self) { workingDirectory in
                    let result = ShellExecuteW(
                        GetForegroundWindow(), nil, target,
                        arguments == nil ? nil : parameters, directory == nil ? nil : workingDirectory, SW_SHOWNORMAL
                    )
                    return Int(bitPattern: result) > 32
                }
            }
        }
    }
    #endif
}
