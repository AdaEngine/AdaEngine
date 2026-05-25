@preconcurrency import Foundation

struct EditorSourceLocation: Equatable, Hashable, Sendable {
    var line: Int
    var character: Int
}

struct EditorSourceRange: Equatable, Hashable, Sendable {
    var start: EditorSourceLocation
    var end: EditorSourceLocation
}

enum EditorDiagnosticSeverity: String, Equatable, Hashable, Sendable {
    case error
    case warning
    case information
    case hint
}

struct EditorDiagnostic: Equatable, Hashable, Sendable {
    var filePath: String
    var range: EditorSourceRange
    var severity: EditorDiagnosticSeverity
    var message: String
    var source: String

    static func diagnostics(from result: EditorProcessResult, projectURL: URL) -> [EditorDiagnostic] {
        parseBuildOutput(result.standardOutput, projectURL: projectURL)
            + parseStandardError(result.standardError, command: result.command, projectURL: projectURL, failed: !result.succeeded)
    }

    static func parseBuildOutput(_ output: String, projectURL: URL) -> [EditorDiagnostic] {
        output
            .components(separatedBy: .newlines)
            .compactMap { parseBuildDiagnosticLine($0, projectURL: projectURL) }
    }

    private static func parseStandardError(_ output: String, command: EditorProcessCommand, projectURL: URL, failed: Bool) -> [EditorDiagnostic] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> EditorDiagnostic? in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLine.isEmpty else {
                    return nil
                }

                if let diagnostic = parseBuildDiagnosticLine(trimmedLine, projectURL: projectURL) {
                    return diagnostic
                }

                return EditorDiagnostic(
                    filePath: projectURL.appendingPathComponent("Package.swift", isDirectory: false).path,
                    range: EditorSourceRange(
                        start: EditorSourceLocation(line: 0, character: 0),
                        end: EditorSourceLocation(line: 0, character: 1)
                    ),
                    severity: severity(forStandardErrorLine: trimmedLine, failed: failed),
                    message: trimmedLine,
                    source: command.displayName
                )
            }
    }

    private static func severity(forStandardErrorLine line: String, failed: Bool) -> EditorDiagnosticSeverity {
        let lowercasedLine = line.lowercased()
        if failed || lowercasedLine.contains("error:") {
            return .error
        }
        if lowercasedLine.contains("warning:") {
            return .warning
        }
        return .information
    }

    private static func parseBuildDiagnosticLine(_ line: String, projectURL: URL) -> EditorDiagnostic? {
        let parts = line.split(separator: ":", maxSplits: 4, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              let lineNumber = Int(parts[1]),
              let columnNumber = Int(parts[2])
        else {
            return nil
        }

        let severity: EditorDiagnosticSeverity = switch parts[3].trimmingCharacters(in: .whitespaces) {
        case "error":
            .error
        case "warning":
            .warning
        case "note":
            .information
        default:
            .hint
        }

        let rawPath = parts[0]
        let absolutePath = rawPath.hasPrefix("/") ? rawPath : projectURL.appendingPathComponent(rawPath).path
        let zeroBasedLine = max(0, lineNumber - 1)
        let zeroBasedColumn = max(0, columnNumber - 1)

        return EditorDiagnostic(
            filePath: absolutePath,
            range: EditorSourceRange(
                start: EditorSourceLocation(line: zeroBasedLine, character: zeroBasedColumn),
                end: EditorSourceLocation(line: zeroBasedLine, character: zeroBasedColumn + 1)
            ),
            severity: severity,
            message: parts[4].trimmingCharacters(in: .whitespaces),
            source: "swift"
        )
    }
}

struct EditorSourceSymbolTarget: Equatable, Hashable, Sendable {
    var uri: String
    var filePath: String
    var range: EditorSourceRange
    var selectionRange: EditorSourceRange
}

struct EditorSourceReference: Equatable, Hashable, Sendable {
    var uri: String
    var filePath: String
    var range: EditorSourceRange
}

struct EditorSymbolHover: Equatable, Sendable {
    var contents: String
    var range: EditorSourceRange?
}

enum EditorDocumentHighlightKind: String, Equatable, Sendable {
    case text
    case read
    case write
}

struct EditorDocumentHighlight: Equatable, Sendable {
    var range: EditorSourceRange
    var kind: EditorDocumentHighlightKind
}

struct EditorSemanticToken: Equatable, Hashable, Sendable {
    var line: Int
    var startCharacter: Int
    var length: Int
    var type: String
    var modifiers: [String]
}

struct SourceKitLSPDocumentIdentifier: Equatable, Hashable, Sendable {
    var uri: String

    init(fileURL: URL) {
        self.uri = fileURL.absoluteURL.absoluteString
    }
}

private extension EditorSourceLocation {
    var jsonRPCValue: JSONRPCValue {
        .object([
            "line": .int(line),
            "character": .int(character)
        ])
    }
}

protocol SourceKitLSPConnecting: Sendable {
    func start(executablePath: String, projectURL: URL) async throws
    func request(method: String, params: JSONRPCValue?) async throws -> JSONRPCValue?
    func notify(method: String, params: JSONRPCValue?) async throws
    func stop() async
}

actor SourceKitLSPClient {
    private let connection: any SourceKitLSPConnecting
    private var nextVersionByURI: [String: Int] = [:]
    private var openedURIs: Set<String> = []
    private(set) var diagnosticsByURI: [String: [EditorDiagnostic]] = [:]
    private(set) var semanticTokensByURI: [String: [EditorSemanticToken]] = [:]

    init(connection: any SourceKitLSPConnecting) {
        self.connection = connection
    }

    func start(toolchain: SwiftToolchain, projectURL: URL) async throws {
        guard let sourceKitLSPExecutablePath = toolchain.sourceKitLSPExecutablePath else {
            throw SourceKitLSPError.sourceKitLSPUnavailable
        }

        try await connection.start(executablePath: sourceKitLSPExecutablePath, projectURL: projectURL)
        _ = try await connection.request(
            method: "initialize",
            params: .object([
                "processId": .int(Int(ProcessInfo.processInfo.processIdentifier)),
                "rootUri": .string(projectURL.absoluteString),
                "capabilities": .object([
                    "textDocument": .object([
                        "semanticTokens": .object([
                            "dynamicRegistration": .bool(false),
                            "requests": .object([
                                "full": .bool(true),
                                "range": .bool(false)
                            ]),
                            "tokenTypes": .array(Self.semanticTokenTypes.map { .string($0) }),
                            "tokenModifiers": .array(Self.semanticTokenModifiers.map { .string($0) })
                        ])
                    ])
                ])
            ])
        )
        try await connection.notify(method: "initialized", params: .object([:]))
    }

    func openDocument(fileURL: URL, language: EditorSourceLanguage, text: String) async throws {
        let identifier = SourceKitLSPDocumentIdentifier(fileURL: fileURL)
        if openedURIs.contains(identifier.uri) {
            try await changeDocument(fileURL: fileURL, text: text)
            return
        }

        nextVersionByURI[identifier.uri] = 1
        openedURIs.insert(identifier.uri)

        try await connection.notify(
            method: "textDocument/didOpen",
            params: .object([
                "textDocument": .object([
                    "uri": .string(identifier.uri),
                    "languageId": .string(language.lspLanguageID),
                    "version": .int(1),
                    "text": .string(text)
                ])
            ])
        )
    }

    func changeDocument(fileURL: URL, text: String) async throws {
        let identifier = SourceKitLSPDocumentIdentifier(fileURL: fileURL)
        let version = (nextVersionByURI[identifier.uri] ?? 1) + 1
        nextVersionByURI[identifier.uri] = version

        try await connection.notify(
            method: "textDocument/didChange",
            params: .object([
                "textDocument": .object([
                    "uri": .string(identifier.uri),
                    "version": .int(version)
                ]),
                "contentChanges": .array([
                    .object(["text": .string(text)])
                ])
            ])
        )
    }

    func saveDocument(fileURL: URL) async throws {
        try await connection.notify(
            method: "textDocument/didSave",
            params: .object([
                "textDocument": .object([
                    "uri": .string(SourceKitLSPDocumentIdentifier(fileURL: fileURL).uri)
                ])
            ])
        )
    }

    func refreshSemanticTokens(fileURL: URL) async throws -> [EditorSemanticToken] {
        let uri = SourceKitLSPDocumentIdentifier(fileURL: fileURL).uri
        let response = try await connection.request(
            method: "textDocument/semanticTokens/full",
            params: .object([
                "textDocument": .object([
                    "uri": .string(uri)
                ])
            ])
        )
        let tokens = Self.decodeSemanticTokens(from: response, legend: Self.semanticTokenTypes, modifiersLegend: Self.semanticTokenModifiers)
        semanticTokensByURI[uri] = tokens
        return tokens
    }

    func definition(fileURL: URL, position: EditorSourceLocation) async throws -> [EditorSourceSymbolTarget] {
        let response = try await connection.request(
            method: "textDocument/definition",
            params: textDocumentPositionParams(fileURL: fileURL, position: position)
        )
        return Self.decodeDefinitionTargets(from: response)
    }

    func references(fileURL: URL, position: EditorSourceLocation, includeDeclaration: Bool = true) async throws -> [EditorSourceReference] {
        let uri = SourceKitLSPDocumentIdentifier(fileURL: fileURL).uri
        let response = try await connection.request(
            method: "textDocument/references",
            params: .object([
                "textDocument": .object(["uri": .string(uri)]),
                "position": position.jsonRPCValue,
                "context": .object(["includeDeclaration": .bool(includeDeclaration)])
            ])
        )
        return Self.decodeReferences(from: response)
    }

    func hover(fileURL: URL, position: EditorSourceLocation) async throws -> EditorSymbolHover? {
        let response = try await connection.request(
            method: "textDocument/hover",
            params: textDocumentPositionParams(fileURL: fileURL, position: position)
        )
        return Self.decodeHover(from: response)
    }

    func documentHighlights(fileURL: URL, position: EditorSourceLocation) async throws -> [EditorDocumentHighlight] {
        let response = try await connection.request(
            method: "textDocument/documentHighlight",
            params: textDocumentPositionParams(fileURL: fileURL, position: position)
        )
        return Self.decodeDocumentHighlights(from: response)
    }

    func stop() async {
        await connection.stop()
    }

    private func textDocumentPositionParams(fileURL: URL, position: EditorSourceLocation) -> JSONRPCValue {
        .object([
            "textDocument": .object([
                "uri": .string(SourceKitLSPDocumentIdentifier(fileURL: fileURL).uri)
            ]),
            "position": position.jsonRPCValue
        ])
    }

    static func decodeSemanticTokens(from response: JSONRPCValue?, legend: [String], modifiersLegend: [String]) -> [EditorSemanticToken] {
        guard case .object(let object)? = response,
              case .array(let values)? = object["data"]
        else {
            return []
        }

        let numbers = values.compactMap(\.intValue)
        guard numbers.count % 5 == 0 else {
            return []
        }

        var tokens: [EditorSemanticToken] = []
        var line = 0
        var character = 0

        for index in stride(from: 0, to: numbers.count, by: 5) {
            let deltaLine = numbers[index]
            let deltaStart = numbers[index + 1]
            let length = numbers[index + 2]
            let typeIndex = numbers[index + 3]
            let modifiersMask = numbers[index + 4]

            line += deltaLine
            character = deltaLine == 0 ? character + deltaStart : deltaStart

            let type = legend.indices.contains(typeIndex) ? legend[typeIndex] : "unknown"
            let modifiers = modifiersLegend.enumerated().compactMap { offset, modifier in
                (modifiersMask & (1 << offset)) == 0 ? nil : modifier
            }

            tokens.append(
                EditorSemanticToken(
                    line: line,
                    startCharacter: character,
                    length: length,
                    type: type,
                    modifiers: modifiers
                )
            )
        }

        return tokens
    }

    static func decodeDefinitionTargets(from response: JSONRPCValue?) -> [EditorSourceSymbolTarget] {
        switch response {
        case .object(let object)?:
            if let target = decodeLocationLink(object) ?? decodeLocation(object).map({ location in
                EditorSourceSymbolTarget(uri: location.uri, filePath: location.filePath, range: location.range, selectionRange: location.range)
            }) {
                return [target]
            }
            return []
        case .array(let values)?:
            return values.flatMap { value -> [EditorSourceSymbolTarget] in
                guard case .object(let object) = value else {
                    return []
                }
                if let link = decodeLocationLink(object) {
                    return [link]
                }
                if let location = decodeLocation(object) {
                    return [
                        EditorSourceSymbolTarget(
                            uri: location.uri,
                            filePath: location.filePath,
                            range: location.range,
                            selectionRange: location.range
                        )
                    ]
                }
                return []
            }
        default:
            return []
        }
    }

    static func decodeReferences(from response: JSONRPCValue?) -> [EditorSourceReference] {
        guard case .array(let values)? = response else {
            return []
        }

        return values.compactMap { value in
            guard case .object(let object) = value,
                  let location = decodeLocation(object)
            else {
                return nil
            }

            return EditorSourceReference(uri: location.uri, filePath: location.filePath, range: location.range)
        }
    }

    static func decodeHover(from response: JSONRPCValue?) -> EditorSymbolHover? {
        guard case .object(let object)? = response,
              let contents = object["contents"],
              let text = decodeMarkupContent(contents)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else {
            return nil
        }

        return EditorSymbolHover(contents: text, range: object["range"].flatMap(decodeRange))
    }

    static func decodeDocumentHighlights(from response: JSONRPCValue?) -> [EditorDocumentHighlight] {
        guard case .array(let values)? = response else {
            return []
        }

        return values.compactMap { value in
            guard case .object(let object) = value,
                  let rangeValue = object["range"],
                  let range = decodeRange(rangeValue)
            else {
                return nil
            }

            let kind: EditorDocumentHighlightKind = switch object["kind"]?.intValue {
            case 2:
                .read
            case 3:
                .write
            default:
                .text
            }

            return EditorDocumentHighlight(range: range, kind: kind)
        }
    }

    private static func decodeLocation(_ object: [String: JSONRPCValue]) -> (uri: String, filePath: String, range: EditorSourceRange)? {
        guard case .string(let uri)? = object["uri"],
              let rangeValue = object["range"],
              let range = decodeRange(rangeValue)
        else {
            return nil
        }

        return (uri, filePath(fromURI: uri), range)
    }

    private static func decodeLocationLink(_ object: [String: JSONRPCValue]) -> EditorSourceSymbolTarget? {
        guard case .string(let uri)? = object["targetUri"],
              let targetRangeValue = object["targetRange"],
              let targetSelectionRangeValue = object["targetSelectionRange"],
              let targetRange = decodeRange(targetRangeValue),
              let targetSelectionRange = decodeRange(targetSelectionRangeValue)
        else {
            return nil
        }

        return EditorSourceSymbolTarget(
            uri: uri,
            filePath: filePath(fromURI: uri),
            range: targetRange,
            selectionRange: targetSelectionRange
        )
    }

    private static func decodeRange(_ value: JSONRPCValue) -> EditorSourceRange? {
        guard case .object(let object) = value,
              let startValue = object["start"],
              let endValue = object["end"],
              let start = decodePosition(startValue),
              let end = decodePosition(endValue)
        else {
            return nil
        }

        return EditorSourceRange(start: start, end: end)
    }

    private static func decodePosition(_ value: JSONRPCValue) -> EditorSourceLocation? {
        guard case .object(let object) = value,
              let line = object["line"]?.intValue,
              let character = object["character"]?.intValue
        else {
            return nil
        }

        return EditorSourceLocation(line: line, character: character)
    }

    private static func decodeMarkupContent(_ value: JSONRPCValue) -> String? {
        switch value {
        case .string(let string):
            return string
        case .object(let object):
            if case .string(let value)? = object["value"] {
                return value
            }
            return nil
        case .array(let values):
            let parts = values.compactMap(decodeMarkupContent)
            return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
        default:
            return nil
        }
    }

    private static func filePath(fromURI uri: String) -> String {
        guard let url = URL(string: uri) else {
            return uri
        }

        return url.path.removingPercentEncoding ?? url.path
    }

    private static let semanticTokenTypes = [
        "namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter",
        "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword",
        "modifier", "comment", "string", "number", "regexp", "operator", "decorator"
    ]

    private static let semanticTokenModifiers = [
        "declaration", "definition", "readonly", "static", "deprecated", "abstract", "async",
        "modification", "documentation", "defaultLibrary"
    ]
}

enum SourceKitLSPError: Error, Equatable, Sendable {
    case sourceKitLSPUnavailable
    case connectionClosed
    case invalidResponse
}

actor SourceKitLSPStdioConnection: SourceKitLSPConnecting {
    private var process: Process?
    private var input: Pipe?
    private var output: Pipe?
    private var nextRequestID = 1

    func start(executablePath: String, projectURL: URL) async throws {
        let process = Process()
        let input = Pipe()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.currentDirectoryURL = projectURL
        process.standardInput = input
        process.standardOutput = output
        process.standardError = Pipe()

        try process.run()

        self.process = process
        self.input = input
        self.output = output
    }

    func request(method: String, params: JSONRPCValue?) async throws -> JSONRPCValue? {
        let requestID = nextRequestID
        nextRequestID += 1
        try write(
            .object([
                "jsonrpc": .string("2.0"),
                "id": .int(requestID),
                "method": .string(method),
                "params": params ?? .null
            ])
        )

        while true {
            guard let response = try readMessage() else {
                throw SourceKitLSPError.connectionClosed
            }

            guard case .object(let object) = response else {
                throw SourceKitLSPError.invalidResponse
            }

            guard object["id"]?.intValue == requestID else {
                continue
            }

            if object["error"] != nil {
                throw SourceKitLSPError.invalidResponse
            }

            return object["result"]
        }
    }

    func notify(method: String, params: JSONRPCValue?) async throws {
        try write(
            .object([
                "jsonrpc": .string("2.0"),
                "method": .string(method),
                "params": params ?? .null
            ])
        )
    }

    func stop() {
        process?.terminate()
        process = nil
        input = nil
        output = nil
    }

    private func write(_ value: JSONRPCValue) throws {
        guard let input else {
            throw SourceKitLSPError.connectionClosed
        }

        let data = try JSONEncoder().encode(value)
        var message = Data("Content-Length: \(data.count)\r\n\r\n".utf8)
        message.append(data)
        input.fileHandleForWriting.write(message)
    }

    private func readMessage() throws -> JSONRPCValue? {
        guard let output else {
            throw SourceKitLSPError.connectionClosed
        }

        let handle = output.fileHandleForReading
        var header = Data()
        while !header.contains(Data("\r\n\r\n".utf8)) {
            let byte = handle.readData(ofLength: 1)
            if byte.isEmpty {
                return nil
            }
            header.append(byte)
        }

        guard let headerString = String(data: header, encoding: .utf8),
              let contentLengthLine = headerString.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("content-length:") }),
              let length = Int(contentLengthLine.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "")
        else {
            throw SourceKitLSPError.invalidResponse
        }

        let body = handle.readData(ofLength: length)
        guard !body.isEmpty else {
            return nil
        }
        return try JSONDecoder().decode(JSONRPCValue.self, from: body)
    }
}

enum JSONRPCValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONRPCValue])
    case object([String: JSONRPCValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONRPCValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONRPCValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            value
        case .double(let value):
            Int(value)
        default:
            nil
        }
    }
}

extension EditorSourceLanguage {
    var lspLanguageID: String {
        switch self {
        case .c:
            "c"
        case .cpp:
            "cpp"
        case .swift, .packageManifest:
            "swift"
        default:
            rawValue
        }
    }
}
