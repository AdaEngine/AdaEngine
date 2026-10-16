//
//  AudioSource.swift
//  AdaEngine
//

import AdaAssets
import AdaECS
import AdaTransform
import Foundation

/// A serializable sound on an entity: scene files, the Studio inspector and scripts all use it.
///
/// ``AudioSourceSystem`` loads ``source`` through the asset system and plays it from the entity's position,
/// so give music and interface sounds to the camera entity to hear them at full volume. A script triggers a
/// sound by setting ``play`` to `true` (the system restarts the sound and clears the flag) and ends it with ``stop``.
@Component
public struct AudioSource: Codable, Equatable, Sendable {
    /// Project-relative `@res://` path to a WAV, MP3 or FLAC file.
    public var source: String
    /// Linear gain in `0...1`.
    public var volume: Float
    public var loops: Bool
    /// Plays once as soon as the sound has loaded.
    public var autoplay: Bool
    /// Request: start (or restart) the sound from the beginning. The system resets it to `false`.
    public var play: Bool
    /// Request: stop the sound. The system resets it to `false`.
    public var stop: Bool

    public init(source: String = "", volume: Float = 1, loops: Bool = false, autoplay: Bool = false, play: Bool = false, stop: Bool = false) {
        self.source = source
        self.volume = volume
        self.loops = loops
        self.autoplay = autoplay
        self.play = play
        self.stop = stop
    }
}

/// Runtime status of an ``AudioSource``.
public struct AudioSourceState: Component {
    public let path: String
    public let error: String?
    let controller: AudioPlaybackController?

    init(path: String, controller: AudioPlaybackController? = nil, error: String? = nil) {
        self.path = path
        self.controller = controller
        self.error = error
    }

    public var isPlaying: Bool { controller?.isPlaying ?? false }
}

/// Loads changed ``AudioSource`` paths and applies volume, looping and play/stop requests every update.
@PlainSystem
public struct AudioSourceSystem {
    @Query<Entity, AudioSource> private var sources
    @Query<Entity, AudioSourceState> private var states
    @Commands private var commands

    public init(world _: World) {}

    public func update(context _: UpdateContext) async {
        guard unsafe AudioServer.shared != nil else { return }
        states.forEach { entity, state in
            guard entity.components[AudioSource.self] == nil else { return }
            state.controller?.stop()
            let id = entity.id
            commands.queue.push { world in world.getEntityByID(id)?.components[AudioSourceState.self] = nil }
        }
        var loads: [(Entity.ID, AudioSource)] = []
        sources.forEach { entity, source in
            guard let state = entity.components[AudioSourceState.self], state.path == source.source else {
                if !source.source.isEmpty { loads.append((entity.id, source)) }
                return
            }
            guard let controller = state.controller else { return }
            controller.volume = max(0, min(source.volume, 1))
            controller.setLoop(source.loops)
            if let position = entity.components[Transform.self]?.position { controller.sound.position = position }
            if source.stop { controller.stop() }
            if source.play {
                controller.stop()
                controller.play()
            }
            if source.play || source.stop {
                let id = entity.id
                commands.queue.push { world in
                    guard var current = world.getEntityByID(id)?.components[AudioSource.self] else { return }
                    current.play = false
                    current.stop = false
                    world.getEntityByID(id)?.components[AudioSource.self] = current
                }
            }
        }
        for (id, source) in loads {
            let result: Result<AudioResource, AssetError>
            do {
                result = .success(try await AssetsManager.load(AudioResource.self, at: source.source).asset)
            } catch {
                result = .failure(.message(error.localizedDescription))
            }
            commands.queue.push { world in
                guard let owner = world.getEntityByID(id), owner.components[AudioSource.self]?.source == source.source else { return }
                owner.components[AudioSourceState.self]?.controller?.stop()
                switch result {
                case .success(let resource):
                    guard unsafe AudioServer.shared != nil else { return }
                    let controller = unsafe AudioServer.shared.prepareAudio(resource)
                    controller.volume = max(0, min(source.volume, 1))
                    controller.setLoop(source.loops)
                    if source.autoplay { controller.play() }
                    owner.components[AudioSourceState.self] = AudioSourceState(path: source.source, controller: controller)
                case .failure(let error):
                    owner.components[AudioSourceState.self] = AudioSourceState(path: source.source, error: error.localizedDescription)
                }
            }
        }
    }
}
