//
//  GUIAppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/14/22.
//

import AdaApp
import Math

/// GUI App Scene relative to work with GUI Applications.
/// You must use this scene for applications with custom view hieararchy and if you don't need a game scenes.
/// - Warning: Under development!
public struct GUIAppScene: AppScene {
    
    public var body: Never { fatalError() }
    
    let window: () -> UIWindow
    let filePath: StaticString
    
    /// Create a new app scene for GUI application.
    /// - Parameters window: ``Window`` which will be presented on screen
    public init(
        window: @escaping () -> UIWindow,
        filePath: StaticString = #filePath
    ) {
        self.window = window
        self.filePath = filePath
    }
}

extension GUIAppScene: InternalAppScene {
    @MainActor
    public func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> Any {
        let window = window()
        
        if window.frame.size == .zero {
            window.frame = Rect(origin: .zero, size: configuration.minimumSize)
        }
        
        if let title = configuration.title {
            window.title = title
        }
        
        window.setWindowMode(configuration.windowMode == .fullscreen ? .fullscreen : .windowed)
        window.minSize = configuration.minimumSize
        return window
    }

    @MainActor
    public func _getFilePath() -> StaticString {
        self.filePath
    }
}
