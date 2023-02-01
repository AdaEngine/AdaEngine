//
//  SceneSerializer.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Foundation
import Yams

struct SystemRepresentation: Codable {
    let name: String
}

struct ScenePluginRepresentation: Codable {
    let name: String
}

struct ComponentRepresentation: Codable {
    let name: String
}

struct SceneRepresentation: Codable {
    let version: Version
    let scene: String
    let plugins: [ScenePluginRepresentation]
    let systems: [SystemRepresentation]
    let entities: [Entity]
}
