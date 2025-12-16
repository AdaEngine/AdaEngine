//
//  UIRenderPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 04.12.2025.
//

import AdaApp
import AdaECS
import AdaRender
import AdaUtils

public struct UIRenderPlugin: Plugin {
    public func setup(in app: borrowing AdaApp.AppWorlds) {
        app.main.registerRequiredComponent(
            RenderItems<UIRenderItem>.self,
            for: Camera.self
        ) {
            RenderItems<UIRenderItem>()
        }
        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }
        renderWorld.insertResource(ExtractedUIComponents())
        let renderGraph = renderWorld.getRefResource(RenderGraph.self)
        renderGraph.wrappedValue.addNode(UIRenderNode())
        renderGraph.wrappedValue.addNodeEdge(from: UIRenderNode.self, to: Main2DRenderNode.self)
        renderWorld.addSystem(ExtractUIComponentsSystem.self, on: .extract)
        renderWorld.addSystem(UIRenderPreparingSystem.self, on: .prepare)
    }
}

@System
public func UIRenderPreparing(
    _ cameras: Query<Camera>,
    _ uiComponents: Res<ExtractedUIComponents>,
) async {
    await cameras.forEach { camera in
        for component in uiComponents.components {
            var context = await UIGraphicsContext(camera: camera)
            await component.view.draw(with: context)

            // 1. store context and than render
            // 2. render context by command in render graph
        }
    }
}

@PlainSystem
public struct UIRenderDrawSystem {
    public init(world: World) { }

    public func update(context: UpdateContext) async {
        
    }
}

public struct ExtractedUIComponents: Resource {
    public var components: ContiguousArray<UIComponent> = []
}

@System
public func ExtractUIComponents(
    _ uiComponents: Extract<
        Query<UIComponent>
    >,
    _ extractedUIComponents: ResMut<ExtractedUIComponents>
) {
    extractedUIComponents.components.removeAll(keepingCapacity: true)

    uiComponents().forEach {
        extractedUIComponents.components.append($0)
    }
}

public struct UIRenderNode: RenderNode {
    public func execute(
        context: inout Context,
        renderContext: AdaRender.RenderContext
    ) async throws -> [AdaRender.RenderSlotValue] {
        return []
    }
}

public struct UIRenderItem: RenderItem {
    public var sortKey: Int
    public var entity: AdaECS.Entity.ID
    public var drawPass: any AdaRender.DrawPass
    public var batchRange: Range<Int32>? = nil
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
