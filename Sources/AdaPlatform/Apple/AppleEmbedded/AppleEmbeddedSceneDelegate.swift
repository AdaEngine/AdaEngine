//
//  AppleEmbeddedSceneDelegate.swift
//  AdaEngine
//
//  Created by Codex on 29.03.2026.
//

#if os(iOS) || os(tvOS)
import UIKit
@_spi(Internal) import AdaUI

// swiftlint:disable type_name
final class AppleEmbeddedSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIKit.UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene,
              let windowManager = UIWindowManager.shared as? AppleEmbeddedWindowManager else {
            return
        }
        windowManager.sceneDidConnect(windowScene)

        if let url = connectionOptions.urlContexts.first?.url {
            NotificationCenter.default.post(name: .adaEngineOpenURL, object: url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        guard let url = urlContexts.first?.url else { return }
        NotificationCenter.default.post(name: .adaEngineOpenURL, object: url)
    }
}
// swiftlint:enable type_name
#endif
