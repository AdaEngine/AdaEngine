//
//  iOSAppDelegate.swift
//  
//
//  Created by v.prusakov on 5/24/22.
//

#if canImport(UIKit)
import UIKit

// swiftlint:disable type_name
class iOSAppDelegate: NSObject, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        let window = UIWindow()
        window.rootViewController = iOSGameViewController(nibName: nil, bundle: nil)
        window.makeKeyAndVisible()
        self.window = window
        
        Engine.shared.run()
        
        return true
    }
}

// swiftlint:enable type_name
#endif
