//
//  DrawPassStorage.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

public enum DrawPassStorage {
    
    private static var draws: [DrawPassId: any DrawPass] = [:]
    
    private static let lock: NSLock = NSLock()
    
    public static func getDrawPass<I: RenderItem>(for item: I) -> AnyDrawPass<I>? {
        lock.lock()
        defer { lock.unlock() }
        guard let drawPass = draws[item.drawPassId] else {
            return nil
        }
        
        return AnyDrawPass(drawPass)
    }
    
    public static func setDrawPass<T: DrawPass>(_ drawPass: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = T.identifier
        draws[key] = drawPass
    }
}
