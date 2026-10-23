#if os(macOS) && canImport(WebGPU)
@_spi(Internal) @testable import AdaRender
import AdaUtils
import Foundation
import Math
import Testing

extension Render3DGPUTests {
    @MainActor
    @Suite("FSR 1 on WebGPU", .enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_GOLDEN_WEBGPU"] == "1"))
    struct FSR {
        private func device() throws -> any RenderDevice {
            try WebGPURenderBackend.createBackend().renderDevice
        }

        private func texture(_ device: any RenderDevice, width: Int, height: Int, format: PixelFormat = .rgba8) -> Texture2D {
            Texture2D(
                gpuTexture: device.createTexture(from: .init(
                    width: width, height: height, pixelFormat: format, textureUsage: [.read, .renderTarget], textureType: .texture2D
                )), sampler: device.createSampler(from: .init()),
                size: SizeInt(width: width, height: height)
            )
        }

        private func upload(_ pixels: [UInt8], into texture: Texture2D) {
            unsafe pixels.withUnsafeBytes { bytes in
                guard let pointer = bytes.baseAddress else {
                    return
                }
                unsafe texture.gpuTexture.replaceRegion(
                    RectInt(x: 0, y: 0, width: texture.width, height: texture.height),
                    mipmapLevel: 0,
                    withBytes: pointer,
                    bytesPerRow: texture.width * 4
                )
            }
        }

        @Test func supportsSpatialResolutionAndRejectsUnsupportedInputsWithoutEncoding() throws {
            let device = try device()
            #expect(device.supportsSpatialUpscaling)
            #expect(resolveRenderSize(outputSize: [101, 51], mode: .spatial(renderScale: 0.75), supportsSpatialUpscaling: device.supportsSpatialUpscaling) == [76, 39])
            let source = texture(device, width: 8, height: 8)
            let command = device.createCommandQueue().makeCommandBuffer()
            #expect(!command.encodeSpatialUpscale(source: source, destination: source))
            #expect(!command.encodeSpatialUpscale(source: source, destination: texture(device, width: 8, height: 8)))
            #expect(!command.encodeSpatialUpscale(source: source, destination: texture(device, width: 4, height: 16)))
            #expect(!command.encodeSpatialUpscale(source: texture(device, width: 4, height: 4, format: .rgba_16f), destination: source))
            // Failed attempts must leave the encoder usable.
            let pass = command.beginRenderPass(.init(colorAttachments: [
                .init(texture: source, operation: .init(loadAction: .clear, storeAction: .store), clearColor: .red),
            ]))
            pass.endRenderPass()
            command.commit()
        }

        @Test func constantColorsSurviveBordersResizeCacheEvictionAndBothOutputFormats() async throws {
            let device = try device()
            let queue = device.createCommandQueue()
            // More than eight sizes exercises bounded-cache eviction; single texels exercise clamped borders.
            for index in 0..<11 {
                let source = texture(device, width: index + 1, height: index == 0 ? 1 : 3, format: index.isMultiple(of: 2) ? .rgba8 : .bgra8)
                let target = texture(device, width: (index + 1) * 2 + 1, height: 7, format: index.isMultiple(of: 2) ? .rgba8 : .bgra8)
                let color: [UInt8] = index.isMultiple(of: 2) ? [0, 255, 96, 64] : [255, 0, 128, 192]
                let bytes = index.isMultiple(of: 2) ? color : [color[2], color[1], color[0], color[3]]
                upload(Array(repeating: bytes, count: source.width * source.height).flatMap { $0 }, into: source)
                let command = queue.makeCommandBuffer()
                #expect(command.encodeSpatialUpscale(source: source, destination: target))
                command.commit()
                let image = try #require(try await device.readImage(from: target))
                for y in 0..<image.height {
                    for x in 0..<image.width {
                        let pixel = image.getPixel(x: x, y: y)
                        #expect(abs(pixel.red - Float(color[0]) / 255) < 0.01)
                        #expect(abs(pixel.green - Float(color[1]) / 255) < 0.01)
                        #expect(abs(pixel.blue - Float(color[2]) / 255) < 0.01)
                        #expect(abs(pixel.alpha - Float(color[3]) / 255) < 0.01)
                    }
                }
            }
        }

        @Test func reconstructsEdgesAndKeepsQueuedViewsIndependent() async throws {
            let device = try device()
            let queue = device.createCommandQueue()
            let source = texture(device, width: 8, height: 6)
            var pixels: [UInt8] = []
            for y in 0..<6 {
                for x in 0..<8 {
                    let value: UInt8 = x >= y + 1 ? 224 : 32
                    pixels += [value, value, value, UInt8(x * 32)]
                }
            }
            upload(pixels, into: source)
            let target = texture(device, width: 16, height: 12)
            let otherSource = texture(device, width: 12, height: 9)
            upload(Array(repeating: [UInt8(200), 60, 100, 255], count: 108).flatMap { $0 }, into: otherSource)
            let otherTarget = texture(device, width: 16, height: 12)
            // Both views are encoded before either command is submitted, with different immutable scales.
            let first = queue.makeCommandBuffer()
            let second = queue.makeCommandBuffer()
            #expect(first.encodeSpatialUpscale(source: source, destination: target))
            #expect(second.encodeSpatialUpscale(source: otherSource, destination: otherTarget))
            first.commit()
            second.commit()
            let image = try #require(try await device.readImage(from: target))
            let other = try #require(try await device.readImage(from: otherTarget))
            #expect(abs(other.getPixel(x: 8, y: 6).red - 200.0 / 255) < 0.01)
            #expect(image.getPixel(x: 0, y: 0).red < 0.15)
            #expect(image.getPixel(x: 15, y: 0).red > 0.85)
            #expect(image.getPixel(x: 0, y: 11).red < 0.15)
            // FSR must differ measurably from a generic bilinear presentation on diagonal detail.
            var difference: Float = 0
            for y in 0..<12 {
                for x in 0..<16 {
                    let sx = (Float(x) + 0.5) * 0.5 - 0.5
                    let sy = (Float(y) + 0.5) * 0.5 - 0.5
                    let ix = Int(floor(sx)), iy = Int(floor(sy))
                    let fx = sx - floor(sx), fy = sy - floor(sy)
                    func red(_ x: Int, _ y: Int) -> Float {
                        Float(pixels[(min(5, max(0, y)) * 8 + min(7, max(0, x))) * 4]) / 255
                    }
                    let top = red(ix, iy) * (1 - fx) + red(ix + 1, iy) * fx
                    let bottom = red(ix, iy + 1) * (1 - fx) + red(ix + 1, iy + 1) * fx
                    difference += abs(image.getPixel(x: x, y: y).red - (top * (1 - fy) + bottom * fy))
                }
            }
            #expect(difference > 1)
            // Bright side of the diagonal stays bright.
            let edge = image.getPixel(x: 7, y: 4).red
            #expect(edge > 0.80)
            // Alpha remains bilinear rather than acquiring RCAS overshoot.
            #expect(abs(image.getPixel(x: 7, y: 4).alpha - 104.0 / 255) < 0.01)
            // Same-size views reuse the intermediate within a single command buffer safely.
            let combined = queue.makeCommandBuffer()
            #expect(combined.encodeSpatialUpscale(source: otherSource, destination: otherTarget))
            #expect(combined.encodeSpatialUpscale(source: source, destination: target))
            combined.commit()
            let repeated = try #require(try await device.readImage(from: target))
            #expect(repeated.data == image.data)
        }
    }
}
#endif
