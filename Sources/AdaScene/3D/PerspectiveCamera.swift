//
//  PerspectiveCamera.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/10/23.
//

import AdaECS
import AdaAudio
import AdaRender
import AdaTransform

/// A virtual camera that establishes the rendering perspective.
@Bundle
public struct PerspectiveCameraBundle {
    public var camera: Camera
    public var visibleEntities = VisibleEntities()
    public var globalViewUniform = GlobalViewUniform()
    public var globalViewUniformBufferSet = GlobalViewUniformBufferSet()
    public var audioReceiver = AudioReceiver()
    public var transform = Transform()
    public var renderItems = RenderItems<Transparent2DRenderItem>()

    /// Create a new perspective camera for rendering 2D and 3D items on screen.
    public init(
        camera: Camera,
         visibleEntities: VisibleEntities = VisibleEntities(),
         globalViewUniform: GlobalViewUniform = GlobalViewUniform(),
         globalViewUniformBufferSet: GlobalViewUniformBufferSet = GlobalViewUniformBufferSet(),
         audioReceiver: AudioReceiver = AudioReceiver(),
         transform: Transform = Transform(),
        renderItems: RenderItems<Transparent2DRenderItem> = RenderItems<Transparent2DRenderItem>()
    ) {
        self.camera = camera
        self.camera.projection = .perspective
        self.visibleEntities = visibleEntities
        self.globalViewUniform = globalViewUniform
        self.globalViewUniformBufferSet = globalViewUniformBufferSet
        self.audioReceiver = audioReceiver
        self.transform = transform
        self.renderItems = renderItems
    }
}
