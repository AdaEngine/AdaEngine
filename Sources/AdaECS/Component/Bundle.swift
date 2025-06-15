//
//  Bundle.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 13.06.2025.
//

/// Collection of components.
///
/// Example:
/// ```swift
/// @Bundle
/// struct PlayerBundle {
///     var player: Player
/// }
///
/// let playerBundle = PlayerBundle(player: Player(name: "John"))
/// world.spawn(bundle: playerBundle)
/// ```
public protocol Bundle: Sendable, ~Copyable {
    /// The components that are part of the bundle.
    var components: [any Component] { get }
}
