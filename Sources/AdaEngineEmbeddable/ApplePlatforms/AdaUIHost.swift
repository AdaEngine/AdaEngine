#if canImport(UIKit) && canImport(SwiftUI)
    import AdaUI
    import Foundation
    import SwiftUI

    /// Places an existing AdaUI panel inside a SwiftUI window. Content and local AdaUI
    /// state survive SwiftUI updates; the native host owns rendering and input only.
    @MainActor
    public struct AdaUIHost<Content: AdaUI.View>: SwiftUI.UIViewRepresentable {
        private let content: Content
        private let assetBundle: Bundle?
        private let onError: (@MainActor (Error) -> Void)?
        private let onTextInputFocusChanged: (@MainActor (Bool) -> Void)?

        public init(
            assetBundle: Bundle? = nil,
            onError: (@MainActor (Error) -> Void)? = nil,
            onTextInputFocusChanged: (@MainActor (Bool) -> Void)? = nil,
            @AdaUI.ViewBuilder content: () -> Content
        ) {
            self.content = content()
            self.assetBundle = assetBundle
            self.onError = onError
            self.onTextInputFocusChanged = onTextInputFocusChanged
        }

        public func makeUIView(context: Context) -> AdaUIHostingView<Content> {
            let view = AdaUIHostingView(content: content, assetBundle: assetBundle)
            view.onError = onError
            view.onTextInputFocusChanged = onTextInputFocusChanged
            return view
        }

        public func updateUIView(_ uiView: AdaUIHostingView<Content>, context: Context) {
            uiView.onError = onError
            uiView.onTextInputFocusChanged = onTextInputFocusChanged
            uiView.updateContent(content, colorScheme: context.environment.colorScheme == .dark ? .dark : .light)
        }

        public static func dismantleUIView(_ uiView: AdaUIHostingView<Content>, coordinator _: ()) {
            uiView.stop()
        }
    }
#endif
