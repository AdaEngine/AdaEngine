#if os(Linux)
    import AdaApp
    import AdaECS
    @_spi(Internal) import AdaInput
    @_spi(Internal) import AdaUI
    import AdaUtils
    import Foundation
    import Glibc
    import Logging
    import X11

    @MainActor
    final class LinuxApplication: Application {
        private let display: LinuxDisplay
        private var isRunning = true

        override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
            display = try LinuxDisplay()
            unsafe try super.init(argc: argc, argv: argv)
            windowManager = LinuxWindowManager(display: display)
            UIWindowManager.setShared(windowManager)
            AdaUI.Screen.screenManager = LinuxScreenManager(display: display)
        }

        override func run(_ appWorlds: AppWorlds) async throws {
            windowManager.inputRef = appWorlds.main.getRefResource(Input.self)
            while isRunning {
                try Task.checkCancellation()
                let startedAt = Time.absolute
                (windowManager as? LinuxWindowManager)?.pollEvents()
                guard isRunning else {
                    break
                }
                try await appWorlds.update()
                let duration = appWorlds.getResource(ApplicationFramePacing.self)?.minimumFrameDuration ?? (1.0 / 60.0)
                let remaining = duration - (Time.absolute - startedAt)
                if remaining > 0 {
                    try await Task.sleep(for: .seconds(Double(remaining)))
                } else {
                    await Task.yield()
                }
            }
        }

        override func terminate() { isRunning = false }

        override func openURL(_ url: URL) -> Bool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
            process.arguments = [url.absoluteString]
            do {
                try process.run()
                return true
            } catch {
                Logger(label: "org.adaengine.linux").error("Cannot open URL: \(error)")
                return false
            }
        }

        override func showAlert(_ alert: Alert) {
            // Keep the message visible even on minimal Linux desktops without a dialog utility.
            Logger(label: "org.adaengine.linux").error("\(alert.title): \(alert.message ?? "")")
        }
    }

    /// Event access is main-actor isolated. XInitThreads also permits Dawn to use Xlib on its GPU thread.
    @MainActor
    final class LinuxDisplay {
        let pointer: OpaquePointer
        let inputMethod: XIM?

        init() throws {
            guard unsafe XInitThreads() != 0 else {
                throw LinuxPlatformError.threadInitializationFailed
            }
            unsafe setlocale(LC_CTYPE, "")
            unsafe XSetLocaleModifiers("")
            guard let pointer = unsafe XOpenDisplay(nil) else {
                throw LinuxPlatformError.displayUnavailable
            }
            unsafe self.pointer = pointer
            inputMethod = unsafe XOpenIM(pointer, nil, nil, nil)
            var supported: Int32 = 0
            unsafe XkbSetDetectableAutoRepeat(pointer, 1, &supported)
        }

        isolated deinit {
            if let inputMethod { unsafe XCloseIM(inputMethod) }
            unsafe XCloseDisplay(pointer)
        }
    }

    enum LinuxPlatformError: LocalizedError {
        case threadInitializationFailed, displayUnavailable

        var errorDescription: String? {
            switch self {
            case .threadInitializationFailed: "Cannot initialize Xlib threading."
            case .displayUnavailable: "Cannot open the X11 display. Start a desktop session (or WSLg) and check DISPLAY."
            }
        }
    }
#endif
