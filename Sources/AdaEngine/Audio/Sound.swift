//
//  Sound.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/3/23.
//

import Math

public enum SoundState {
    case ready
    case playing
    case paused
    case stopped
}

protocol Sound: AnyObject {
    
    var volume: Float { get set }
    
    var pitch: Float { get set }
    
    var position: Vector3 { get set }
    
    var isLooping: Bool { get set }
    
    func start()
    
    func stop()
    
    func pause() 
    
    func update(_ deltaTime: TimeInterval)
    
    func onCompleteHandler(_ block: @escaping () -> Void) 
}
