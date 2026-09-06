#if canImport(AppKit) && os(macOS)
@_spi(AdaEngine) import AdaEngine
import AppKit

struct EditorInspectorColorWell: AppKitViewRepresentable {
    let value: EditorInspectorColorValue
    let onChange: (EditorInspectorColorValue) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSColorWell {
        let colorWell = NSColorWell()
        colorWell.colorWellStyle = .minimal
        colorWell.isBordered = true
        colorWell.target = context.coordinator
        colorWell.action = #selector(Coordinator.colorChanged(_:))
        updateNSView(colorWell, context: context)
        return colorWell
    }

    func updateNSView(_ colorWell: NSColorWell, context: Context) {
        context.coordinator.onChange = onChange
        colorWell.color = NSColor(
            srgbRed: CGFloat(value.red),
            green: CGFloat(value.green),
            blue: CGFloat(value.blue),
            alpha: CGFloat(value.alpha)
        )
    }

    final class Coordinator: NSObject {
        var onChange: (EditorInspectorColorValue) -> Void

        init(onChange: @escaping (EditorInspectorColorValue) -> Void) {
            self.onChange = onChange
        }

        @MainActor @objc func colorChanged(_ sender: NSColorWell) {
            guard let color = sender.color.usingColorSpace(.sRGB) else {
                return
            }
            onChange(EditorInspectorColorValue(
                red: Float(color.redComponent),
                green: Float(color.greenComponent),
                blue: Float(color.blueComponent),
                alpha: Float(color.alphaComponent)
            ))
        }
    }
}

struct EditorInspectorTextureDropTarget: AppKitViewRepresentable {
    let onClick: () -> Void
    let onDrop: (URL) -> Void

    func makeNSView(context: Context) -> TextureDropView {
        TextureDropView(onClick: onClick, onDrop: onDrop)
    }

    func updateNSView(_ view: TextureDropView, context: Context) {
        view.onClick = onClick
        view.onDrop = onDrop
    }

    final class TextureDropView: NSView {
        var onClick: () -> Void
        var onDrop: (URL) -> Void

        init(onClick: @escaping () -> Void, onDrop: @escaping (URL) -> Void) {
            self.onClick = onClick
            self.onDrop = onDrop
            super.init(frame: .zero)
            registerForDraggedTypes([.fileURL])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func mouseDown(with event: NSEvent) {
            onClick()
        }

        override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
            droppedFileURL(from: sender) == nil ? [] : .copy
        }

        override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
            guard let url = droppedFileURL(from: sender) else {
                return false
            }
            onDrop(url)
            return true
        }

        private func droppedFileURL(from draggingInfo: any NSDraggingInfo) -> URL? {
            draggingInfo.draggingPasteboard.readObjects(forClasses: [NSURL.self])?.first as? URL
        }
    }
}
#endif

#if canImport(UIKit) && os(iOS)
@_spi(AdaEngine) import AdaEngine
import UIKit

struct EditorInspectorIOSColorWell: UIKitViewRepresentable {
    let value: EditorInspectorColorValue
    let onChange: (EditorInspectorColorValue) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeUIView(context: Context) -> UIColorWell {
        let colorWell = UIColorWell()
        colorWell.supportsAlpha = true
        colorWell.addTarget(context.coordinator, action: #selector(Coordinator.colorChanged(_:)), for: .valueChanged)
        updateUIView(colorWell, in: context)
        return colorWell
    }

    func updateUIView(_ colorWell: UIColorWell, in context: Context) {
        context.coordinator.onChange = onChange
        colorWell.selectedColor = UIColor(
            red: CGFloat(value.red),
            green: CGFloat(value.green),
            blue: CGFloat(value.blue),
            alpha: CGFloat(value.alpha)
        )
    }

    final class Coordinator: NSObject {
        var onChange: (EditorInspectorColorValue) -> Void

        init(onChange: @escaping (EditorInspectorColorValue) -> Void) {
            self.onChange = onChange
        }

        @MainActor @objc func colorChanged(_ sender: UIColorWell) {
            guard let color = sender.selectedColor else {
                return
            }
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                return
            }
            onChange(EditorInspectorColorValue(
                red: Float(red),
                green: Float(green),
                blue: Float(blue),
                alpha: Float(alpha)
            ))
        }
    }
}
#endif
