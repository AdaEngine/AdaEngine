//
//  UIRenderPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 04.12.2025.
//

import AdaApp
import AdaECS
import AdaRender

public struct UIRenderPlugin: Plugin {
    public func setup(in app: borrowing AdaApp.AppWorlds) {
        app.main.registerRequiredComponent(
            RenderItems<UIRenderItem>.self,
            for: Camera.self
        ) {
            RenderItems()
        }
        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }
        let renderGraph = renderWorld.getRefResource(RenderGraph.self)
        renderGraph.wrappedValue.addNode(UIRenderNode())
        renderWorld.addSystem(UIRenderPreparingSystem.self, on: .extract)
    }
}

@System
func UIRenderPreparing(
    _ uiComponents: Extract<
        Query<UIComponent>
    >
) {
    uiComponents.wrappedValue.forEach { component in
        
    }
}

func ExtractUIComponents(
    _ uiComponents: Extract<
        Query<UIComponent>
    >
) {

}

struct UIRenderNode: RenderNode {
    func execute(
        context: inout Context,
        renderContext: AdaRender.RenderContext
    ) async throws -> [AdaRender.RenderSlotValue] {
        return []
    }
}

struct UIRenderItem: RenderItem {
    var sortKey: Int
    var entity: AdaECS.Entity.ID
    var drawPass: any AdaRender.DrawPass
}

struct UIRenderDrawPass: DrawPass {
    func render(
        with renderEncoder: any AdaRender.RenderCommandEncoder,
        world: AdaECS.World,
        view: AdaECS.Entity,
        item: UIRenderItem
    ) throws {

    }
}
