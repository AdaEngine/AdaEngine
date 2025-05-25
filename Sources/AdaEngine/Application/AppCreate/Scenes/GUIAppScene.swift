//
//  GUIAppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/14/22.
//

/// GUI App Scene relative to work with GUI Applications.
/// You must use this scene for applications with custom view hieararchy and if you don't need a game scenes.
/// - Warning: Under development!
public struct GUIAppScene: AppScene {
    
    public var scene: Never { fatalError() }
    
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
    func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> UIWindow {
        let window = window()
        
        if window.frame.size == .zero {
            window.frame = Rect(origin: .zero, size: configuration.minimumSize)
        }
        
        if let title = configuration.title {
            window.title = title
        }
        
        window.setWindowMode(configuration.windowMode)
        window.minSize = configuration.minimumSize
        return window
    }

    @MainActor
    func _getFilePath() -> StaticString {
        self.filePath
    }
}
