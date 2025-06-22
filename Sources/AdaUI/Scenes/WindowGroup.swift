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
@MainActor
func WindowGroupUpdate(
    _ context: inout WorldUpdateContext,
    _ isAllocated: LocalIsolated<Bool> = false
) {
    if isAllocated.wrappedValue {
        return
    }
    guard
        let resource = context.world.getResource(PrimaryWindow.self),
        let containerView = context.world.getResource(InitialContainerView.self)
    else {
        return
    }

    let view = containerView.view
    view.autoresizingRules = [.flexibleWidth, .flexibleHeight]
    resource.window.addSubview(view)

    isAllocated.wrappedValue = true
}
