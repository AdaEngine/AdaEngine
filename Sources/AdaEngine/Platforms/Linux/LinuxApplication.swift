//
//  LinuxApplication.swift
//  AdaEngine
//
//  Created by v.prusakov on 9/2/22.
//

#if LINUX
import Wayland

final class LinuxApplication: Application {
    private var task: Task<Void, Never>?

    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        try super.init(argc: argc, argv: argv)
        
        self.windowManager = LinuxWindowManager()
    }

    override func run() {
        print("LinuxApplication.run()")
        task = Task { @MainActor in
            self.gameLoop.setup()
            do {
                while true {
                    try Task.checkCancellation()
                    self.processEvents()
                    try await self.gameLoop.iterate()
                }
            } catch {
                fatalError("LinuxApplication.run() error: \(error)")
                let alert = Alert(title: "AdaEngine finished with Error", message: error.localizedDescription, buttons: [.cancel("OK", action: {
                    exit(EXIT_FAILURE)
                })])

                Application.shared.showAlert(alert)
            }
        }
    }

    override func openURL(_ url: URL) -> Bool {
        // TODO: Implement Wayland URL opening
        return false
    }

    override func showAlert(_ alert: Alert) {
        // TODO: Implement Wayland alert
    }

    func processEvents() {
        // TODO: Implement Wayland events processing
    }
}

#endif
