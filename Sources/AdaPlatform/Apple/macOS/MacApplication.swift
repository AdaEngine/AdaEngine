//
//  MacApplication.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

#if MACOS
import AdaApp
import AppKit
@_spi(Internal) import AdaInput
@_spi(Internal) import AdaUI
import AdaUtils
import MetalKit
import AdaECS

final class MacApplication: Application {

    private let delegate = MacAppDelegate()
    private let screenManager: MacOSScreenManager

    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        unsafe Color.accentColor = NSColor.controlAccentColor.toColor
        self.screenManager = MacOSScreenManager()
        Screen.screenManager = screenManager
        unsafe try super.init(argc: argc, argv: argv)
        self.windowManager = MacOSWindowManager(screenManager)
        UIWindowManager.setShared(self.windowManager)

        // Create application
        let app = AdaApplication.shared
        app.setActivationPolicy(.regular)

        app.finishLaunching()
        app.delegate = self.delegate

        self.processEvents()
        app.activate(ignoringOtherApps: true)
    }

    private var task: Task<Void, Never>?

    override func run(_ appWorlds: AppWorlds) throws {
        setupInput(for: appWorlds)
        task = Task(priority: .userInitiated) {
            do {
                while true {
                    let frameStartedAt = Time.absolute
                    try Task.checkCancellation()
                    self.processEvents()
                    try await appWorlds.update()
                    try await self.waitForNextFrameIfNeeded(startedAt: frameStartedAt, appWorlds: appWorlds)
                }
            } catch {
                let alert = Alert(
                    title: "AdaEngine finished with Error",
                    message: error.localizedDescription,
                    buttons: [
                        .cancel("OK", action: { exit(EXIT_FAILURE) })
                    ]
                )
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

    private func setupInput(for app: AppWorlds) {
        let mutableInput = app.main.getRefResource(Input.self)
        self.windowManager.inputRef = mutableInput
    }

    private func processEvents() {
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

    private func waitForNextFrameIfNeeded(startedAt frameStartedAt: LongTimeInterval, appWorlds: AppWorlds) async throws {
        guard let framePacing = appWorlds.getResource(ApplicationFramePacing.self) else {
            await Task.yield()
            return
        }

        let remainingTime = framePacing.minimumFrameDuration - (Time.absolute - frameStartedAt)
        guard remainingTime > 0 else {
            await Task.yield()
            return
        }

        try await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
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

private extension NSColor {
    var toColor: AdaUtils.Color {
        Color(
            red: Float(self.cgColor.components?[0] ?? 0),
            green: Float(self.cgColor.components?[1] ?? 0),
            blue: Float(self.cgColor.components?[2] ?? 0),
            alpha: Float(self.cgColor.alpha)
        )
    }
}

#endif
