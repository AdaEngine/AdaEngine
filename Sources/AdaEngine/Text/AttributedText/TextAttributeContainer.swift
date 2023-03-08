//
//  TextAttributeContainer.swift
//  
//
//  Created by v.prusakov on 3/7/23.
//

/// A container for attribute keys and values.
@dynamicMemberLookup
public struct TextAttributeContainer: Hashable {
    
    typealias Container = [ObjectIdentifier : AnyHashable]
    
    private(set) var container: Container = [:]
    
    public init() { }
    
    init(container: Container) {
        self.container = container
    }

    public mutating func merge(
        _ attributes: TextAttributeContainer,
        mergePolicy: AttributedText.AttributeMergePolicy = .keepNew
    ) {
        self.container.merge(attributes.container, uniquingKeysWith: { old, new in
            return mergePolicy == .keepNew ? new : old
        })
    }
    
    public mutating func merging(
        _ attributes: TextAttributeContainer,
        mergePolicy: AttributedText.AttributeMergePolicy = .keepNew
    ) -> TextAttributeContainer {
        let newContainer = self.container.merging(attributes.container, uniquingKeysWith: { old, new in
            return mergePolicy == .keepNew ? new : old
        })
        
        return TextAttributeContainer(container: newContainer)
    }
    
}

// MARK: - Subscripts

public extension TextAttributeContainer {
    subscript<T: TextAttributeKey>(_ type: T.Type) -> T.Value? {
        get {
            return self.container[ObjectIdentifier(type)] as? T.Value
        }
        
        set {
            self.container[ObjectIdentifier(type), default: T.defaultValue] = newValue
        }
    }
    
    subscript<T>(dynamicMember keyPath: WritableKeyPath<TextAttributeContainer, T>) -> T {
        get {
            return self[keyPath: keyPath]
        }
        
        set {
            self[keyPath: keyPath] = newValue
        }
    }
}
