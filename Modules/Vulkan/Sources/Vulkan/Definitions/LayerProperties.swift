//
//  LayerProperties.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

public struct LayerProperties {
    public let layerName: String
    public let description: String
    public let specVersion: UInt32
    public let implementationVersion: UInt32
    
    public init(_ vkLayer: VkLayerProperties) {
        let name = convertTupleToUnsafePointer(tuple: vkLayer.layerName, type: CChar.self)
        let description = convertTupleToUnsafePointer(tuple: vkLayer.description, type: CChar.self)
        
        self.layerName = String(cString: name)
        self.description = String(cString: description)
        self.specVersion = vkLayer.specVersion
        self.implementationVersion = vkLayer.implementationVersion
        self.vulkanValue = vkLayer
    }
    
    public let vulkanValue: VkLayerProperties
}
