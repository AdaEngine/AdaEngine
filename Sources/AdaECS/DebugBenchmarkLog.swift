//
//  DebugBenchmarkLog.swift
//  AdaECS
//
//  Writes NDJSON to a file when CURSOR_DEBUG_LOG_PATH is set (for benchmark profiling).
//

import Foundation

enum DebugBenchmarkLogCounter {
    static var entitiesInsertCount = 0
    static var insertNewEntityCount = 0
    static var moveEntityToArchetypeCount = 0
    static var queryEntityLookupCount = 0
    static var querySetChunkCount = 0
}

public enum DebugBenchmarkLog {

    private static let logPath = ProcessInfo.processInfo.environment["CURSOR_DEBUG_LOG_PATH"]
    private static let sessionId = "ef35b1"

    /// Append one NDJSON line when CURSOR_DEBUG_LOG_PATH is set. No-op otherwise.
    public static func write(
        location: String,
        message: String,
        data: [String: Any] = [:],
        hypothesisId: String? = nil
    ) {
        guard let path = logPath, !path.isEmpty else { return }
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        var payload: [String: Any] = [
            "sessionId": sessionId,
            "location": location,
            "message": message,
            "timestamp": timestamp
        ]
        if !data.isEmpty {
            payload["data"] = data
        }
        if let hid = hypothesisId {
            payload["hypothesisId"] = hid
        }
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: json, encoding: .utf8)
        else { return }
        let content = line + "\n"
        guard let contentData = content.data(using: .utf8) else { return }
        let url = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(contentData)
        } else {
            try? contentData.write(to: url, options: .atomic)
        }
    }

    /// Call from benchmark to mark start/end of a benchmark (when CURSOR_DEBUG_LOG_PATH is set).
    public static func benchmarkPhase(name: String, phase: String) {
        write(
            location: "AdaECSBenchmarks",
            message: "benchmark_phase",
            data: ["benchmark": name, "phase": phase],
            hypothesisId: nil
        )
    }
}
