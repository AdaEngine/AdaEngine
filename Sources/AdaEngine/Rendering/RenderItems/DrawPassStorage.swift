//
//  DrawPassStorage.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

/// The storage for caching draw passes by their type.
public enum DrawPassStorage {
    
    nonisolated(unsafe) private static var draws: [DrawPassId: any DrawPass] = [:]
    
    private static let lock: NSLock = NSLock()
    
    /// Get draw pass for render item.
    public static func getDrawPass<I: RenderItem>(for item: I) -> AnyDrawPass<I>? {
        lock.lock()
        defer { lock.unlock() }
        guard let drawPass = draws[item.drawPassId] else {
            return nil
        }
        
        return AnyDrawPass(drawPass)
    }
    
    /// Store draw pass.
    public static func setDrawPass<T: DrawPass>(_ drawPass: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = T.identifier
        draws[key] = drawPass
    }
}
