//
//  UIClipboard.swift
//  AdaEngine
//
//  Created by Codex on 19.02.2026.
//

import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Clipboard helper used by editable UI controls.
@MainActor
public enum UIClipboard {

    private static var fallbackString: String = ""

    /// Returns plain text from the system clipboard if available.
    public static func getString() -> String? {
        #if canImport(AppKit)
        NSPasteboard.general.string(forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string
        #else
        fallbackString
        #endif
    }

    /// Writes plain text to the clipboard.
    public static func setString(_ value: String) {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = value
        #else
        fallbackString = value
        #endif
    }
}
