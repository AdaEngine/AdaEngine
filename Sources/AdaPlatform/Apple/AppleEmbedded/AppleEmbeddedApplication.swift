//
//  AppleEmbeddedApplication.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/24/22.
//

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    import AdaApp
    import AdaECS
    @_spi(Internal) import AdaInput
    @_spi(Internal) import AdaUI
    import AdaUtils
    import Foundation
    import UIKit

    @safe @MainActor
    final class AppleEmbeddedApplication: Application {
        let argc: Int32
        let argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>

        private let screenManager: AppleEmbeddedScreenManager
        private var appWorlds: AppWorlds?
        private var task: Task<Void, Never>?
        private var configuredFrameRateRange: ClosedRange<Int>?
        #if IOS
            private weak var displayLinkScreen: UIScreen?
            private weak var updateLinkView: UIKit.UIView?
            private var updateLink: UIUpdateLink?
        #endif
        var displayLink: CADisplayLink!

        override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
            unsafe self.argv = argv
            self.argc = argc

            let screenManager = AppleEmbeddedScreenManager()
            self.screenManager = screenManager
            Screen.screenManager = screenManager
            try unsafe super.init(argc: argc, argv: argv)
            self.windowManager = AppleEmbeddedWindowManager(screenManager: screenManager)
            UIWindowManager.setShared(self.windowManager)
        }

        override func run(_ appWorlds: AppWorlds) throws {
            self.appWorlds = appWorlds
            self.setupInput(for: appWorlds)

            #if IOS
                (windowManager as? AppleEmbeddedWindowManager)?.onNativeWindowPresented = { [weak self] view in
                    self?.bindDisplayLink(to: view)
                }
            #endif

            #if os(visionOS)
            self.displayLink = CADisplayLink(target: self, selector: #selector(update))
            #else
            self.displayLink =
                UIScreen.main.displayLink(withTarget: self, selector: #selector(update))
                ?? CADisplayLink(target: self, selector: #selector(update))
            #endif
            self.configureDisplayLinkFrameRate()
            self.displayLink.add(to: .main, forMode: .common)

            // FIXME: We should store bundleIdentifier? err ("Invalid parameter not satisfying: bundleIdentifier")
            let exitCode = unsafe UIApplicationMain(
                argc,
                argv,
                NSStringFromClass(AdaApplication.self),
                NSStringFromClass(AppleEmbeddedAppDelegate.self)
            )

            if exitCode != EXIT_SUCCESS {
                throw NSError(domain: "", code: Int(exitCode))
            }
        }

        @discardableResult
        override func openURL(_ url: URL) -> Bool {
            UIApplication.shared.open(url)
            return true
        }

        override func showAlert(_ alert: Alert) {
            let window = UIApplication.shared.connectedScenes
                .lazy
                .compactMap { ($0 as? UIWindowScene) }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }

            guard let window else {
                return
            }

            let alertController = UIAlertController(
                title: alert.title,
                message: alert.message,
                preferredStyle: .alert
            )

            for button in alert.buttons {
                let style: UIAlertAction.Style

                switch button.kind {
                case .cancel:
                    style = .cancel
                case .plain:
                    style = .`default`
                }

                let action = UIAlertAction(
                    title: button.title,
                    style: style,
                    handler: { _ in
                        button.action?()
                    }
                )

                alertController.addAction(action)
            }

            window.rootViewController?.present(alertController, animated: true)
        }

        override func terminate() {
            self.task?.cancel()
            #if IOS
                self.updateLink?.isEnabled = false
            #endif
            self.displayLink?.invalidate()
            exit(EXIT_SUCCESS)
        }

        // MARK: - Private

        #if IOS
            private func bindDisplayLink(to view: UIKit.UIView) {
                guard let screen = (view as? UIKit.UIWindow)?.windowScene?.screen ?? view.window?.windowScene?.screen,
                    updateLinkView !== view || displayLinkScreen !== screen else { return }
                displayLink?.invalidate()
                updateLink?.isEnabled = false
                displayLinkScreen = screen
                updateLinkView = view
                // Follow the view as Duo moves it between its physical displays.
                let link = UIUpdateLink(view: view) { [weak self] _, _ in self?.update() }
                link.requiresContinuousUpdates = true
                updateLink = link
                configuredFrameRateRange = nil
                configureDisplayLinkFrameRate()
                link.isEnabled = true
            }
        #endif

        private func setupInput(for app: AppWorlds) {
            let mutableInput = app.main.getRefResource(Input.self)
            self.windowManager.inputRef = mutableInput
        }

        @objc private func update() {
            guard let appWorlds = self.appWorlds,
                let windowManager = self.windowManager as? AppleEmbeddedWindowManager,
                windowManager.isUIKitReady
            else {
                return
            }
            self.configureDisplayLinkFrameRate()

            // Use a task to handle async update
            if task == nil {
                task = Task(priority: .userInitiated) { [weak self] in
                    do {
                        try await appWorlds.update()
                    } catch {
                        print("Update error: \(error.localizedDescription)")
                    }
                    self?.task = nil
                }
            }
        }

        private func configureDisplayLinkFrameRate() {
            guard
                let displayLink,
                let framePacing = appWorlds?.getResource(ApplicationFramePacing.self)
            else {
                return
            }

            #if os(visionOS)
                let displayMaximumFramesPerSecond = 90
            #elseif os(watchOS)
                let displayMaximumFramesPerSecond = 60
            #else
                #if IOS
                    let displayMaximumFramesPerSecond = displayLinkScreen?.maximumFramesPerSecond ?? 60
                #else
                    let displayMaximumFramesPerSecond = UIScreen.main.maximumFramesPerSecond
                #endif
            #endif
            let thermalState: ApplicationFramePacing.ThermalState
            switch ProcessInfo.processInfo.thermalState {
            case .nominal: thermalState = .nominal
            case .fair: thermalState = .fair
            case .serious: thermalState = .serious
            case .critical: thermalState = .critical
            @unknown default: thermalState = .serious
            }
            let isIdle = !windowManager.windows.values.contains {
                $0.value.canDraw && Time.absolute - $0.value.lastUIActivityTime < 1
            }
            let range = framePacing.resolvedFrameRateRange(
                forDisplayMaximumFramesPerSecond: displayMaximumFramesPerSecond,
                isIdle: isIdle,
                thermalState: thermalState
            )
            guard configuredFrameRateRange != range else {
                return
            }
            configuredFrameRateRange = range
            let frameRateRange = CAFrameRateRange(
                minimum: Float(range.lowerBound),
                maximum: Float(range.upperBound),
                preferred: Float(range.upperBound)
            )
            #if IOS
                if let updateLink {
                    updateLink.preferredFrameRateRange = frameRateRange
                } else {
                    displayLink.preferredFrameRateRange = frameRateRange
                }
            #else
                displayLink.preferredFrameRateRange = frameRateRange
            #endif
        }
    }

    final class AdaApplication: UIApplication {}

#endif
