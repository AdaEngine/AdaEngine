//
//  AdaTrace.swift
//  AdaEngine
//
//  Created by Codex on 02.03.2026.
//

import Tracing

public enum AdaTrace {
    /// Executes a synchronous operation inside a tracing span.
    /// - Parameters:
    ///   - name: The span name.
    ///   - body: The operation to execute.
    /// - Returns: The operation result.
    @inlinable
    public static func span<T>(
        _ name: String,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ body: @Sendable () throws -> T
    ) rethrows -> T {
        try Tracing.withSpan(name, function: function, file: fileID, line: line) { _ in
            try body()
        }
    }

    /// Starts a span and returns it for manual lifecycle control.
    /// - Parameter name: The span name.
    /// - Returns: The started span.
    @inlinable
    public static func startSpan(_ name: String, function: String = #function, file fileID: String = #fileID, line: UInt = #line) -> any Span {
        InstrumentationSystem.tracer.startSpan(name, function: function, file: fileID, line: line)
    }

    /// Executes an async operation inside a tracing span.
    /// - Parameters:
    ///   - name: The span name.
    ///   - body: The operation to execute.
    /// - Returns: The operation result.
    @inlinable
    public static func span<T>(
        _ name: String,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ body: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await Tracing.withSpan(name, function: function, file: fileID, line: line) { _ in
            try await body()
        }
    }
}
