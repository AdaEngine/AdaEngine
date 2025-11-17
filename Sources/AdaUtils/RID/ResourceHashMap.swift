//
//  ResourceHashMap.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/22.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Collections

/// The data type contains any values usign RID as key
/// - Note: ResourceHashMap is thread safety
public struct ResourceHashMap<T> {
    
    private var queue: DispatchQueue = DispatchQueue(label: "ResourceMap-\(T.self)")
    
    private var dictionary: OrderedDictionary<RID, T> = [:]
    
    public var values: OrderedDictionary<RID, T>.Values {
        self.dictionary.values
    }
    
    public func get(_ rid: RID) -> T? {
        return self.queue.sync {
            return self.dictionary[rid]
        }
    }
    
    /// Generate new RID and set value for it
    /// - Returns: RID instance of holded resource
    public mutating func setValue(_ value: T) -> RID {
        self.queue.sync(flags: .barrier) {
            let rid = RID()
            self.dictionary[rid] = value
            
            return rid
        }
    }
    
    public mutating func setValue(_ value: T?, forKey rid: RID) {
        self.queue.sync(flags: .barrier) {
            self.dictionary[rid] = value
        }
    }
    
    public mutating func removeAll() {
        self.queue.sync(flags: .barrier) {
            self.dictionary.removeAll()
        }
    }
    
    public subscript(_ rid: RID) -> T? {
        get {
            return self.get(rid)
        }
        
        set {
            self.setValue(newValue, forKey: rid)
        }
    }
    
    public func contains(_ rid: RID) -> Bool {
        return self.get(rid) != nil
    }
    
    /// The number of elements in the hash map.
    public var count: Int {
        return self.dictionary.count
    }
}

extension ResourceHashMap: Sequence {
    public typealias Iterator = OrderedDictionary<RID, T>.Iterator
    
    public func makeIterator() -> OrderedDictionary<RID, T>.Iterator {
        return self.dictionary.makeIterator()
    }
}

extension ResourceHashMap: ExpressibleByDictionaryLiteral {
    
    public init(dictionaryLiteral elements: (RID, T)...) {
        self.dictionary.merge(elements, uniquingKeysWith: { $1 })
    }
}
