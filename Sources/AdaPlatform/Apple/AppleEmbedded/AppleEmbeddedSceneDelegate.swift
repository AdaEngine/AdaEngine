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
    }
}
// swiftlint:enable type_name
#endif
