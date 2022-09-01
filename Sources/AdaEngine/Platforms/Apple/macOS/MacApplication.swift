//
//  MacApplication.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

#if MACOS
import AppKit

final class MacApplication: Application {
    
    // Timer that synced with display refresh rate.
    private let displayLink: DisplayLink
    
    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        self.displayLink = DisplayLink(on: .main)!
        try super.init(argc: argc, argv: argv)
        self.windowManager = MacOSWindowManager()
    }
    
    override func run() throws {
        let app = AdaApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        
        let delegate = MacAppDelegate()
        app.delegate = delegate
        
        app.activate(ignoringOtherApps: true)
        
        self.displayLink.setHandler { [weak self] in
            self?.update()
        }
        
        self.displayLink.start()
        
        app.run()
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
        
        let result = nsAlert.runModal() // synchronous call
        
        // hack from that thread: https://stackoverflow.com/a/59245758
        let index = result.rawValue - 1000
        alert.buttons[index].action?()
        
        Application.shared.windowManager.activeWindow?.showWindow(makeFocused: true)
    }
    
    // MARK: - Private
    
    private func update() {
        do {
            try self.gameLoop.iterate()
        } catch {
            print(error.localizedDescription)
            exit(-1)
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
