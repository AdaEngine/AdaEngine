//
//  MacApplication.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

#if MACOS
import AppKit
import MetalKit

final class MacApplication: Application {

    private let delegate = MacAppDelegate()

    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        try super.init(argc: argc, argv: argv)
        self.windowManager = MacOSWindowManager()

        // Create application
        let app = AdaApplication.shared
        app.setActivationPolicy(.regular)

        app.finishLaunching()
        app.delegate = self.delegate

        self.processEvents()

        app.activate(ignoringOtherApps: true)
    }

    private var task: Task<Void, Never>?

    override func run() throws {
        task = Task { @MainActor in
            self.gameLoop.setup()
            do {
                while true {
                    try Task.checkCancellation()
                    self.processEvents()
                    try await self.gameLoop.iterate()
                }
            } catch {
                let alert = Alert(title: "AdaEngine finished with Error", message: error.localizedDescription, buttons: [.cancel("OK", action: {
                    exit(EXIT_FAILURE)
                })])

                Application.shared.showAlert(alert)
            }
        }

        NSApplication.shared.run()
    }

    override func terminate() {
        self.task?.cancel()
        NSApplication.shared.terminate(nil)
    }

    @discardableResult
    override func openURL(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    override func showAlert(_ alert: Alert) {
        let nsAlert = NSAlert()
        nsAlert.alertStyle = .warning
        nsAlert.messageText = alert.title
        nsAlert.informativeText = alert.message ?? ""

        for button in alert.buttons {
            let nsButton = nsAlert.addButton(withTitle: button.title)

            // hack from that thread: https://stackoverflow.com/a/16627982
            if button.kind == .cancel {
                nsButton.keyEquivalent = "\\r"
            }
        }

        let result = nsAlert.runModal() // synchronous call

        // hack from that thread: https://stackoverflow.com/a/59245758
        let index = result.rawValue - 1000
        alert.buttons[index].action?()

        Application.shared.windowManager.activeWindow?.showWindow(makeFocused: true)
    }

    // MARK: - Private

    func processEvents() {
        while true {
            let event = NSApp.nextEvent(
                matching: .any,
                until: .distantPast,
                inMode: .default,
                dequeue: true
            )

            guard let event else {
                break
            }

            NSApp.sendEvent(event)
        }
    }
}

class AdaApplication: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyUp && event.modifierFlags.contains(.command) {
            self.keyWindow?.sendEvent(event)
        } else {
            super.sendEvent(event)
        }
    }
}

#endif
