//
//  main.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine

@main
struct AdaEditorApp: App {
    var scene: some AppScene {
        GUIAppScene {
            EditorWindow()
        }
    }
}
