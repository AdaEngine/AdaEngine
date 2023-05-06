//
//  AudioPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

// TODO: Must copy sound cross playbacks controllers

/// Emmiter of audio in spatial environment.
public struct AudioComponent: Component {
    
    public let playbackController: AudioPlaybackController
    
    public init(resource: AudioResource) {
        self.playbackController = AudioServer.shared.prepareAudio(resource)
    }
}

/// AudioReceiver should be used for spatial audio.
public struct AudioReceiver: Component {
    
    internal var audioListener: AudioEngineListener?
    
    public var isEnabled: Bool {
        get {
            audioListener?.isEnabled ?? false
        }
        
        set {
            audioListener?.isEnabled = true
        }
    }
}

public struct AudioPlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) {
        scene.addSystem(AudioSystem.self)
    }
}

public struct AudioSystem: System {
    
    static let query = EntityQuery(where: .has(AudioComponent.self) && .has(Transform.self))
    
    static let audioReceiverQuery = EntityQuery(where: .has(AudioReceiver.self) && .has(Transform.self))
    
    let audioEngine: AudioEngine
    
    public init(scene: Scene) {
        self.audioEngine = AudioServer.shared.engine
    }
    
    public func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            let (audioComponent, transform) = entity.components[AudioComponent.self, Transform.self]
            audioComponent.playbackController.resource.sound.position = transform.position
        }
        
        context.scene.performQuery(Self.audioReceiverQuery).forEach { entity in
            var (audioReceiver, transform) = entity.components[AudioReceiver.self, Transform.self]
            
            if let listener = audioReceiver.audioListener, listener.position != transform.position {
                listener.position = transform.position
            } else {
                audioReceiver.audioListener = self.audioEngine.getAudioListener(at: 0)
                entity.components += audioReceiver
            }
        }
    }
}
