//
//  main.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine

@main
struct AdaEditorApp: App {
    
    let gameScene = GameScene()
    
    var scene: some AppScene {
        GameAppScene {
            gameScene.makeScene()
        }
        .windowMode(.windowed)
    }
}
