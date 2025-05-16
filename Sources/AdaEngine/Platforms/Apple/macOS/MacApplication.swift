//
//  MacApplication.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

#if MACOS
import AppKit
import MetalKit

// This hack to avoid using NSApplication.shared.run().
func runLoopObserverCallback(
    observer: CFRunLoopObserver?, 
    activity: CFRunLoopActivity, 
    info: UnsafeMutableRawPointer?
) {
    MainActor.assumeIsolated {
        let gameLoop = Application.shared.gameLoop
        do {
            if !gameLoop.isIterating {
                try gameLoop.iterate()
            }
        } catch {
            print("error", error)
        }
    }
    CFRunLoopWakeUp(CFRunLoopGetCurrent())
}

final class MacApplication: Application {

    private let delegate = MacAppDelegate()

    override class var windowManagerClass: UIWindowManager.Type {
        MacOSWindowManager.self
    }

    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        try super.init(argc: argc, argv: argv)

        // Create application
        let app = AdaApplication.shared
        app.setActivationPolicy(.regular)

        app.finishLaunching()
        app.delegate = self.delegate

        let observer = CFRunLoopObserverCreate(
            kCFAllocatorDefault, 
            CFRunLoopActivity.beforeWaiting.rawValue, 
            true, 
            0, 
            runLoopObserverCallback, 
            nil
        )
        CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, CFRunLoopMode.defaultMode)

        self.processEvents()
        app.activate(ignoringOtherApps: true)
    }

    override func run() throws {
        self.gameLoop.setup()
        do {
            while true {
                self.processEvents()
                try self.gameLoop.iterate()
            }
        } catch {
            let alert = Alert(
                title: "AdaEngine finished with Error", message: error.localizedDescription,
                buttons: [
                    .cancel(
                        "OK",
                        action: {
                            exit(EXIT_FAILURE)
                        })
                ])

            Application.shared.showAlert(alert)
        }
    }

    override func terminate() {
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

        let result = nsAlert.runModal()  // synchronous call

        // hack from that thread: https://stackoverflow.com/a/59245758
        let index = result.rawValue - 1000
        alert.buttons[index].action?()

        Application.shared.windowManager.activeWindow?.showWindow(makeFocused: true)
    }

    // MARK: - Private

    func processEvents(_ until: Date = .distantPast) {
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
