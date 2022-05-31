//
//  main.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine

let scene = GameScene().makeScene()

let windowConfig = ApplicationRunOptions.WindowConfiguration(
    windowClass: EditorWindow.self,
    windowMode: .fullscreen
)

let options = ApplicationRunOptions(
    initialScene: nil,
    sceneName: nil,
    windowConfiguration: windowConfig
)

ApplicationCreate(options: options)
