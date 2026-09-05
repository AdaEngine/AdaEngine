//
//  ProjectOpenPicker.swift
//  AdaEngine
//

import Foundation

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

enum ProjectLocationPickerResult: Equatable, Sendable {
    case selected(URL)
    case cancelled
    case unavailable(String)
}

enum ProjectOpenPicker {
    static let title = "Open Ada Project"
    static let prompt = "Open Project"
    static let message = "Choose an Ada project directory or a SwiftPM Package.swift manifest."
    static let allowedFileNames = ["Package.swift"]
    static let projectLocationTitle = "Choose Project Location"
    static let projectLocationPrompt = "Choose"
    static let projectLocationMessage = "Choose the parent folder where AdaEditor should create the new project directory."
    static let assetImportTitle = "Import Assets"
    static let assetImportPrompt = "Import"
    static let assetImportMessage = "Choose asset files to copy into the project's Assets directory."

    @MainActor
    static func presentProjectPicker(completion: @escaping @MainActor (URL?) -> Void) {
        #if canImport(AppKit)
        completion(pickProjectURL())
        #elseif canImport(UIKit)
        guard let presenter = activeViewController() else {
            completion(nil)
            return
        }
        let projectType = UTType("org.adaengine.project") ?? .folder
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [projectType, .folder],
            asCopy: false
        )
        let delegate = ProjectDocumentPickerDelegate(completion: completion)
        activeProjectPickerDelegate = delegate
        picker.delegate = delegate
        picker.allowsMultipleSelection = false
        presenter.present(picker, animated: true)
        #else
        completion(nil)
        #endif
    }

    @MainActor
    static func pickProjectURL() -> URL? {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.message = message
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = []
        } else {
            panel.allowedFileTypes = nil
        }

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return nil
        }

        return projectDirectoryURL(fromPickerSelection: selectedURL)
        #else
        return nil
        #endif
    }

    @MainActor
    static func presentProjectLocationPicker(
        completion: @escaping @MainActor (ProjectLocationPickerResult) -> Void
    ) {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.title = projectLocationTitle
        panel.prompt = projectLocationPrompt
        panel.message = projectLocationMessage
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else {
            completion(.cancelled)
            return
        }
        guard let selectedURL = panel.url else {
            completion(.unavailable("The system picker did not return a selected folder."))
            return
        }
        completion(.selected(projectLocationURL(fromPickerSelection: selectedURL)))
        #elseif canImport(UIKit)
        guard let presenter = activeViewController() else {
            completion(.unavailable("AdaEditor has no active window from which to open Files."))
            return
        }
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder],
            asCopy: false
        )
        let delegate = ProjectLocationDocumentPickerDelegate(completion: completion)
        activeProjectLocationPickerDelegate = delegate
        picker.delegate = delegate
        picker.allowsMultipleSelection = false
        presenter.present(picker, animated: true)
        #else
        completion(.unavailable("Folder selection is not supported on this platform."))
        #endif
    }

    @MainActor
    static func pickAssetImportURLs() -> [URL]? {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.title = assetImportTitle
        panel.prompt = assetImportPrompt
        panel.message = assetImportMessage
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.urls
        #else
        return nil
        #endif
    }

    static func projectDirectoryURL(fromPickerSelection selectedURL: URL) -> URL {
        if selectedURL.lastPathComponent == "Package.swift" {
            return selectedURL.deletingLastPathComponent().standardizedFileURL
        }

        if (try? selectedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return selectedURL.standardizedFileURL
        }

        return selectedURL.deletingLastPathComponent().standardizedFileURL
    }

    static func projectLocationURL(fromPickerSelection selectedURL: URL) -> URL {
        if (try? selectedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return selectedURL.standardizedFileURL
        }

        return selectedURL.deletingLastPathComponent().standardizedFileURL
    }

    #if canImport(UIKit)
    @MainActor
    private static var activeProjectPickerDelegate: ProjectDocumentPickerDelegate?
    @MainActor
    private static var activeProjectLocationPickerDelegate: ProjectLocationDocumentPickerDelegate?
    @MainActor
    private static var securityScopedAccesses: [String: SecurityScopedURLAccess] = [:]

    @MainActor
    private static func activeViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var current = root
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }

    @MainActor
    private final class ProjectDocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
        private let completion: @MainActor (URL?) -> Void

        init(completion: @escaping @MainActor (URL?) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            finish(with: urls.first.map {
                retainSecurityScopedAccess(to: projectDirectoryURL(fromPickerSelection: $0))
            })
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            finish(with: nil)
        }

        private func finish(with url: URL?) {
            completion(url)
            activeProjectPickerDelegate = nil
        }
    }

    @MainActor
    private final class ProjectLocationDocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
        private let completion: @MainActor (ProjectLocationPickerResult) -> Void

        init(completion: @escaping @MainActor (ProjectLocationPickerResult) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedURL = urls.first else {
                finish(with: .unavailable("Files did not return a selected folder."))
                return
            }
            let locationURL = projectLocationURL(fromPickerSelection: selectedURL)
            finish(with: .selected(retainSecurityScopedAccess(to: locationURL)))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            finish(with: .cancelled)
        }

        private func finish(with result: ProjectLocationPickerResult) {
            completion(result)
            activeProjectLocationPickerDelegate = nil
        }
    }

    @MainActor
    static func retainSecurityScopedAccess(to url: URL) -> URL {
        let standardizedURL = url.standardizedFileURL
        let key = standardizedURL.path
        if securityScopedAccesses[key] == nil {
            securityScopedAccesses[key] = SecurityScopedURLAccess(url: standardizedURL)
        }
        return standardizedURL
    }

    private final class SecurityScopedURLAccess {
        private let isAccessing: Bool
        private let url: URL

        init(url: URL) {
            self.url = url
            self.isAccessing = url.startAccessingSecurityScopedResource()
        }

        deinit {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
    #endif
}
