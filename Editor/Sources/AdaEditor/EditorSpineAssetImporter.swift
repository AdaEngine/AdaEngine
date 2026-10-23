import AdaSpine
import Foundation

/// Copies a skeleton, atlas and every atlas page into one collision-free project folder.
enum EditorSpineAssetImporter {
    static func accepts(_ source: URL) -> Bool {
        if EditorSpineResource.extensions.contains(source.pathExtension.lowercased()) { return true }
        guard source.pathExtension.lowercased() == "json", let data = try? Data(contentsOf: source),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let header = json["skeleton"] as? [String: Any], let version = header["spine"] as? String else { return false }
        return version.hasPrefix("4.2.")
    }

    static func copy(_ source: URL, to destination: URL, fileManager: FileManager = .default) throws -> URL {
        let root = source.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let expected = source.deletingPathExtension().appendingPathExtension("atlas")
        let atlas: URL
        if fileManager.fileExists(atPath: expected.path) { atlas = expected }
        else {
            let candidates = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.pathExtension == "atlas" }
            guard candidates.count == 1, let only = candidates.first else {
                throw SpineError.invalidData("Place the companion atlas beside the skeleton, with the same basename.")
            }
            atlas = only
        }
        let atlasText = try String(contentsOf: atlas, encoding: .utf8)
        let player = try SpineAnimationPlayer(skeleton: Data(contentsOf: source), atlas: atlasText,
                                              format: source.pathExtension.lowercased() == "skel" ? .binary : .json)
        var pages: [(String, URL)] = []
        for page in player.pageNames {
            let url = root.appendingPathComponent(page).resolvingSymlinksInPath().standardizedFileURL
            guard !page.hasPrefix("/"), !page.contains(":"), url.path.hasPrefix(root.path + "/"),
                  (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else {
                throw SpineError.invalidData("Atlas pages must be files inside the export directory: \(page)")
            }
            pages.append((page, url))
        }
        let basename = source.deletingPathExtension().lastPathComponent
        var target = destination.appendingPathComponent(basename, isDirectory: true)
        var suffix = 2
        while fileManager.fileExists(atPath: target.path) {
            target = destination.appendingPathComponent("\(basename)-\(suffix)", isDirectory: true)
            suffix += 1
        }
        let stage = destination.appendingPathComponent(".spine-import-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stage) }
        let name = source.pathExtension.lowercased() == "skel" ? "\(basename).skel" : "\(basename).spine"
        try fileManager.copyItem(at: source, to: stage.appendingPathComponent(name))
        try Data(atlasText.utf8).write(to: stage.appendingPathComponent("\(basename).atlas"))
        for (page, url) in pages {
            let output = stage.appendingPathComponent(page)
            try fileManager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: url, to: output)
        }
        try fileManager.moveItem(at: stage, to: target)
        return target.appendingPathComponent(name)
    }
}
