//
//  WidgetGroup.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public struct WidgetGroup<Content: Widget>: AppScene {
    
    public var scene: Never { fatalError() }
    
    let content: Content
    
    public init(@WidgetBuilder content: () -> Content) {
        self.content = content()
    }
}

extension WidgetGroup: InternalAppScene {
    @MainActor
    func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> UIWindow {
        let frame = Rect(origin: .zero, size: configuration.minimumSize)
        let window = UIWindow(frame: frame)
        
        let gameSceneView = UIWidgetView(rootView: self.content)
        gameSceneView.autoresizingRules = [.flexibleWidth, .flexibleHeight]
        window.addSubview(gameSceneView)
        
        window.setWindowMode(configuration.windowMode)
        window.minSize = configuration.minimumSize
        
        if let title = configuration.title {
            window.title = title
        }
        
        return window
    }
}
