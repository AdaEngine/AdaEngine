//
//  File.swift
//  
//
//  Created by v.prusakov on 7/9/22.
//

import Box2DSwift
import AppKit

public struct KeyModifier: OptionSet, Hashable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let capsLock = KeyModifier(rawValue: 1 << 0)
    public static let shift = KeyModifier(rawValue: 1 << 1)
    public static let control = KeyModifier(rawValue: 1 << 2)
    public static let main = KeyModifier(rawValue: 1 << 3)
    public static let alt = KeyModifier(rawValue: 1 << 4)
}

#if os(macOS)

import AppKit

extension KeyModifier {
    init(modifiers: NSEvent.ModifierFlags) {
        var flags: KeyModifier = []
        
        if modifiers.contains(.capsLock) {
            flags.insert(.capsLock)
        }
        
        if modifiers.contains(.command) {
            flags.insert(.main)
        }
        
        if modifiers.contains(.control) {
            flags.insert(.control)
        }
        
        if modifiers.contains(.option) {
            flags.insert(.alt)
        }
        
        if modifiers.contains(.shift) {
            flags.insert(.shift)
        }
        
        self.init(rawValue: flags.rawValue)
    }
}
