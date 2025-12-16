//
//  WindowGroup.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

import AdaApp
import AdaECS
import AdaUtils
import Math

public struct WindowGroup<Content: View>: AppScene {

    public var body: some AppScene {
        EmptyWindow()
            .transformAppWorlds { appWorld in
                appWorld.insertResource(
                    InitialContainerView(view: UIContainerView(rootView: self.content))
                )
                appWorld.addSystem(WindowGroupUpdateSystem.self, on: .startup)
            }
    }

    let content: Content
    let filePath: StaticString
    
    public init(@ViewBuilder content: () -> Content, filePath: StaticString = #filePath) {
        self.content = content()
        self.filePath = filePath
    }
}

struct InitialContainerView: Resource {
    let view: UIView
}

@System
@MainActor
func WindowGroupUpdate(
    _ context: WorldUpdateContext,
    _ primaryWindow: ResMut<PrimaryWindow>,
    _ containerView: Res<InitialContainerView>
) {
    let view = containerView.view
    view.autoresizingRules = [.flexibleWidth, .flexibleHeight]
    primaryWindow.wrappedValue.window.addSubview(view)
}
