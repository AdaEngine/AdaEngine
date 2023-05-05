//
//  AudioResource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

public final class AudioResource: Resource {
    
    internal let sound: Sound
    
    public var resourceName: String = ""
    public var resourcePath: String = ""
    
    public static var resourceType: ResourceType = .audio
    
    public required init(asset decoder: AssetDecoder) throws {
        if decoder.assetMeta.filePath.pathExtension == Self.resourceType.fileExtenstion {
            guard let data = FileSystem.current.readFile(at: decoder.assetMeta.filePath) else {
                throw AssetDecodingError.decodingProblem("Can't read file at path")
            }
            
            self.sound = try AudioServer.shared.engine.makeSound(from: data)
        } else {
            self.sound = try AudioServer.shared.engine.makeSound(from: decoder.assetMeta.filePath)
        }
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        
    }
}

public struct AudioComponent: Component {
    
    public let resource: AudioResource
    
    public init(resource: AudioResource) {
        self.resource = resource
    }
    
    public func start() {
        self.resource.sound.start()
    }
    
    public func stop() {
        self.resource.sound.stop()
    }
}

public struct AudioSystem: System {
    
    static let query = EntityQuery(where: .has(AudioComponent.self) && .has(Transform.self))
    
    public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            let (audioComponent, transform) = entity.components[AudioComponent.self, Transform.self]
            audioComponent.resource.sound.position = transform.position
        }
    }
}

public struct AudioListener: Component {
    
}

public struct AudioPlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) {
        scene.addSystem(AudioSystem.self)
    }
}
