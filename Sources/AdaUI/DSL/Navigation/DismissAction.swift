//
//  DismissAction.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 25.03.2026.
//

import AdaUtils

/// An action that dismisses a presentation.
///
/// Use the ``EnvironmentValues/dismiss`` environment value to get an instance
/// of this structure. Then call the instance to perform the dismissal.
///
/// ```swift
/// struct DetailView: View {
///     @Environment(\.dismiss) var dismiss
///
///     var body: some View {
///         Button("Close") { dismiss() }
///     }
/// }
/// ```
public struct DismissAction: Sendable {
    @MainActor let action: @MainActor () -> Void

    @MainActor
    public func callAsFunction() {
        action()
    }
}

public extension EnvironmentValues {
    /// An action that dismisses the current presentation.
    @Entry var dismiss: DismissAction = DismissAction { }
}
