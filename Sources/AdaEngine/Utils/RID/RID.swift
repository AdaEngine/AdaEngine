//
//  RID.swift
//  
//
//  Created by v.prusakov on 5/21/22.
//

// swiftlint:disable all

/// Object contains identifier to resource.
/// Currently, RID system help us to manage platform specific data without overcoding.
/// - NOTE: Please, don't use RID for saving/restoring data.
public struct RID: Equatable, Hashable, Codable {
    internal let id: Int
}

extension RID {
    
    public static var empty = RID(id: -1)
    
    /// Generate random unique rid
    init() {
        self.id = Self.readTime()
    }
    
    private static func readTime() -> Int {
        var time = timespec(tv_sec: 0, tv_nsec: 0)
        clock_gettime(CLOCK_MONOTONIC, &time)
        
        return (time.tv_sec * 10000000) + (time.tv_nsec / 100) + 0x01B21DD213814000;
    }
}

// swiftlint:enable all
