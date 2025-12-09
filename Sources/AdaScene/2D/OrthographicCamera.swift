//
//  OrthographicCamera.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/5/23.
//

import AdaECS
import AdaAudio
import AdaRender

/// A virtual camera that establishes the rendering orthographic.
@Bundle
public struct OrthographicCameraBundle {
    public var camera: Camera
    public var viewUniforms: GlobalViewUniform
    public var globalViewUniformBufferSet: GlobalViewUniformBufferSet
    public var visibleEntities: VisibleEntities
    public var audioReceiver: AudioReceiver
    public var transform: Transform
    public var visibility: Visibility

    /// Create a new orthograpich camera for rendering 2D and 3D items on screen.
    public init(
        camera: Camera,
        viewUniforms: GlobalViewUniform = GlobalViewUniform(),
        globalViewUniformBufferSet: GlobalViewUniformBufferSet = GlobalViewUniformBufferSet(),
        visibleEntities: VisibleEntities = VisibleEntities(),
        audioReceiver: AudioReceiver = AudioReceiver(),
        transform: Transform = Transform(),
        visibility: Visibility = .visible
    ) {
        self.camera = camera
        self.camera.projection = .orthographic
        self.viewUniforms = viewUniforms
        self.globalViewUniformBufferSet = globalViewUniformBufferSet
        self.visibleEntities = visibleEntities
        self.audioReceiver = audioReceiver
        self.transform = transform
        self.visibility = visibility
    }
}
