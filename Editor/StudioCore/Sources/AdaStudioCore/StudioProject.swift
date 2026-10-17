import Foundation

public struct StudioFile: Codable, Equatable, Sendable, Identifiable {
    public var path: String
    public var data: Data
    public var id: String { path }
    public init(path: String, data: Data) { self.path = path; self.data = data }
    public init(path: String, text: String) { self.init(path: path, data: Data(text.utf8)) }
    public var text: String { String(decoding: data, as: UTF8.self) }
}

public struct StudioMessage: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var role: String
    public var content: String
    public var toolCalls: [StudioValue]?
    public var toolCallID: String?
    public var images: [String]?
    public init(role: String, content: String, toolCalls: [StudioValue]? = nil, toolCallID: String? = nil, images: [String]? = nil) {
        self.id = UUID().uuidString.lowercased(); self.role = role; self.content = content
        self.toolCalls = toolCalls; self.toolCallID = toolCallID
        self.images = images
    }
}

/// Working sources, never a compiled publication. Credentials are held outside this type.
public struct StudioSnapshot: Codable, Equatable, Sendable {
    public static let maximumBytes = 64 * 1024 * 1024
    public static let maximumFiles = 512
    public var formatVersion = 1
    public var title: String
    public var files: [StudioFile]
    public var messages: [StudioMessage]
    public init(title: String, files: [StudioFile], messages: [StudioMessage] = []) {
        self.title = title; self.files = files; self.messages = messages
    }
    public func file(_ path: String) -> StudioFile? { files.first { $0.path == path } }
    public var metadata: StudioValue { (try? file(".ada/project.json").map { try StudioValue.decode($0.data) }) ?? .null }
    public var scenePath: String { metadata["runtime"]["entry"]["scene"].string ?? "Assets/Scenes/Main.ascn" }
    public var sources: [StudioFile] { files.filter { $0.path.hasPrefix("Sources/") && $0.path.hasSuffix(".ada") }.sorted { $0.path < $1.path } }

    public func validate() throws {
        guard formatVersion == 1, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.utf8.count <= 240,
              !files.isEmpty, files.count <= Self.maximumFiles, messages.count <= 1000 else { throw StudioError.invalid("Некорректный проект Studio.") }
        var names = Set<String>(), bytes = 0
        for file in files {
            guard Self.validPath(file.path), names.insert(file.path.lowercased()).inserted,
                  file.data.count <= 16 * 1024 * 1024 else { throw StudioError.invalid("Недопустимый файл: \(file.path)") }
            if file.path.hasPrefix("Sources/"), file.data.count > 512 * 1024 { throw StudioError.invalid("Исходный файл превышает 512 КБ.") }
            bytes += file.data.count
            guard bytes <= Self.maximumBytes else { throw StudioError.invalid("Размер проекта превышает 64 МБ.") }
        }
        guard file(".ada/project.json")?.data.count ?? Int.max <= 256 * 1024,
              metadata["build"]["system"].string == "adascript", !sources.isEmpty,
              metadata["runtime"]["entry"]["view"] == .null, metadata["runtime"]["entry"]["scene"].string != nil, file(scenePath) != nil else {
            throw StudioError.invalid("Нужен AdaScript-проект со сценой и исходниками.")
        }
        guard [nil, "Sources"].contains(metadata["paths"]["sources"].string), [nil, "Assets"].contains(metadata["paths"]["assets"].string),
              metadata["paths"]["resourceRoots"].array.allSatisfy({ $0.string == "Assets" }) else { throw StudioError.invalid("Web Studio использует Sources и Assets внутри проекта.") }
        var chatBytes = 0
        for message in messages {
            guard ["user", "assistant", "tool"].contains(message.role), message.content.utf8.count <= 512 * 1024 else {
                throw StudioError.invalid("История чата слишком велика.")
            }
            guard (message.images?.count ?? 0) <= 4, (message.images ?? []).allSatisfy({ $0.hasPrefix("data:image/") && $0.utf8.count <= 512 * 1024 }) else { throw StudioError.invalid("Слишком большое изображение чата.") }
            chatBytes += try JSONEncoder().encode(message).count
            guard chatBytes <= 4 * 1024 * 1024 else { throw StudioError.invalid("История проекта превышает 4 МБ. Начните новый чат.") }
        }
    }

    public static func validPath(_ path: String) -> Bool {
        guard !path.isEmpty, path.utf8.count <= 512,
              path.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./-").contains($0) }),
              path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return false }
        if path == ".ada/project.json" { return true }
        if path.hasPrefix("Sources/") { return path.hasSuffix(".ada") }
        return path.hasPrefix("Assets/") && ["png", "jpg", "jpeg", "wav", "ogg", "ascn", "tilemap", "tileset", "json", "ui", "glb", "gltf", "bin"].contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }

    /// Export uses source paths and strips host-specific settings, never flattened player sources.
    public func exportFiles(newIdentity: Bool = false) throws -> [StudioFile] {
        try validate()
        var result = files
        guard let index = result.firstIndex(where: { $0.path == ".ada/project.json" }) else { throw StudioError.invalid("Нет метаданных проекта.") }
        var meta = metadata
        meta["ai"] = .object([:]); meta["editor"] = .object([:]); meta["run"] = .object([:])
        meta["paths"]["build"] = .null; meta["paths"]["generated"] = .null; meta["paths"]["run"] = .object([:])
        if newIdentity { meta["project"]["id"] = .string(UUID().uuidString.lowercased()) }
        result[index].data = try meta.encoded()
        return result.sorted { $0.path < $1.path }
    }

    public func importedCopy() throws -> Self {
        var copy = self
        copy.files = try exportFiles(newIdentity: true)
        copy.messages = []
        return copy
    }
}

public struct StudioWorkspace: Codable, Sendable, Identifiable {
    public var id: String
    public var revision: Int
    public var title: String
    public var updatedAt: Double
    public var snapshot: StudioSnapshot?
    public var pageID: String?
    public init(id: String, revision: Int, title: String, updatedAt: Double, snapshot: StudioSnapshot? = nil) {
        self.id = id; self.revision = revision; self.title = title; self.updatedAt = updatedAt; self.snapshot = snapshot; self.pageID = nil
    }
}

public struct StudioCheckpoint: Codable, Sendable, Identifiable {
    public var id: String { String(revision) }
    public var revision: Int
    public var title: String
    public var updatedAt: Double
}
