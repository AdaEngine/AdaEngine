#if os(visionOS)
    import SwiftUI
    import UIKit

    /// Requests a size preset for this view's own scene; subsequent user resizing remains freeform.
    struct EditorVRWindowResize: SwiftUI.UIViewRepresentable {
        let request: Int
        let size: CGSize
        let onError: @MainActor (Error) -> Void

        func makeUIView(context: Context) -> EditorVRResizeView {
            let view = EditorVRResizeView()
            view.isUserInteractionEnabled = false
            return view
        }

        func updateUIView(_ view: EditorVRResizeView, context: Context) {
            view.request = request
            view.requestedSize = size
            view.onError = onError
            view.applyRequest()
        }
    }

    @MainActor
    final class EditorVRResizeView: UIKit.UIView {
        var request = 0
        var requestedSize = CGSize.zero
        var onError: (@MainActor (Error) -> Void)?
        private var appliedRequest = 0
        private var geometryTask: Task<Void, Never>?

        isolated deinit { geometryTask?.cancel() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyRequest()
        }

        func applyRequest() {
            guard request != appliedRequest, let scene = window?.windowScene else {
                return
            }
            appliedRequest = request
            geometryTask?.cancel()
            let currentRequest = request
            geometryTask = Task { @MainActor [weak self, weak scene] in
                // Let SwiftUI replace the compact dock's fixed bounds before restoring a normal size.
                await Task.yield()
                guard let self, let scene, !Task.isCancelled, request == currentRequest else { return }
                window?.layoutIfNeeded()
                scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.Vision(size: requestedSize, resizingRestrictions: .freeform)) { [weak self] error in
                    self?.onError?(error)
                }
            }
        }
    }
#endif
