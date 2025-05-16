//
//  LinuxApplication.swift
//  AdaEngine
//
//  Created by v.prusakov on 9/2/22.
//

#if LINUX
import Wayland

final class LinuxApplication: Application {
    override class var windowManagerClass: UIWindowManager.Type {
        LinuxWindowManager.self
    }

    private var linuxWindowManager: LinuxWindowManager {
        windowManager as! LinuxWindowManager
    }

    override func run() {
        guard let display = linuxWindowManager.display else {
            fatalError("Display is not set")
        }

        self.gameLoop.setup()

        do {
            while true {
                while wl_display_prepare_read(display) != 0 {
                    wl_display_dispatch_pending(display)
                }
                wl_display_flush(display)
                wl_display_read_events(display)
                wl_display_dispatch_pending(display)

                try self.gameLoop.iterate()
            }
        } catch {
            print("error", error)
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
