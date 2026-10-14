import Foundation

enum EditorHostTools {
    static func environmentValue(_ name: String, in environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        #if os(Windows)
        return environment.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        #else
        return environment[name]
        #endif
    }
    static func isAbsolutePath(_ path: String) -> Bool {
        if path.hasPrefix("/") || path.hasPrefix("\\\\") { return true }
        let bytes = Array(path.utf8.prefix(3))
        return bytes.count == 3 && bytes[1] == 58 && (bytes[2] == 47 || bytes[2] == 92)
            && ((65...90).contains(bytes[0]) || (97...122).contains(bytes[0]))
    }
    static func executable(_ name: String, windowsName: String? = nil) -> String {
        #if os(Windows)
        let filename = windowsName ?? (name.lowercased().hasSuffix(".exe") ? name : name + ".exe")
        let separator: Character = ";"
        #else
        let filename = name
        let separator: Character = ":"
        #endif
        for component in (environmentValue("PATH") ?? "").split(separator: separator) {
            let candidate = URL(fileURLWithPath: String(component)).appendingPathComponent(filename).path
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return filename
    }
}
