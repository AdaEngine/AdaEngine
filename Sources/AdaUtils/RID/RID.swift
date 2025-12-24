//
//  RID.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/22.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#elseif os(Android) || os(Linux)
import Glibc
#endif

// swiftlint:disable all

/// Resource Identifier.
/// An object contains identifier to resource.
/// Currently, RID system help us to manage platform specific data without overcoding.
/// - NOTE: Please, don't use RID for saving/restoring data.
public struct RID: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: Int
}

public extension RID {
    
    static let empty = RID(id: -1)

    /// Generate random unique rid
    init() {
        self.id = Self.readTime()
    }
    
    private static func readTime() -> Int {
        #if os(Windows)
        // Windows doesn't have clock_gettime, use Foundation's ProcessInfo
        let uptime = ProcessInfo.processInfo.systemUptime
        let seconds = Int64(uptime)
        let nanoseconds = Int64((uptime - Double(seconds)) * 1_000_000_000)
        return Int((seconds * 10000000) + (nanoseconds / 100) + 0x01B21DD213814000)
        #else
        var time = timespec(tv_sec: 0, tv_nsec: 0)
        unsafe clock_gettime(CLOCK_MONOTONIC, &time)
        
        return (time.tv_sec * 10000000) + (time.tv_nsec / 100) + 0x01B21DD213814000;
        #endif
    }
}

// swiftlint:enable all
