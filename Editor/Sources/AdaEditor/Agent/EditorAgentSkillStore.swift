import Foundation

enum EditorAgentSkillStore {
    static func discoverSkills(projectURL: URL, directories: [String], fileManager: FileManager = .default) -> [EditorAgentSkill] {
        directories.flatMap { directory in
            discoverSkills(in: projectURL.appendingPathComponent(directory, isDirectory: true), fileManager: fileManager)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func discoverSkills(in rootURL: URL, fileManager: FileManager = .default) -> [EditorAgentSkill] {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return []
        }

        var skillFiles: [URL] = []
        if rootURL.lastPathComponent == "SKILL.md" {
            skillFiles = [rootURL]
        } else if let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator where url.lastPathComponent == "SKILL.md" {
                skillFiles.append(url)
            }
        }

        return skillFiles.compactMap { skillFile in
            guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else {
                return nil
            }
            return parseSkill(content: content, skillFileURL: skillFile)
        }
    }

    static func parseSkill(content: String, skillFileURL: URL) -> EditorAgentSkill {
        let metadata = parseFrontMatter(content)
        let directoryName = skillFileURL.deletingLastPathComponent().lastPathComponent
        let name = metadata["name"]?.nilIfEmpty ?? directoryName
        let id = metadata["id"]?.nilIfEmpty ?? name
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_.-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return EditorAgentSkill(
            id: id.isEmpty ? directoryName : id,
            name: name,
            description: metadata["description"]?.nilIfEmpty,
            localPath: skillFileURL.path,
            userInvocable: metadata["user_invocable"].map { $0 != "false" } ?? true,
            allowedTools: metadata["allowed_tools"]?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? [],
            instructions: content
        )
    }

    private static func parseFrontMatter(_ content: String) -> [String: String] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.first == "---" else {
            return [:]
        }

        var result: [String: String] = [:]
        for line in lines.dropFirst() {
            guard line != "---" else {
                break
            }
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                continue
            }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            result[key] = value
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

