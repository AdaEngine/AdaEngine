import Foundation

#if os(Windows)
    @unsafe import WinSDK
#endif

enum EditorAtomicFileWriter {
    static func write(_ data: Data, to destinationURL: URL) throws {
        #if os(Windows)
            let fileManager = FileManager.default
            let temporaryURL = destinationURL
                .deletingLastPathComponent()
                .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp")

            do {
                try data.write(to: temporaryURL)
                let moved = temporaryURL.path.withCString(encodedAs: UTF16.self) { sourcePath in
                    destinationURL.path.withCString(encodedAs: UTF16.self) { destinationPath in
                        unsafe MoveFileExW(
                            sourcePath,
                            destinationPath,
                            DWORD(MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)
                        )
                    }
                }
                guard moved else {
                    let errorCode = GetLastError()
                    throw NSError(
                        domain: "NSWin32ErrorDomain",
                        code: Int(errorCode),
                        userInfo: [
                            NSFilePathErrorKey: destinationURL.path,
                            NSLocalizedDescriptionKey: "Could not replace \(destinationURL.lastPathComponent) (Win32 error \(errorCode)).",
                        ]
                    )
                }
            } catch {
                try? fileManager.removeItem(at: temporaryURL)
                throw error
            }
        #else
            try data.write(to: destinationURL, options: .atomic)
        #endif
    }

    static func write(_ string: String, to destinationURL: URL, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try write(data, to: destinationURL)
    }
}
