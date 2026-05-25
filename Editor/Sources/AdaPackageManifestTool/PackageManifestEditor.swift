import Foundation
import SwiftParser

public struct PackageManifestEditResult: Equatable, Sendable {
    public var manifest: String
    public var changed: Bool

    public init(manifest: String, changed: Bool) {
        self.manifest = manifest
        self.changed = changed
    }
}

public enum PackageManifestEditError: Error, Equatable, Sendable {
    case invalidSwiftSyntax
    case unsupportedManifestShape(reason: String, suggestedPatch: String)
    case invalidArgument(String)

    public var structuredDescription: String {
        switch self {
        case .invalidSwiftSyntax:
            #"{"error":"invalidSwiftSyntax","reason":"Package.swift could not be parsed as Swift."}"#
        case .unsupportedManifestShape(let reason, let suggestedPatch):
            #"{"error":"unsupportedManifestShape","reason":"\#(Self.escape(reason))","suggestedPatch":"\#(Self.escape(suggestedPatch))"}"#
        case .invalidArgument(let message):
            #"{"error":"invalidArgument","reason":"\#(Self.escape(message))"}"#
        }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

public enum PackageManifestCommand: Equatable, Sendable {
    case addTarget(name: String, dependencies: [String])
    case addExecutableTarget(name: String, dependencies: [String])
    case addTestTarget(name: String, dependencies: [String])
    case addDependency(url: String, requirement: String)
    case addPlugin(name: String, capability: String)
    case ensureAssetResources(targetName: String?, assetsPath: String)
}

public enum PackageManifestEditor {
    public static func edit(_ manifest: String, command: PackageManifestCommand) throws -> PackageManifestEditResult {
        _ = Parser.parse(source: manifest)

        switch command {
        case .addTarget(let name, let dependencies):
            return try insertTarget(manifest, entry: targetEntry(kind: "target", name: name, dependencies: dependencies))
        case .addExecutableTarget(let name, let dependencies):
            let withProduct = try insertProduct(manifest, entry: productEntry(kind: "executable", name: name))
            return try insertTarget(withProduct.manifest, entry: targetEntry(kind: "executableTarget", name: name, dependencies: dependencies))
        case .addTestTarget(let name, let dependencies):
            return try insertTarget(manifest, entry: targetEntry(kind: "testTarget", name: name, dependencies: dependencies))
        case .addDependency(let url, let requirement):
            return try insertDependency(manifest, entry: dependencyEntry(url: url, requirement: requirement))
        case .addPlugin(let name, let capability):
            let withProduct = try insertProduct(manifest, entry: pluginProductEntry(name: name))
            return try insertTarget(withProduct.manifest, entry: pluginTargetEntry(name: name, capability: capability))
        case .ensureAssetResources(let targetName, let assetsPath):
            return try ensureAssetResources(manifest, targetName: targetName, assetsPath: assetsPath)
        }
    }

    private static func ensureAssetResources(_ manifest: String, targetName: String?, assetsPath: String) throws -> PackageManifestEditResult {
        let targets = executableTargetRanges(in: manifest)
        let selectedTargets: [(range: Range<String.Index>, body: Substring, name: String?)]
        if let targetName {
            selectedTargets = targets.filter { $0.name == targetName }
        } else {
            selectedTargets = targets
        }

        guard selectedTargets.count == 1, let target = selectedTargets.first else {
            throw PackageManifestEditError.unsupportedManifestShape(
                reason: "Could not uniquely identify an executable target for Assets resources.",
                suggestedPatch: #"resources: [.copy("\#(assetsPath)")]"#
            )
        }

        let editedBody = try targetBodyByEnsuringResource(in: String(target.body), targetName: target.name, assetsPath: assetsPath)
        guard editedBody != String(target.body) else {
            return PackageManifestEditResult(manifest: manifest, changed: false)
        }

        var editedManifest = manifest
        editedManifest.replaceSubrange(target.range, with: editedBody)
        return PackageManifestEditResult(manifest: editedManifest, changed: true)
    }

    private static func executableTargetRanges(in manifest: String) -> [(range: Range<String.Index>, body: Substring, name: String?)] {
        var results: [(Range<String.Index>, Substring, String?)] = []
        var searchRange = manifest.startIndex..<manifest.endIndex

        while let start = manifest.range(of: ".executableTarget(", range: searchRange)?.lowerBound {
            guard let openParen = manifest[start...].firstIndex(of: "("),
                  let closeParen = closingDelimiterIndex(open: "(", close: ")", start: openParen, in: manifest)
            else {
                break
            }

            let end = manifest.index(after: closeParen)
            let range = start..<end
            let body = manifest[range]
            results.append((range, body, targetName(in: body)))
            searchRange = end..<manifest.endIndex
        }

        return results
    }

    private static func targetName(in body: Substring) -> String? {
        guard let range = body.range(of: #"name:\s*"([^"]+)""#, options: .regularExpression) else {
            return nil
        }

        let match = body[range]
        guard let firstQuote = match.firstIndex(of: "\""),
              let lastQuote = match.lastIndex(of: "\""),
              firstQuote != lastQuote
        else {
            return nil
        }

        return String(match[match.index(after: firstQuote)..<lastQuote])
    }

    private static func targetBodyByEnsuringResource(in body: String, targetName: String?, assetsPath: String) throws -> String {
        let resourceEntry = #".copy("\#(assetsPath)")"#
        let needsPackageRootPath = !body.contains("path:")
        let needsSources = needsPackageRootPath && !body.contains("sources:")
        let sourceEntry = targetName.map { #"sources: ["Sources/\#($0)"]"# }

        if body.contains(resourceEntry), !needsPackageRootPath, !needsSources {
            return body
        }

        var editedBody = body
        if needsPackageRootPath {
            editedBody = try targetBodyByAppendingArgument(#"path: ".""#, to: editedBody)
        }
        if needsSources, let sourceEntry {
            editedBody = try targetBodyByAppendingArgument(sourceEntry, to: editedBody)
        }

        if editedBody.contains(resourceEntry) {
            return editedBody
        }

        if let resourcesLabel = editedBody.range(of: "resources:"),
           let openBracket = editedBody[resourcesLabel.upperBound...].firstIndex(of: "["),
           let closeBracket = closingDelimiterIndex(open: "[", close: "]", start: openBracket, in: editedBody) {
            let prefix = editedBody[..<closeBracket]
            let suffix = editedBody[closeBracket...]
            let needsComma = prefix.last(where: { !$0.isWhitespace }).map { $0 != "[" && $0 != "," } ?? false
            let separator = needsComma ? ", " : ""
            return String(prefix) + separator + resourceEntry + String(suffix)
        }

        return try targetBodyByAppendingArgument("resources: [\(resourceEntry)]", to: editedBody)
    }

    private static func targetBodyByAppendingArgument(_ argument: String, to body: String) throws -> String {
        guard let closeParen = body.lastIndex(of: ")") else {
            throw PackageManifestEditError.invalidSwiftSyntax
        }

        let prefix = body[..<closeParen]
        let suffix = body[closeParen...]
        let hasNewline = body.contains("\n")
        if hasNewline {
            let indentation = indentationBeforeClosingBracket(at: closeParen, in: body) + "    "
            let separator = prefix.last(where: { !$0.isWhitespace }).map { $0 == "," ? "" : "," } ?? ""
            return String(prefix) + "\(separator)\n\(indentation)\(argument)\n" + String(suffix)
        }

        let separator = prefix.last(where: { !$0.isWhitespace }).map { $0 == "(" ? "" : ", " } ?? ""
        return String(prefix) + "\(separator)\(argument)" + String(suffix)
    }

    private static func insertProduct(_ manifest: String, entry: String) throws -> PackageManifestEditResult {
        try insert(entry: entry, intoArrayNamed: "products", manifest: manifest)
    }

    private static func insertDependency(_ manifest: String, entry: String) throws -> PackageManifestEditResult {
        try insert(entry: entry, intoArrayNamed: "dependencies", manifest: manifest)
    }

    private static func insertTarget(_ manifest: String, entry: String) throws -> PackageManifestEditResult {
        try insert(entry: entry, intoArrayNamed: "targets", manifest: manifest)
    }

    private static func insert(entry: String, intoArrayNamed arrayName: String, manifest: String) throws -> PackageManifestEditResult {
        guard !manifest.contains(entry) else {
            return PackageManifestEditResult(manifest: manifest, changed: false)
        }

        guard let insertionIndex = closingBracketIndex(forArrayNamed: arrayName, in: manifest) else {
            throw PackageManifestEditError.unsupportedManifestShape(
                reason: "Could not find a static \(arrayName): [...] array in Package.swift.",
                suggestedPatch: entry
            )
        }

        let prefix = manifest[..<insertionIndex]
        let suffix = manifest[insertionIndex...]
        let needsComma = prefix.last(where: { !$0.isWhitespace }).map { $0 != "[" && $0 != "," } ?? false
        let separator = needsComma ? "," : ""
        let indentation = indentationBeforeClosingBracket(at: insertionIndex, in: manifest) + "    "
        let inserted = "\(separator)\n\(indentation)\(entry)\n"

        return PackageManifestEditResult(
            manifest: String(prefix) + inserted + String(suffix),
            changed: true
        )
    }

    private static func closingBracketIndex(forArrayNamed name: String, in manifest: String) -> String.Index? {
        guard let labelRange = manifest.range(of: "\n    \(name):"),
              let openBracket = manifest[labelRange.upperBound...].firstIndex(of: "[")
        else {
            return nil
        }

        var depth = 0
        var index = openBracket
        while index < manifest.endIndex {
            let character = manifest[index]
            if character == "[" {
                depth += 1
            } else if character == "]" {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
            index = manifest.index(after: index)
        }

        return nil
    }

    private static func closingDelimiterIndex(open: Character, close: Character, start: String.Index, in text: String) -> String.Index? {
        var depth = 0
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
            index = text.index(after: index)
        }

        return nil
    }

    private static func indentationBeforeClosingBracket(at index: String.Index, in manifest: String) -> String {
        let lineStart = manifest[..<index].lastIndex(of: "\n").map { manifest.index(after: $0) } ?? manifest.startIndex
        return String(manifest[lineStart..<index].prefix { $0 == " " || $0 == "\t" })
    }

    private static func productEntry(kind: String, name: String) -> String {
        ".\(kind)(name: \"\(name)\", targets: [\"\(name)\"])"
    }

    private static func pluginProductEntry(name: String) -> String {
        ".plugin(name: \"\(name)\", targets: [\"\(name)\"])"
    }

    private static func dependencyEntry(url: String, requirement: String) -> String {
        ".package(url: \"\(url)\", \(requirement))"
    }

    private static func targetEntry(kind: String, name: String, dependencies: [String]) -> String {
        let dependencyList = dependencies.map { "\"\($0)\"" }.joined(separator: ", ")
        return ".\(kind)(name: \"\(name)\", dependencies: [\(dependencyList)])"
    }

    private static func pluginTargetEntry(name: String, capability: String) -> String {
        ".plugin(name: \"\(name)\", capability: \(capability), dependencies: [])"
    }
}
