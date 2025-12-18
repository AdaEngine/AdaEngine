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
import Logging

public struct ExtractedUIComponents: Resource {
    public var components: ContiguousArray<UIComponent> = []
}

@System
public func ExtractUIComponents(
    _ uiComponents: Extract<
        Query<UIComponent>
    >,
    _ pendingViews: Extract<
        Res<UIWindowPendingDrawViews>
    >,
    _ extractedUIComponents: ResMut<ExtractedUIComponents>
) {
    extractedUIComponents.components.removeAll(keepingCapacity: true)

    pendingViews().windows.forEach {
        extractedUIComponents.components.append(UIComponent(view: $0, behaviour: .default))
    }
    uiComponents().forEach {
        extractedUIComponents.components.append($0)
    }
}

public struct PendingUIGraphicsContext: Resource {
    public var graphicContexts: ContiguousArray<UIGraphicsContext> = []
}

@System
@MainActor
public func UIRenderPreparing(
    _ cameras: Query<Camera>,
    _ uiComponents: Res<ExtractedUIComponents>,
    _ contexts: ResMut<PendingUIGraphicsContext>
) {
    contexts.graphicContexts.removeAll(keepingCapacity: true)
    uiComponents.components.forEach { component in
        let context = UIGraphicsContext()
        component.view.draw(with: context)

        contexts.graphicContexts.append(context)
    }
}

// - prepare draw commands to mesh
@PlainSystem
public struct UIRenderTesselationSystem {

    @ResMut<PendingUIGraphicsContext>
    private var contexts

    @ResMut<SortedRenderItems<Transparent2DRenderItem>>
    private var renderItems

    public init(world: World) { }

    public func update(context: UpdateContext) {
        for context in contexts.graphicContexts {
            for command in context.commandQueue.commands.reversed() {
                switch command {
                case let .setLineWidth(lineWidth):

                case let .drawQuad(transform, texture, color):
                    
                case let .drawText(textLayout, transform):

                case let .drawGlyph(glyph, transform):

                case .commit:
                default:
                    continue
                }
            }
        }
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
