#if os(Windows)
import Foundation
@_spi(Internal) import AdaPlatform
import WinSDK

@MainActor
enum WindowsProjectFilePicker {
    static func folder(title: String) async -> ProjectLocationPickerResult {
        await WindowsNativeDialogs.present { owner in folder(title: title, owner: owner) }
    }

    nonisolated private static func folder(title: String, owner: HWND?) -> ProjectLocationPickerResult {
        let initialization = CoInitializeEx(nil, DWORD(COINIT_APARTMENTTHREADED.rawValue))
        defer { if initialization >= 0 { CoUninitialize() } }
        var displayName = [WCHAR](repeating: 0, count: Int(MAX_PATH))
        let titleCharacters = Array(title.utf16) + [0]
        let selected = titleCharacters.withUnsafeBufferPointer { titleBuffer in
            displayName.withUnsafeMutableBufferPointer { displayBuffer in
                var info = BROWSEINFOW()
                info.hwndOwner = owner
                info.pszDisplayName = displayBuffer.baseAddress
                info.lpszTitle = titleBuffer.baseAddress
                info.ulFlags = UINT(BIF_RETURNONLYFSDIRS | BIF_EDITBOX)
                if initialization >= 0 { info.ulFlags |= UINT(BIF_NEWDIALOGSTYLE) }
                return SHBrowseForFolderW(&info)
            }
        }
        guard let selected else { return .cancelled }
        defer { CoTaskMemFree(selected) }
        var path = [WCHAR](repeating: 0, count: 32_768)
        guard SHGetPathFromIDListEx(selected, &path, DWORD(path.count), 0) else {
            return .unavailable("Windows could not read the selected folder path.")
        }
        let length = path.firstIndex(of: 0) ?? path.endIndex
        return .selected(URL(fileURLWithPath: String(decoding: path[..<length], as: UTF16.self), isDirectory: true))
    }

    static func files(
        title: String,
        extensions: [String] = [],
        allowsMultipleSelection: Bool = true,
        directory: URL? = nil
    ) async -> AssetFilePickerResult {
        await WindowsNativeDialogs.present { owner in
            files(title: title, extensions: extensions, allowsMultipleSelection: allowsMultipleSelection, directory: directory, owner: owner)
        }
    }

    nonisolated private static func files(
        title: String, extensions: [String], allowsMultipleSelection: Bool, directory: URL?, owner: HWND?
    ) -> AssetFilePickerResult {
        var filenames = [WCHAR](repeating: 0, count: 32_768)
        let pattern = extensions.isEmpty ? "*.*" : extensions.map { "*.\($0)" }.joined(separator: ";")
        let filter = Array("Files\0\(pattern)\0\0".utf16)
        let titleCharacters = Array(title.utf16) + [0]
        let directoryCharacters = Array((directory?.path ?? "").utf16) + [0]
        let accepted = filenames.withUnsafeMutableBufferPointer { fileBuffer in
            filter.withUnsafeBufferPointer { filterBuffer in
                titleCharacters.withUnsafeBufferPointer { titleBuffer in
                    directoryCharacters.withUnsafeBufferPointer { directoryBuffer in
                        var dialog = OPENFILENAMEW()
                        dialog.lStructSize = DWORD(MemoryLayout<OPENFILENAMEW>.size)
                        dialog.hwndOwner = owner
                        dialog.lpstrTitle = titleBuffer.baseAddress
                        dialog.lpstrFilter = filterBuffer.baseAddress
                        dialog.lpstrFile = fileBuffer.baseAddress
                        dialog.nMaxFile = DWORD(fileBuffer.count)
                        dialog.lpstrInitialDir = directory == nil ? nil : directoryBuffer.baseAddress
                        dialog.Flags = DWORD(OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR)
                        if allowsMultipleSelection { dialog.Flags |= DWORD(OFN_ALLOWMULTISELECT) }
                        return GetOpenFileNameW(&dialog)
                    }
                }
            }
        }
        guard accepted else {
            let error = CommDlgExtendedError()
            return error == 0 ? .cancelled : .unavailable("Windows file selection failed (\(error)).")
        }
        return .selected(urls(from: filenames))
    }

    /// Explorer returns either a full path, or a directory followed by file names.
    nonisolated static func urls(from buffer: [WCHAR]) -> [URL] {
        var parts: [String] = []
        var start = 0
        for index in buffer.indices where buffer[index] == 0 {
            if index == start { break }
            parts.append(String(decoding: buffer[start..<index], as: UTF16.self))
            start = index + 1
        }
        guard let first = parts.first else { return [] }
        let root = URL(fileURLWithPath: first)
        return parts.count == 1 ? [root] : parts.dropFirst().map { root.appendingPathComponent($0) }
    }
}
#endif
