#if canImport(AppKit) && os(macOS)
    import AppKit

    @MainActor
    final class EditorPlatformColorPicker: NSObject {
        static let shared = EditorPlatformColorPicker()

        private var onChange: ((EditorInspectorColorValue) -> Void)?

        static func present(
            value: EditorInspectorColorValue,
            supportsAlpha: Bool = true,
            onChange: @escaping (EditorInspectorColorValue) -> Void
        ) {
            shared.present(value: value, supportsAlpha: supportsAlpha, onChange: onChange)
        }

        private func present(
            value: EditorInspectorColorValue,
            supportsAlpha: Bool = true,
            onChange: @escaping (EditorInspectorColorValue) -> Void
        ) {
            self.onChange = onChange
            let panel = NSColorPanel.shared
            panel.showsAlpha = supportsAlpha
            panel.color = NSColor(
                srgbRed: CGFloat(value.red),
                green: CGFloat(value.green),
                blue: CGFloat(value.blue),
                alpha: CGFloat(value.alpha)
            )
            panel.setTarget(self)
            panel.setAction(#selector(colorChanged(_:)))
            panel.makeKeyAndOrderFront(nil)
        }

        @objc private func colorChanged(_ panel: NSColorPanel) {
            guard let color = panel.color.usingColorSpace(.sRGB) else {
                return
            }
            onChange?(
                EditorInspectorColorValue(
                    red: Float(color.redComponent),
                    green: Float(color.greenComponent),
                    blue: Float(color.blueComponent),
                    alpha: Float(color.alphaComponent)
                )
            )
        }
    }
#elseif canImport(UIKit) && os(iOS)
    import UIKit

    @MainActor
    final class EditorPlatformColorPicker: NSObject, UIColorPickerViewControllerDelegate {
        static let shared = EditorPlatformColorPicker()

        private var onChange: ((EditorInspectorColorValue) -> Void)?
        private weak var presentedPicker: UIColorPickerViewController?

        static func present(
            value: EditorInspectorColorValue,
            supportsAlpha: Bool = true,
            onChange: @escaping (EditorInspectorColorValue) -> Void
        ) {
            shared.present(value: value, supportsAlpha: supportsAlpha, onChange: onChange)
        }

        private func present(
            value: EditorInspectorColorValue,
            supportsAlpha: Bool = true,
            onChange: @escaping (EditorInspectorColorValue) -> Void
        ) {
            guard presentedPicker == nil, let presenter = Self.activeViewController() else {
                return
            }
            self.onChange = onChange
            let picker = UIColorPickerViewController()
            picker.delegate = self
            picker.supportsAlpha = supportsAlpha
            picker.selectedColor = UIColor(
                red: CGFloat(value.red),
                green: CGFloat(value.green),
                blue: CGFloat(value.blue),
                alpha: CGFloat(value.alpha)
            )
            presentedPicker = picker
            presenter.present(picker, animated: true)
        }

        func colorPickerViewController(
            _: UIColorPickerViewController,
            didSelect color: UIColor,
            continuously _: Bool
        ) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                return
            }
            onChange?(
                EditorInspectorColorValue(
                    red: Float(red),
                    green: Float(green),
                    blue: Float(blue),
                    alpha: Float(alpha)
                )
            )
        }

        func colorPickerViewControllerDidFinish(_: UIColorPickerViewController) {
            presentedPicker = nil
            onChange = nil
        }

        private static func activeViewController() -> UIViewController? {
            let root = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController
            var current = root
            while let presented = current?.presentedViewController {
                current = presented
            }
            return current
        }
    }
#elseif os(Windows)
    @_spi(Internal) import AdaPlatform
    import WinSDK

    @MainActor
    final class EditorPlatformColorPicker {
        static let shared = EditorPlatformColorPicker()

        private var customColors = [COLORREF](repeating: 0xFFFFFF, count: 16)
        private var isPresented = false

        static func present(
            value: EditorInspectorColorValue,
            supportsAlpha: Bool = true,
            onChange: @escaping (EditorInspectorColorValue) -> Void
        ) {
            guard !shared.isPresented else { return }
            shared.isPresented = true
            let initialColor = colorReference(value)
            let initialCustomColors = shared.customColors
            Task {
                defer { shared.isPresented = false }
                let (selection, customColors) = await WindowsNativeDialogs.present { owner in
                    var customColors = initialCustomColors
                    var picker = CHOOSECOLORW()
                    picker.lStructSize = DWORD(MemoryLayout<CHOOSECOLORW>.size)
                    picker.hwndOwner = owner
                    picker.rgbResult = initialColor
                    picker.Flags = DWORD(CC_RGBINIT | CC_FULLOPEN)
                    let accepted = customColors.withUnsafeMutableBufferPointer { colors in
                        picker.lpCustColors = colors.baseAddress
                        return ChooseColorW(&picker)
                    }
                    return (accepted ? picker.rgbResult : nil, customColors)
                }
                shared.customColors = customColors
                if let selection { onChange(colorValue(selection, alpha: supportsAlpha ? value.alpha : 1)) }
            }
        }

        static func colorReference(_ value: EditorInspectorColorValue) -> COLORREF {
            let red = UInt32((value.red * 255).rounded())
            let green = UInt32((value.green * 255).rounded())
            let blue = UInt32((value.blue * 255).rounded())
            return red | (green << 8) | (blue << 16)
        }

        static func colorValue(_ value: COLORREF, alpha: Float) -> EditorInspectorColorValue {
            EditorInspectorColorValue(
                red: Float(value & 0xFF) / 255,
                green: Float((value >> 8) & 0xFF) / 255,
                blue: Float((value >> 16) & 0xFF) / 255,
                alpha: alpha
            )
        }
    }
#endif
