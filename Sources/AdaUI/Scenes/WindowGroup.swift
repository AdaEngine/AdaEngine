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
struct WindowGroupSystem {

    @LocalIsolated private var isAllocated = false

    init(world: World) { }

    func update(context: inout UpdateContext) {
        if isAllocated {
            return
        }
        guard
            let resource = context.world.getResource(PrimaryWindow.self),
            let containerView = context.world.getResource(InitialContainerView.self)
        else {
            return
        }

        context.taskGroup?.addTask { @MainActor in
            let gameSceneView = containerView.view
            gameSceneView.autoresizingRules = [.flexibleWidth, .flexibleHeight]
            resource.window.addSubview(gameSceneView)

            self.isAllocated = true
        }
    }
}
