//
//  AppScene.swift
//  
//
//  Created by v.prusakov on 6/14/22.
//

@MainActor
public protocol AppScene {
    associatedtype Body: AppScene
    var scene: Body { get }
    
    var _configuration: _AppSceneConfiguration { get set }
    func _makeWindow(with configuration: _AppSceneConfiguration) async throws -> Window
}

public struct _AppSceneConfiguration {
    var minimumSize: Size = Window.defaultMinimumSize
    var windowMode: Window.Mode = .fullscreen
    var isSingleWindow: Bool = false
    var title: String?
}

public extension AppScene {
    func minimumSize(width: Float, height: Float) -> some AppScene {
        var newValue = self
        newValue._configuration.minimumSize = Size(width: width, height: height)
        return newValue
    }
    
    func windowMode(_ mode: Window.Mode) -> some AppScene {
        var newValue = self
        newValue._configuration.windowMode = mode
        return newValue
    }
    
    func singleWindow(_ isSingleWindow: Bool) -> some AppScene {
        var newValue = self
        newValue._configuration.isSingleWindow = isSingleWindow
        return newValue
    }
    
    func windowTitle(_ title: String) -> some AppScene {
        var newValue = self
        newValue._configuration.title = title
        return newValue
    }
}
