//
//  ExtensionProperties.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

public struct ExtensionProperties {
    public let extensionName: String
    public let specVersion: UInt32
    
    public init(_ vkExtProp: VkExtensionProperties) {
        let name = convertTupleToUnsafePointer(tuple: vkExtProp.extensionName, type: CChar.self)
        self.extensionName = String(cString: name)
        self.specVersion = vkExtProp.specVersion
    }
}
