#if os(visionOS)
    @_spi(Internal) import AdaEngine
    import Foundation
    import UIKit

    @MainActor
    enum EditorVRPalmLabel {
        static func make(_ label: String, in world: World, device: RenderDevice) -> Entity? {
            let width = 384
            let height = 96
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let rendered = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(width), height: CGFloat(height)), format: format).image { _ in
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                NSAttributedString(string: label, attributes: [.font: UIFont.systemFont(ofSize: 44, weight: .semibold), .foregroundColor: UIColor.white, .paragraphStyle: paragraph]).draw(
                    in: CGRect(x: 0, y: 16, width: CGFloat(width), height: 70)
                )
            }
            guard let image = rendered.cgImage else {
                return nil
            }
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            let copied = pixels.withUnsafeMutableBytes { storage in
                guard
                    let context = CGContext(
                        data: storage.baseAddress,
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bytesPerRow: width * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    )
                else {
                    return false
                }
                context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                return true
            }
            guard copied else {
                return nil
            }
            let texture = Texture2D(image: AdaEngine.Image(width: width, height: height, data: Data(pixels), format: .rgba8))
            let material = PBRMaterial()
            material.baseColorTexture = texture
            material.emissiveTexture = texture
            material.emissiveStrength = 1
            material.metallicFactor = 0
            material.roughnessFactor = 1
            material.alphaMode = .mask
            material.alphaCutoff = 0.1
            material.doubleSided = true
            let mesh = Mesh.generate(from: Quad(size: .one), renderDevice: device)
            return world.spawn("Palm Label \(label)") {
                Transform()
                Mesh3DComponent(mesh: mesh, materials: [material], castShadows: false, receiveShadows: false)
                Visibility.visible
            }
        }
    }
#endif
