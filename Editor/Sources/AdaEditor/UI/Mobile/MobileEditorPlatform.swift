#if os(iOS) || os(Android)
import AdaEngine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Native services used by the shared mobile screens.
@MainActor
enum MobileEditorPlatform {
    static var isForeground: Bool {
        #if os(iOS)
        UIApplication.shared.applicationState == .active
        #else
        (try? AndroidStudioHost.call("foreground").flag) ?? false
        #endif
    }

    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        _ = try? AndroidStudioHost.call("copy", text: text)
        #endif
    }

    static func pickFiles(completion: @escaping @MainActor (AssetFilePickerResult) -> Void) {
        #if os(iOS)
        ProjectOpenPicker.presentAgentContextPicker(completion: completion)
        #else
        AndroidStudioHost.pickFiles(imagesOnly: false, completion: completion)
        #endif
    }

    static func pickPhotos(completion: @escaping @MainActor (AssetFilePickerResult) -> Void) {
        #if os(iOS)
        ProjectOpenPicker.presentAgentPhotoPicker(completion: completion)
        #else
        AndroidStudioHost.pickFiles(imagesOnly: true, completion: completion)
        #endif
    }

    static func pickAttachmentSource(
        pickFiles: @escaping @MainActor () -> Void,
        pickPhotos: @escaping @MainActor () -> Void
    ) {
        #if os(iOS)
        ProjectOpenPicker.presentAgentAttachmentSourcePicker(pickFiles: pickFiles, pickPhotos: pickPhotos)
        #else
        // Android's document picker includes local files, photos and cloud providers.
        pickFiles()
        #endif
    }
}
#endif
