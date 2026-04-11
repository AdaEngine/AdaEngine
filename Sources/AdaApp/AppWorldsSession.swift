//
//  AppWorldsSession.swift
//  AdaApp
//

import Foundation

/// Weak reference to the root ``AppWorlds`` of the running application.
/// Set from ``AppContext`` so embedded runtimes (e.g. ``SceneView``) can register as subworlds
/// and share the same ``AppWorlds/update()`` loop as the host.
@MainActor
public enum AppWorldsSession {
    public static weak var current: AppWorlds?
}
