#if os(Windows)
import ACPModel
import Foundation

protocol ClientDelegate: AnyObject, Sendable {
    func handleFileReadRequest(_ path: String, sessionId: String, line: Int?, limit: Int?) async throws -> ReadTextFileResponse
    func handleFileWriteRequest(_ path: String, content: String, sessionId: String) async throws -> WriteTextFileResponse
    func handleTerminalCreate(command: String, sessionId: String, args: [String]?, cwd: String?, env: [EnvVariable]?, outputByteLimit: Int?) async throws -> CreateTerminalResponse
    func handleTerminalOutput(terminalId: TerminalId, sessionId: String) async throws -> TerminalOutputResponse
    func handleTerminalWaitForExit(terminalId: TerminalId, sessionId: String) async throws -> WaitForExitResponse
    func handleTerminalKill(terminalId: TerminalId, sessionId: String) async throws -> KillTerminalResponse
    func handleTerminalRelease(terminalId: TerminalId, sessionId: String) async throws -> ReleaseTerminalResponse
    func handlePermissionRequest(request: RequestPermissionRequest) async throws -> RequestPermissionResponse
    func shutdown() async
}

extension ClientDelegate {
    func shutdown() async {}
}

extension Client {
    func route(_ request: JSONRPCRequest) async throws -> AnyCodable {
        guard let delegate = clientDelegate else { throw ClientError.delegateNotSet }
        switch request.method {
        case "fs/read_text_file":
            let params: ReadTextFileRequest = try decode(request)
            return try encode(await delegate.handleFileReadRequest(params.path, sessionId: params.sessionId, line: params.line, limit: params.limit))
        case "fs/write_text_file":
            let params: WriteTextFileRequest = try decode(request)
            return try encode(await delegate.handleFileWriteRequest(params.path, content: params.content, sessionId: params.sessionId))
        case "terminal/create":
            let params: CreateTerminalRequest = try decode(request)
            return try encode(await delegate.handleTerminalCreate(command: params.command, sessionId: params.sessionId,
                args: params.args, cwd: params.cwd, env: params.env, outputByteLimit: params.outputByteLimit))
        case "terminal/output":
            let params: TerminalOutputRequest = try decode(request)
            return try encode(await delegate.handleTerminalOutput(terminalId: params.terminalId, sessionId: params.sessionId))
        case "terminal/wait_for_exit":
            let params: WaitForExitRequest = try decode(request)
            return try encode(await delegate.handleTerminalWaitForExit(terminalId: params.terminalId, sessionId: params.sessionId))
        case "terminal/kill":
            let params: KillTerminalRequest = try decode(request)
            return try encode(await delegate.handleTerminalKill(terminalId: params.terminalId, sessionId: params.sessionId))
        case "terminal/release":
            let params: ReleaseTerminalRequest = try decode(request)
            return try encode(await delegate.handleTerminalRelease(terminalId: params.terminalId, sessionId: params.sessionId))
        case "request_permission", "session/request_permission":
            let params: RequestPermissionRequest = try decode(request)
            return try encode(await delegate.handlePermissionRequest(request: params))
        default: throw ClientError.transportError("Unsupported ACP client method: \(request.method)")
        }
    }

    private func decode<T: Decodable>(_ request: JSONRPCRequest) throws -> T {
        guard let params = request.params else { throw ClientError.invalidResponse }
        return try JSONDecoder().decode(T.self, from: JSONEncoder().encode(params))
    }

    private func encode<T: Encodable>(_ value: T) throws -> AnyCodable {
        try JSONDecoder().decode(AnyCodable.self, from: JSONEncoder().encode(value))
    }
}
#endif
