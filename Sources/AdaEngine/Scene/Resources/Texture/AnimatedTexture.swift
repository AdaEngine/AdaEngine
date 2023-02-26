//
//  AnimatedTexture.swift
//  
//
//  Created by v.prusakov on 7/3/22.
//


// TODO: Make encoding/decoding for scene serialization

/// Animated texture is represents a frame-based animations, where multiple textures can be chained with a predifined delay for each frame.
/// This kind of textures can apply any 2D Textures to animate them.
public final class AnimatedTexture: Texture2D {
    
    struct Frame {
        var texture: Texture2D?
        var delay: TimeInterval
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
    override var gpuTexture: GPUTexture {
        self.frames[currentFrame].texture!.gpuTexture
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
    public override var width: Int {
        return self.frames[currentFrame].texture!.width
    }
    
    /// Return height of the current frame.
    public override var height: Int {
        return self.frames[currentFrame].texture!.height
    }
    
    /// Create animated texture with 256 frames.
    public init() {
        self.frames = [Frame].init(repeating: Frame(texture: nil, delay: 0), count: 256)
        
        super.init(gpuTexture: GPUTexture(), size: .zero)
        
        self.gameLoopToken = EventManager.default.subscribe(
            to: EngineEvents.GameLoopBegan.self,
            completion: update(_:)
        )
    }
    
    // MARK: - Resources
    
    struct AssetRepresentation: Codable {
        struct Frame: Codable {
            let texture: Texture2D // FIXME: (Vlad) resource id/path
            let delay: TimeInterval
        }
        
        let frames: [Frame]
        let fps: Float
        let framesCount: Int
        let options: Options
    }
    
    public convenience required init(asset decoder: AssetDecoder) throws {
        guard decoder.assetMeta.filePath.pathExtension == Self.resourceType.fileExtenstion else {
            throw AssetDecodingError.invalidAssetExtension(decoder.assetMeta.filePath.pathExtension)
        }
        
        let asset = try decoder.decode(AssetRepresentation.self)
        
        self.init()
        
        self.framesCount = asset.framesCount
        self.framesPerSecond = asset.fps
        self.options = asset.options
        
        for (frameIndex, frame) in asset.frames.enumerated() {
            self.setTexture(frame.texture, for: frameIndex)
            self.setDelay(frame.delay, for: frameIndex)
        }
    }
    
    public override func encodeContents(with encoder: AssetEncoder) throws {
        guard encoder.assetMeta.filePath.pathExtension == Self.resourceType.fileExtenstion else {
            throw AssetDecodingError.invalidAssetExtension(encoder.assetMeta.filePath.pathExtension)
        }
        
        var frames: [AssetRepresentation.Frame] = []
        
        for index in 0 ..< self.framesCount {
            let frame = self.frames[index]
            guard let texture = frame.texture else {
                continue
            }

            let item = AssetRepresentation.Frame(
                texture: texture,
                delay: frame.delay
            )

            frames.append(item)
        }
        
        let asset = AssetRepresentation(
            frames: frames,
            fps: self.framesPerSecond,
            framesCount: self.framesCount,
            options: self.options
        )
        
        try encoder.encode(asset)
    }
    
    // MARK: - Codable
    
    public convenience required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let path = try container.decode(String.self)
        let texture = try ResourceManager.load(path) as AnimatedTexture
        
        self.init()
        
        self.frames = texture.frames
        self.framesPerSecond = texture.framesPerSecond
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.resourcePath)
    }
    
    // MARK: - Public methods
    
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
    
    public func setDelay(_ delay: TimeInterval, for frame: Int) {
        self.frames[frame].delay = delay
    }
    
    public func getDelay(for frame: Int) -> TimeInterval {
        return self.frames[frame].delay
    }
    
    // MARK: - Private
    
    // FIXME: After breakpoint can increase animation speed. 
    private var time: TimeInterval = 0
    
    /// Called each frame to update current frame.
    private func update(_ event: EngineEvents.GameLoopBegan) {
        if self.isPaused {
            return
        }
        
        // Avoid bug when we play animation very fast, because we need to fit to frames per second rate
        if event.deltaTime > 1 {
            return
        }
        
        self.time += event.deltaTime
        
        let limit: TimeInterval = TimeInterval(self.framesPerSecond != 0 ? 1 / self.framesPerSecond : 0)
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
    struct Options: OptionSet, Codable {
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// Repeats animation forever.
        public static let `repeat` = Options(rawValue: 0 << 1)
    }
}
