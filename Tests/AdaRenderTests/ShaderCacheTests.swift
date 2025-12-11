//
//  ShaderCacheTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 11.12.2025.
//

import Testing
@testable import AdaRender
import Foundation

@Suite("Shader Cache Tests")
struct ShaderCacheTests {
    
    private let shaderSource = """
    #version 450 core
    #pragma stage : vert
    
    void main() {
        gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
    }
    """
    
    private let modifiedShaderSource = """
    #version 450 core
    #pragma stage : vert
    
    void main() {
        gl_Position = vec4(1.0, 1.0, 1.0, 1.0);
    }
    """
    
    @Test func `if cached shader change we update shader`() async throws {
        // Given: Create a temporary shader file
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        let shaderFileURL = tempDirectory.appendingPathComponent("test_shader.glsl")
        try shaderSource.write(to: shaderFileURL, atomically: true, encoding: .utf8)
        
        // Create ShaderSource from the file
        let shader = try ShaderSource(from: shaderFileURL)
        let version = 1
        
        // When: First call to hasChanges (no cache exists)
        let firstCallChanges = ShaderCache.hasChanges(for: shader, version: version)
        
        // Then: Should return vertex stage as changed (first time = no cache)
        #expect(firstCallChanges.contains(.vertex))
        
        // When: Second call with the same source (cache exists)
        let secondCallChanges = ShaderCache.hasChanges(for: shader, version: version)
        
        // Then: Should return empty set (no changes)
        #expect(secondCallChanges.isEmpty)
        
        // When: Modify the shader source
        shader.setSource(modifiedShaderSource, for: .vertex)
        
        // Then: Call hasChanges - should detect the change
        let thirdCallChanges = ShaderCache.hasChanges(for: shader, version: version)
        
        // Then: Should return vertex stage as changed
        #expect(thirdCallChanges.contains(.vertex))
    }
}
