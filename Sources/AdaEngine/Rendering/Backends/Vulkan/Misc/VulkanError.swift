//
//  VulkanError.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

#if VULKAN

import CVulkan

enum VulkanError: LocalizedError {
    case failedInit(
        message: String? = nil,
        code: VkResult,
        file: StaticString = #file,
        line: Int = #line,
        function: StaticString = #function
    )

    var errorDescription: String? {
        switch self {
        case .failedInit(let message, let code, let file, let line, let function):
            let log = message == nil ? "" : ": \(message!)"
            return "[Vulkan] \(file):\(line):\(function): Failed initialization with error \(code.rawValue)" + log
        }
    }
}

#endif
