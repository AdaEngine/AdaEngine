//
//  Text2dExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 19.12.2025.
//

import AdaEngine

@main
struct Text2dExample: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                Text2dPlugin(),
            )
            .windowMode(.windowed)
    }
}

struct Text2dPlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.spawn(bundle: Camera2D())

        var textAttributes = TextAttributeContainer()
        textAttributes.foregroundColor = .red
//        textAttributes.outlineColor = .blue
        textAttributes.font = .system(size: 100)
        app.spawn(
            "Text",
            bundle: Text2D(
                textComponent: TextComponent(
                    text: AttributedText("AdaEngien", attributes: textAttributes)
                )
            )
            .extend {
                Transform()
            }
        )
    }
}

