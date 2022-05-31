//
//  main.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine

let scene = GameScene().makeScene()
let options = ApplicationRunOptions(initialScene: scene)

ApplicationCreate(options: options)
