//
//  System+Runtime.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/24/22.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// We should register our systems in engine, because we should initiate them in memory
// TODO: (Vlad) Add system list to editor and generate file with registred systems.
extension System {
    /// The Swift name of the system.
    static var swiftName: String {
        return String(reflecting: self)
    }
}
