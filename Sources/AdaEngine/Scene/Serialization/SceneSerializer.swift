//
//  SceneSerializer.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Foundation

struct SceneObject: Codable {
    let name: String
    let entities: [Entity]
}
