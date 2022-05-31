//
//  SceneSerializer.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Yams

public class SceneSerializer {
    
    let encoder: YAMLEncoder
    let decoder: YAMLDecoder
    
    public init() {
        self.encoder = YAMLEncoder()
        self.decoder = YAMLDecoder()
    }
    
    public func loadScene(at path: URL) async throws -> Scene {
        let data = try Data(contentsOf: path)
        let scene = try self.decoder.decode(Scene.self, from: data, userInfo: [:])
        return scene
    }
    
    public func saveScene(_ scene: Scene, at path: URL) async throws {
        guard let data = try self.encoder.encode(scene).data(using: .utf8) else {
            return
        }
        
        try data.write(to: path, options: .atomic)
    }
}
