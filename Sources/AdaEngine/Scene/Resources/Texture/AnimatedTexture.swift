//
//  AnimatedTexture.swift
//  
//
//  Created by v.prusakov on 7/3/22.
//

public class AnimatedTexture: Texture2D {
    
    struct Frame {
        let texture: Texture2D
        let delay: Float
    }
    
    private var frames: [Frame?]
    public var framesCount: Int = 1
    
    public private(set) var currentFrame: Int = 0
    
    @InRange(1..<1000)
    public var framePerSeconds: Float = 4.0
    
    public var isPaused: Bool = false
    
    private var gameLoopToken: Cancellable?
    
    public var isRepeated: Bool = true
    
    override var rid: RID {
        self.frames[currentFrame]!.texture.rid
    }
    
    public override var textureCoordinates: [Vector2] {
        get {
            print(currentFrame)
            return self.frames[currentFrame]!.texture.textureCoordinates
        }
        
        set {
            
        }
    }
    
    public override var width: Float {
        return self.frames[currentFrame]!.texture.width
    }
    
    public override var height: Float {
        return self.frames[currentFrame]!.texture.height
    }
    
    public init() {
        self.frames = [Frame?].init(repeating: nil, count: 256)
        
        super.init(rid: RID(), size: .zero)
        
        self.gameLoopToken = EventManager.default.subscribe(
            for: EngineEvent.GameLoopBegan.self,
            completion: update(_:)
        )
    }
    
    override func freeTexture() { }
    
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
    
    // MARK: - Internal
    
    var time: TimeInterval = 0
    
    func update(_ event: EngineEvent.GameLoopBegan) {
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

protocol AnimationKeys {
    var rawValue: String { get }
}
