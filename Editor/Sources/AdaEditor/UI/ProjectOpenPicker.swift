//
//  ProjectOpenPicker.swift
//  AdaEngine
//

import Foundation

#if canImport(AppKit)
import AppKit
#endif

enum ProjectOpenPicker {
    static let title = "Open Ada Project"
    static let prompt = "Open Project"
    static let message = "Choose a SwiftPM package directory or its Package.swift manifest."
    static let allowedFileNames = ["Package.swift"]
    static let projectLocationTitle = "Choose Project Location"
    static let projectLocationPrompt = "Choose"
    static let projectLocationMessage = "Choose the parent folder where AdaEditor should create the new project directory."
    static let assetImportTitle = "Import Assets"
    static let assetImportPrompt = "Import"
    static let assetImportMessage = "Choose asset files to copy into the project's Assets directory."

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
    static func pickProjectLocationURL() -> URL? {
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

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return nil
        }

        return projectLocationURL(fromPickerSelection: selectedURL)
        #else
        return nil
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
}
