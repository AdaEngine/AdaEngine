//
//  AnimatedTexture.swift
//  
//
//  Created by v.prusakov on 7/3/22.
//

import Yams

/// Animated texture is represents a frame-based animations, where multiple textures can be chained with a predifined delay for each frame.
/// This kind of textures can apply any 2D Textures to animate them.
public final class AnimatedTexture: Texture2D {
    
    struct Frame {
        var texture: Texture2D?
        var delay: Float
    }
    
    /// Contains information about frames
    private var frames: [Frame]
    
    /// Contains ref to subscription of event
    private var gameLoopToken: Cancellable?
    
    public var framesCount: Int = 1
    
    private var _currentFrame: Int = 0
    
    /// Current played frame.
    public var currentFrame: Int {
        get {
            return self._currentFrame
        }
        
        set {
            assert(self.framesCount >= newValue || newValue < 0)
            self._currentFrame = newValue
        }
    }
    
    /// Indicates how much frames will animated per second.
    @InRange(1..<1000)
    public var framesPerSecond: Float = 4.0
    
    /// Indicates that animation on pause.
    public var isPaused: Bool = false
    
    /// Include options for texture. By default contains `repeat` animation.
    public var options: Options = [.repeat]
    
    /// Return RID of current frame
    override var rid: RID {
        self.frames[currentFrame].texture!.rid
    }
    
    /// Return texture coordinates of current frame.
    public override var textureCoordinates: [Vector2] {
        get {
            return self.frames[currentFrame].texture!.textureCoordinates
        }
        // swiftlint:disable:next unused_setter_value
        set {
            fatalError("You cannot set texture coordinates for animated texture.")
        }
    }
    
    /// Return width of the current frame.
    public override var width: Float {
        return self.frames[currentFrame].texture!.width
    }
    
    /// Return height of the current frame.
    public override var height: Float {
        return self.frames[currentFrame].texture!.height
    }
    
    /// Create animated texture with 256 frames.
    public init() {
        self.frames = [Frame].init(repeating: Frame(texture: nil, delay: 0), count: 256)
        
        super.init(rid: RID(), size: .zero)
        
        self.gameLoopToken = EventManager.default.subscribe(
            for: EngineEvent.GameLoopBegan.self,
            completion: update(_:)
        )
    }
    
    override func freeTexture() {
        // we should not manage free of texture, because we don't create it on GPU
    }
    
    // MARK: - Resources
    
    struct AssetRepresentation: Codable {
        
        struct Frame: Codable {
            let texture: Data
            let delay: Float
        }
        
        let frames: [Frame]
        let fps: Float
        let options: UInt8
    }
    
    public required init(assetFrom data: Data) async throws {
        fatalError("init(assetFrom:) has not been implemented")
    }
    
    public override func encodeContents() async throws -> Data {
        var frames: [AssetRepresentation.Frame] = []
        
        for index in 0 ..< self.framesCount {
            
            let frame = self.frames[index]
            guard let texture = frame.texture else {
                continue
            }
            
            let data = try await texture.encodeContents()
            
            let item = AssetRepresentation.Frame(
                texture: data,
                delay: frame.delay
            )
            
            frames.append(item)
        }
        
        let asset = AssetRepresentation(
            frames: frames,
            fps: self.framesPerSecond,
            options: self.options.rawValue
        )
        
        let encoder = YAMLEncoder()
        return try encoder.encode(asset).data(using: .utf8)!
    }
    
    public subscript(_ frame: Int) -> Texture2D? {
        get {
            return self.getTexture(for: frame)
        }
        
        set {
            self.setTexture(newValue, for: frame)
        }
    }
    
    public func setTexture(_ texture: Texture2D?, for frame: Int) {
        self.frames[frame].texture = texture
    }
    
    public func getTexture(for frame: Int) -> Texture2D? {
        return self.frames[frame].texture
    }
    
    public func setDelay(_ delay: Float, for frame: Int) {
        self.frames[frame].delay = delay
    }
    
    public func getDelay(for frame: Int) -> Float {
        return self.frames[frame].delay
    }
    
    // MARK: - Private
    
    // FIXME: After breakpoint can increase animation speed. 
    private var time: TimeInterval = 0
    
    /// Called each frame to update current frame.
    private func update(_ event: EngineEvent.GameLoopBegan) {
        if self.isPaused {
            return
        }
        
        self.time += event.deltaTime
        
        let limit = self.framesPerSecond != 0 ? 1 / self.framesPerSecond : 0
        let frameTime = limit + self.frames[self.currentFrame].delay
        
        if self.time > frameTime {
            self.currentFrame += 1
            
            if self.currentFrame >= self.framesCount {
                if !self.options.contains(.repeat) {
                    self.currentFrame = self.framesCount - 1
                } else {
                    self.currentFrame = 0
                }
            }
            
            self.time -= frameTime
        }
    }
}

public extension AnimatedTexture {
    struct Options: OptionSet {
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// Repeats animation forever.
        public static let `repeat` = Options(rawValue: 0 << 1)
    }
}
