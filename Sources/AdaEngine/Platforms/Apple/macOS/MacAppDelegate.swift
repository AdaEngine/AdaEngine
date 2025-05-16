//
//  MacAppDelegate.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

#if MACOS
import AppKit
import MetalKit

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("applicationDidFinishLaunching")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("applicationWillTerminate")
    }
}

#endif
