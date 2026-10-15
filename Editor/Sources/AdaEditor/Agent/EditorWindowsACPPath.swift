#if os(Windows)
import Foundation
import WinSDK

enum EditorWindowsACPPath {
    /// Resolve the existing ancestor through a native handle. This expands 8.3 names
    /// and junctions as well as symlinks, including when the final file is new.
    static func canonicalURL(_ url: URL) throws -> URL {
        var ancestor = url.standardizedFileURL
        var suffix: [String] = []
        while true {
            let path = Array(ancestor.path.utf16) + [0]
            let handle = CreateFileW(path, 0, DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE), nil,
                DWORD(OPEN_EXISTING), DWORD(FILE_FLAG_BACKUP_SEMANTICS), nil)
            if handle != INVALID_HANDLE_VALUE, let handle {
                defer { CloseHandle(handle) }
                let count = GetFinalPathNameByHandleW(handle, nil, 0, 0)
                guard count > 0 else { throw EditorAgentServiceError.pathOutsideProject(url.path) }
                var buffer = [WCHAR](repeating: 0, count: Int(count) + 1)
                let written = GetFinalPathNameByHandleW(handle, &buffer, DWORD(buffer.count), 0)
                guard written > 0, written < buffer.count else { throw EditorAgentServiceError.pathOutsideProject(url.path) }
                var resolved = String(decoding: buffer.prefix(Int(written)), as: UTF16.self)
                if resolved.hasPrefix("\\\\?\\UNC\\") { resolved = "\\\\" + resolved.dropFirst(8) }
                else if resolved.hasPrefix("\\\\?\\") { resolved = String(resolved.dropFirst(4)) }
                var result = URL(fileURLWithPath: resolved)
                for component in suffix.reversed() { result.appendPathComponent(component) }
                return result
            }
            let error = GetLastError()
            guard error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND else {
                throw EditorAgentServiceError.pathOutsideProject(url.path)
            }
            let parent = ancestor.deletingLastPathComponent()
            guard parent.path != ancestor.path else { throw EditorAgentServiceError.pathOutsideProject(url.path) }
            suffix.append(ancestor.lastPathComponent)
            ancestor = parent
        }
    }
}
#endif
