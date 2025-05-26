//
//  WindowGroup.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public struct WindowGroup<Content: View>: AppScene {

    public var scene: Never { fatalError() }
    
    let content: Content
    let filePath: StaticString
    
    public init(@ViewBuilder content: () -> Content, filePath: StaticString = #filePath) {
        self.content = content()
        self.filePath = filePath
    }
}

extension WindowGroup: InternalAppScene {
    @MainActor
    func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> UIWindow {
        let frame = Rect(origin: .zero, size: configuration.minimumSize)
        let window = UIWindow(frame: frame)
        
        let gameSceneView = UIContainerView(rootView: self.content)
        gameSceneView.autoresizingRules = [.flexibleWidth, .flexibleHeight]
        window.addSubview(gameSceneView)
        
        window.setWindowMode(configuration.windowMode)
        window.minSize = configuration.minimumSize
        
        if let title = configuration.title {
            window.title = title
        }
        
        return window
    }

    @MainActor
    func _getFilePath() -> StaticString {
        self.filePath
    }
}
