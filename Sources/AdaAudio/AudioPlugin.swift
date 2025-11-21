//
//  AudioPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

import AdaApp
import AdaECS
import AdaTransform

/// A plugin that adds audio capabilities to the world.
public struct AudioPlugin: Plugin {

    var engine: AudioEngine?

    public init() {
        do {
            self.engine = unsafe try MiniAudioEngine()
        } catch {
            print("Error", error)
        }
    }

    public func setup(in app: AppWorlds) {
        guard let engine else {
            return
        }
        do {
            try engine.start()
            AudioComponent.registerComponent()
            AudioReceiver.registerComponent()
            AudioPlaybacksControllers.registerComponent()

            app
                .insertResource(engine)
                .addSystem(AudioSystem.self)
        } catch {
            print("Error", error)
        }
    }

    public func finish() {
        do {
            try engine?.stop()
        } catch {
            print("Error", error)
        }
    }
}

/// A component that holds an ``AudioPlaybackController`` for an audio resource.
///
/// Use this component to play audio on an entity.
///
/// - Note: Audio component will be automatically freed when entity is removed from memory and nobody own a reference to the playback controller.
///
/// When you create an audio playback controller engine will automatically update position for spatial audio.
@Component
public struct AudioComponent {
    
    /// The playback controller for the audio component.
    public let playbackController: AudioPlaybackController
    
    /// Creates a new audio component with the specified audio resource.
    ///
    /// - Parameter resource: The audio resource to play.
    public init(resource: AudioResource) {
        self.playbackController = unsafe AudioServer.shared.prepareAudio(resource)
    }
}

/// AudioReceiver should be used for spatial audio.
@Component
public struct AudioReceiver {

    internal var audioListener: AudioEngineListener?

    public init() { }

    /// A Boolean that indicates whether the audio receiver is enabled.
    ///
    /// Set this value to false to disable the audio receiver.
    public var isEnabled: Bool {
        get {
            audioListener?.isEnabled ?? false
        }
        
        set {
            audioListener?.isEnabled = newValue
        }
    }
}

/// A system that manages audio resources for spatial audio.
@PlainSystem
public struct AudioSystem {
    
    @Query<AudioPlaybacksControllers, Transform>
    private var audioPlaybacksControllersQuery
    
    @Query<Ref<AudioReceiver>, Transform>
    private var audioReceiverQuery

    let audioEngine: AudioEngine!

    public init(world: World) {
        self.audioEngine = unsafe world.getResource(MiniAudioEngine.self)!
    }

    public func update(context: inout UpdateContext) {
        self.audioPlaybacksControllersQuery.forEach { audioComponent, transform in
            audioComponent.controllers.forEach { controller in
                controller.sound.position = transform.position
            }
        }
        
        self.audioReceiverQuery.forEach { (audioReceiver, transform) in
            if let listener = audioReceiver.audioListener, listener.position != transform.position {
                listener.position = transform.position
            } else {
                audioReceiver.audioListener = self.audioEngine.getAudioListener(at: 0)
            }
        }
    }
}

/// Holds ``AudioPlaybackController`` to control their lifetimes
@Component
public struct AudioPlaybacksControllers {

    /// The playback controllers for the audio playback controllers.
    public var controllers: [AudioPlaybackController] = []
}

public extension Entity {
    
    /// Create a new ``AudioPlaybackController`` for audio resource or returns existings once if ``AudioResource`` being used earlier for this entity.
    ///
    /// - Note: Audio controller will be automatically freed when entity is removed from memory and nobody own a reference to the playback controller.
    ///
    /// When you create an audio playback controller engine will automatically update position for spatial audio.
    @MainActor
    func prepareAudio(_ resource: AudioResource) -> AudioPlaybackController {
        var controllers = self.components[AudioPlaybacksControllers.self] ?? AudioPlaybacksControllers()
        if let controller = controllers.controllers.first(where: { $0.resource === resource }) {
            return controller
        }
        
        var playbackController = unsafe AudioServer.shared.prepareAudio(resource)
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
    @MainActor
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
    @MainActor
    func stopAllAudio() {
        self.components[AudioPlaybacksControllers.self]?.controllers.forEach { $0.stop() }
        self.components += AudioPlaybacksControllers()
    }
}
