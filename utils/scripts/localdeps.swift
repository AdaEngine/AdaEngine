#!/usr/bin/env swift

import Foundation

// Configuration
let localDepsPath = "Modules/LocalDeps"
let dependencies = [
    "box2d": "https://github.com/AdaEngine/box2d",
    "msdf-atlas-gen": "https://github.com/AdaEngine/msdf-atlas-gen",
    "SPIRV-Cross": "https://github.com/AdaEngine/SPIRV-Cross",
    "miniaudio": "https://github.com/AdaEngine/miniaudio",
    "libpng": "https://github.com/AdaEngine/libpng"
    "glslang": "https://github.com/AdaEngine/glslang",
]

// Create LocalDeps directory if it doesn't exist
func createLocalDepsDirectory() throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(atPath: localDepsPath, withIntermediateDirectories: true)
}

// Clone repository
func cloneRepository(name: String, url: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["clone", url, "\(localDepsPath)/\(name)"]
    
    try process.run()
    process.waitUntilExit()
    
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "GitError", code: Int(process.terminationStatus))
    }
}

// Main execution
do {
    print("Creating LocalDeps directory...")
    try createLocalDepsDirectory()
    
    for (name, url) in dependencies {
        print("Cloning \(name)...")
        try cloneRepository(name: name, url: url)
        print("✅ Successfully cloned \(name)")
    }
    
    print("✨ All dependencies have been cloned successfully!")
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
