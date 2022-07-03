//
//  AnimatedTexture.swift
//  
//
//  Created by v.prusakov on 7/3/22.
//

/// Animated textures can be applied to sprites to animate it.
/// This kind of textures can apply any 2D Textures to animate them.
public final class AnimatedTexture: Texture2D {
    
    struct Frame {
        let texture: Texture2D
        let delay: Float
    }
    
    /// Contains information about frames
    private var frames: [Frame?]
    
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
            assert(newValue > self.framesCount)
            self._currentFrame = newValue
        }
    }
    
    /// Indicates how much frames will animated per second.
    @InRange(1..<1000)
    public var framePerSeconds: Float = 4.0
    
    /// Indicates that animation on pause.
    public var isPaused: Bool = false
    
    /// Indicates that animated texture repeat animation. Default value is true.
    public var isRepeated: Bool = true
    
    /// Return RID of current frame
    override var rid: RID {
        self.frames[currentFrame]!.texture.rid
    }
    
    /// Return texture coordinates of current frame.
    public override var textureCoordinates: [Vector2] {
        get {
            print(currentFrame)
            return self.frames[currentFrame]!.texture.textureCoordinates
        }
        set { fatalError("You cannot set texture coordinates for animated texture.") }
    }
    
    /// Return width of the current frame.
    public override var width: Float {
        return self.frames[currentFrame]!.texture.width
    }
    
    /// Return height of the current frame.
    public override var height: Float {
        return self.frames[currentFrame]!.texture.height
    }
    
    /// Create animated texture with 256 frames.
    public init() {
        self.frames = [Frame?].init(repeating: nil, count: 256)
        
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
    
    public required init(assetFrom data: Data) async throws {
        fatalError("init(assetFrom:) has not been implemented")
    }
    
    public override func encodeContents() async throws -> Data {
        fatalError()
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
        self.frames[frame] = texture.flatMap { Frame(texture: $0, delay: 0) }
    }
    
    public func getTexture(for frame: Int) -> Texture2D? {
        return self.frames[frame]?.texture
    }
    
    public func setDelay(_ delay: Float, for frame: Int) {
        self.frames[frame]?.delay =
    }
    
    // MARK: - Private
    
    private var time: TimeInterval = 0
    
    /// Called each frame to update current frame.
    private func update(_ event: EngineEvent.GameLoopBegan) {
        if self.isPaused {
            return
        }
        
        self.time += event.deltaTime
        
        let limit = self.framePerSeconds != 0 ? 1 / self.framePerSeconds : 0
        let frameTime = limit + self.frames[self.currentFrame]!.delay
        
        if self.time > frameTime {
            self.currentFrame += 1
            
            if self.currentFrame >= self.framesCount {
                if !self.isRepeated {
                    self.currentFrame = self.framesCount - 1
                } else {
                    self.currentFrame = 0
                }
            }
            
            self.time -= frameTime
        }
    }
}
