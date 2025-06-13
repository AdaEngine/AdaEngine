//
//  Bundle.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 13.06.2025.
//

/// Collection of components.
public protocol Bundle: Sendable, ~Copyable {
    var components: [any Component] { get }
}
