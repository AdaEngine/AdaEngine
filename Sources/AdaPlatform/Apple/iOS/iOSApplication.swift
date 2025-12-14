//
//  iOSApplication.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/24/22.
//

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

// swiftlint:disable type_name
@MainActor
final class iOSApplication: Application {
    
    let argc: Int32
    let argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    
    var displayLink: CADisplayLink!
    
    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        self.argv = argv
        self.argc = argc
        
        try super.init(argc: argc, argv: argv)
        self.windowManager = iOSWindowManager()
    }
    
    override func run() throws {
        self.displayLink = CADisplayLink(target: self, selector: #selector(update))
        self.displayLink.add(to: .main, forMode: .default)

        // FIXME: We should store bundleIdentifier? err ("Invalid parameter not satisfying: bundleIdentifier")
        let exitCode = UIApplicationMain(
            argc,
            argv,
            NSStringFromClass(AdaApplication.self),
            NSStringFromClass(iOSAppDelegate.self)
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
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        
        guard let window = window else {
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
                handler: { action in
                    button.action?()
                }
            )
            
            alertController.addAction(action)
        }
        
        window.rootViewController?.present(alertController, animated: true)
    }
    
    // MARK: - Private
    
    @objc private func update() {
        do {
//            try self.mainLoop.iterate()
        } catch {
            print(error.localizedDescription)
            exit(-1)
        }
    }
}

class AdaApplication: UIApplication { }

// swiftlint:enable type_name

#endif
