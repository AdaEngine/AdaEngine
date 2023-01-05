//
//  AdaEditorApp.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine

@main
struct AdaEditorApp: App {
    
    let gameScene = GameScene2D()
    
    var scene: some AppScene {
        GameAppScene {
            try gameScene.makeScene()
        }
        .windowMode(.windowed)
        .windowTitle("AdaEngine")
    }
}
