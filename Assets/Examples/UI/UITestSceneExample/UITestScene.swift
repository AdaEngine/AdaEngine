//
//  UITesScene.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaEngine

@main
struct UITestSceneApp: App {
    var body: some AppScene {
        WindowGroup {
            SomeContent()
        }
        .windowMode(.windowed)
    }
}

struct SomeContent: View {
    var body: some View {
        VStack {
            Color.blue

            Color.green
        }
    }
}
