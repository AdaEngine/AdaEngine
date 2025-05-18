//
//  AudioPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

import AdaECS

/// Emmiter of audio in spatial environment.
@Component
public struct AudioComponent {
    
    public let playbackController: AudioPlaybackController
    
    public init(resource: AudioResource) {
        self.playbackController = AudioServer.shared.prepareAudio(resource)
    }
}

/// AudioReceiver should be used for spatial audio.
@Component
public struct AudioReceiver {

    internal var audioListener: AudioEngineListener?
    
    public var isEnabled: Bool {
        get {
            audioListener?.isEnabled ?? false
        }
        
        set {
            audioListener?.isEnabled = newValue
        }
    }
}

/// Add audio capatibilities to the scene.
public struct AudioPlugin: WorldPlugin {
    
    public init() {}
    
    public func setup(in world: World) {
        world.addSystem(AudioSystem.self)
    }
}

/// A system that managed an audio resources for spatial audio.
public struct AudioSystem: System {
    
    static let query = EntityQuery(where: .has(AudioPlaybacksControllers.self) && .has(Transform.self))
    
    static let audioReceiverQuery = EntityQuery(where: .has(AudioReceiver.self) && .has(Transform.self))
    
    let audioEngine: AudioEngine
    
    public init(world: World) {
        self.audioEngine = AudioServer.shared.engine
    }
    
    public func update(context: UpdateContext) {
        context.world.performQuery(Self.query).forEach { entity in
            let (audioComponent, transform) = entity.components[AudioPlaybacksControllers.self, Transform.self]
            audioComponent.controllers.forEach { controller in
                controller.sound.position = transform.position
            }
        }
        
        context.world.performQuery(Self.audioReceiverQuery).forEach { entity in
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

/// Holds ``AudioPlaybackController`` to controll their lifetimes
@Component
struct AudioPlaybacksControllers {
    var controllers: [AudioPlaybackController] = []
}

public extension Entity {
    
    /// Create a new ``AudioPlaybackController`` for audio resource or returns existings once if ``AudioResource`` being used earlier for this entity.
    ///
    /// - Note: Audio controller will be automatically freed when entity is removed from memory and nobody own a reference to the playback controller.
    ///
    /// When you create an audio playback controller engine will automatically update position for spatial audio.
    func prepareAudio(_ resource: AudioResource) -> AudioPlaybackController {
        var controllers = self.components[AudioPlaybacksControllers.self] ?? AudioPlaybacksControllers()
        
        if let controller = controllers.controllers.first(where: { $0.resource === resource }) {
            return controller
        }
        
        let playbackController = AudioServer.shared.prepareAudio(resource)
        playbackController.entity = self
        
        controllers.controllers.append(playbackController)
        
        self.components += controllers
        
        return playbackController
    }
    
    /// Plays sound from an audio resource on this entity.
    ///
    /// An ``AudioPlaybackController`` instance that you use to manage audio playback.
    /// Use the controller to set playback characteristics like volume and reverb, and then start or stop playback.
    ///
    /// This method first prepares the audio by calling ``Entity/prepareAudio(_:)``, and then immediately calls the ``AudioPlaybackController/play()`` method on the returned controller.
    @discardableResult
    func playAudio(_ resource: AudioResource) -> AudioPlaybackController {
        let controller = self.prepareAudio(resource)
        controller.play()
        return controller
    }
    
    /// Stops audio playback.
    ///
    /// You can stop a specific ``AudioPlaybackController`` instance from playing a particular resource 
    /// by calling the controller’s ``AudioPlaybackController/stop()`` method. 
    /// To stop all controllers associated with a particular Entity instance with a single call, use the ``Entity/stopAllAudio()`` method instead.
    func stopAllAudio() {
        self.components[AudioPlaybacksControllers.self]?.controllers.forEach { $0.stop() }
        self.components += AudioPlaybacksControllers()
    }
}
