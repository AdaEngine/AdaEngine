//
//  UIRenderNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 19.12.2025.
//

import AdaECS
import AdaRender

public struct UIRenderNode: RenderNode {

    public func update(from world: World) {

    }

    public func execute(
        context: inout Context,
        renderContext: AdaRender.RenderContext
    ) async throws -> [AdaRender.RenderSlotValue] {
        []
    }
}
