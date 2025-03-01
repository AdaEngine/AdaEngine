//
//  MockUIWindowManager.swift
//
//
//  Created by vladislav.prusakov on 12.08.2024.
//

@_spi(Internal) @testable import AdaEngine

class TestApplication: Application {
    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        try super.init(argc: argc, argv: argv)
        self.windowManager = MockUIWindowManager()
    }

    convenience init() throws {
        try self.init(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
    }
}

class MockUIWindowManager: UIWindowManager {

}

extension Application {
    @MainActor
    static func prepareForTest() throws {
        self.shared = try TestApplication()
        AudioServer.shared = AudioServer(engine: MockAudioEngine())
    }
}

class MockAudioEngine: AudioEngine {
    /// Starts audio engine.
    func start() throws {}
    
    /// Stop audio engine.
    func stop() throws {}
    
    func update(_ deltaTime: TimeInterval) {}
    
    /// Create a new sound instance from file url.
    func makeSound(from url: URL) throws -> Sound {
        fatalError("Not implemented")
    }
    
    /// Create a new sound instance from data.
    func makeSound(from data: Data) throws -> Sound {
        fatalError("Not implemented")
    }
    
    /// Returns audio listener object at index.
    /// Max count of listeners depends on implementation of ``AudioEngine``.
    func getAudioListener(at index: Int) -> AudioEngineListener {
        fatalError("Not implemented")
    }
}
