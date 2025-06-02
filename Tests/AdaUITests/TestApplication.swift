//
//  MockUIWindowManager.swift
//
//
//  Created by vladislav.prusakov on 12.08.2024.
//

@_spi(Internal) @testable import AdaUI
@_spi(Internal) @testable import AdaPlatform
import AdaInput

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
        UIWindowManager.setShared(self.shared.windowManager)
    }
}
