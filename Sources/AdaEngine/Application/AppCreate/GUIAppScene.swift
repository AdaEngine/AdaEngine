//
//  GUIAppScene.swift
//  
//
//  Created by v.prusakov on 6/14/22.
//

/// GUI App Scene relative to work with GUI Applications.
/// That match for application without needed to implement game logic.
public struct GUIAppScene: AppScene {
    public var scene: Never { fatalError() }
    
    public var _configuration = _AppSceneConfiguration()
    let window: () -> Window
    
    /// - Parameters window: Window for presenting on screen
    public init(window: @escaping () -> Window) {
        self.window = window
    }
    
    public func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> Window {
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
}
