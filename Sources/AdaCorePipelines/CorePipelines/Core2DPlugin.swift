//
//  Core2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

import AdaApp
import AdaECS
import AdaUtils
import AdaRender
import AdaTransform
import Math

/// Plugin for RenderWorld added 2D render capatibilites.
public struct Core2DPlugin: Plugin {

    public init() {}
    
    /// Input slots of render graph.
    public enum InputNode {
        public static let view: RenderSlot.Label = "view"
    }

    public func setup(in app: AppWorlds) {
        guard let app = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        // Add Systems
        app.insertResource(SortedRenderItems<Transparent2DRenderItem>())
        app.addSystem(BatchAndSortTransparent2DRenderItemsSystem.self, on: .prepare)
            .addSystem(ExtractCameraSystem.self, on: .extract) // FIXME: Move to CorePlugin or smth

        var graph = RenderGraph(label: .main2D)
        let entryNode = graph.addEntryNode(inputs: [
            RenderSlot(name: InputNode.view, kind: .entity)
        ])

        graph.addNode(EmptyNode(), by: .Main2D.beginPass)
        graph.addNode(Main2DRenderNode())
        graph.addNode(EmptyNode(), by: .Main2D.endPass)
        graph.addNode(UpscaleNode())

        graph.addSlotEdge(
            fromNode: entryNode,
            outputSlot: InputNode.view,
            toNode: Main2DRenderNode.name,
            inputSlot: Main2DRenderNode.InputNode.view
        )

        graph.addNodeEdge(from: RenderNodeLabel.Main2D.beginPass, to: Main2DRenderNode.name)
        graph.addNodeEdge(from: Main2DRenderNode.name, to: RenderNodeLabel.Main2D.endPass)
        graph.addNodeEdge(from: RenderNodeLabel.Main2D.endPass, to: UpscaleNode.name)

        app
            .getRefResource(RenderGraph.self)
            .wrappedValue
            .addSubgraph(graph, name: .main2D)
    }
}

public extension RenderGraph.Label {
    /// Render graph name.
    static let main2D: RenderGraph.Label = "Scene 2D Render Graph"
}

public extension RenderNodeLabel {
    enum Main2D {
        public static let beginPass: RenderNodeLabel = "Main2D.BeginPass"
        public static let endPass: RenderNodeLabel = "Main2D.EndPass"
    }
}

// - FIXME: Remove when fix generic version of BatchAndSortTransparent<T>
@PlainSystem
public struct BatchAndSortTransparent2DRenderItemsSystem {

    @Query<RenderItems<Transparent2DRenderItem>>
    private var query

    @ResMut<SortedRenderItems<Transparent2DRenderItem>>
    private var sortedRenderItems

    public init(world: World) { }

    public func update(context: UpdateContext) async {
        sortedRenderItems.items.removeAll(keepingCapacity: true)
        self.query.forEach { renderItems in
            let items = renderItems.sorted().items
            var batchedItems: [Transparent2DRenderItem] = []
            batchedItems.reserveCapacity(items.count)

            if var currentItem = items.first {
                for nextItemIndex in 1..<items.count {
                    let nextItem = items[nextItemIndex]

                    if tryToAddBatch(to: &currentItem, from: nextItem) == false {
                        batchedItems.append(currentItem)
                        currentItem = nextItem
                    }
                }

                batchedItems.append(currentItem)
            }

            sortedRenderItems.items.append(contentsOf: batchedItems)
        }
    }

    private func tryToAddBatch(to currentItem: inout Transparent2DRenderItem, from otherItem: Transparent2DRenderItem) -> Bool {
        guard let batch = currentItem.batchRange, let otherBatch = otherItem.batchRange else {
            return false
        }

        if otherItem.entity != currentItem.entity {
            return false
        }

        if batch.upperBound == otherBatch.lowerBound {
            currentItem.batchRange = batch.lowerBound ..< otherBatch.upperBound
        } else if batch.lowerBound == otherBatch.upperBound {
            currentItem.batchRange = otherBatch.lowerBound ..< batch.upperBound
        } else {
            return false
        }

        return true
    }
}

@System
@inline(__always)
public func ExtractCamera(
    _ world: World,
    _ commands: Commands,
    _ query: Extract<
        Query<Entity, Camera, Transform, VisibleEntities, GlobalViewUniformBufferSet, GlobalViewUniform>
    >
) {
    query.wrappedValue.forEach {
        entity, camera, transform,
        visibleEntities, bufferSet, uniform in
        let buffer = bufferSet.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        buffer.setData(uniform)
        commands.spawn("ExtractedCameraEntity") {
            camera
            transform
            visibleEntities
            uniform
            bufferSet
            RenderViewTarget()
            RenderItems<Transparent2DRenderItem>()
        }
    }
}
