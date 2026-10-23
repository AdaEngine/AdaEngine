import AdaEngine
import Foundation
#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#endif

/// Points are normalized to the captured image, so resizing keeps marks aligned.
struct EditorGameScreenshotMarkup: Sendable {
    var strokes: [[Point]] = []

    static func normalized(_ point: Point, in size: Size) -> Point {
        Point(min(1, max(0, point.x / max(1, size.width))), min(1, max(0, point.y / max(1, size.height))))
    }

    static func normalized(_ point: Point, in frame: Rect) -> Point {
        normalized(point - frame.origin, in: frame.size)
    }

    /// Produces the attachment shown in the feedback editor, including the original frame.
    @concurrent
    func pngData(for image: Image) async throws -> Data {
        try Task.checkCancellation()
        #if canImport(CoreGraphics) && canImport(ImageIO)
        guard image.width > 0, image.height > 0, !image.data.isEmpty,
              let source = CGImageSourceCreateWithData(try image.pngData() as CFData, nil),
              let original = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { throw Failure.encodingFailed }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        context.draw(original, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(CGColor(red: 1, green: 0.22, blue: 0.25, alpha: 1))
        context.setFillColor(CGColor(red: 1, green: 0.22, blue: 0.25, alpha: 1))
        let lineWidth = max(2, width * 0.009)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in strokes {
            guard let first = stroke.first else { continue }
            let start = CGPoint(x: CGFloat(first.x) * width, y: (1 - CGFloat(first.y)) * height)
            if stroke.count == 1 {
                context.fillEllipse(in: CGRect(x: start.x - lineWidth / 2, y: start.y - lineWidth / 2, width: lineWidth, height: lineWidth))
            } else {
                context.beginPath()
                context.move(to: start)
                for point in stroke.dropFirst() {
                    context.addLine(to: CGPoint(x: CGFloat(point.x) * width, y: (1 - CGFloat(point.y)) * height))
                }
                context.strokePath()
            }
        }
        let output = NSMutableData()
        guard let marked = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure.encodingFailed
        }
        CGImageDestinationAddImage(destination, marked, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.encodingFailed }
        return output as Data
        #else
        guard image.width > 0, image.height > 0 else { throw Failure.encodingFailed }
        // Normalize BGRA, RGB and grayscale frames to the mutable RGBA format.
        var output = try Image.decode(from: image.pngData())
        let radius = max(1, Float(image.width) * 0.0045)
        func draw(_ point: Point, into output: inout Image) {
            let x = point.x * Float(image.width - 1), y = point.y * Float(image.height - 1)
            let left = max(0, Int(x - radius)), right = min(image.width - 1, Int(x + radius + 1))
            let top = max(0, Int(y - radius)), bottom = min(image.height - 1, Int(y + radius + 1))
            guard left <= right, top <= bottom else { return }
            for row in top...bottom {
                for column in left...right {
                    let dx = Float(column) - x, dy = Float(row) - y
                    if dx * dx + dy * dy <= radius * radius {
                        output.setPixel(in: Point(Float(column), Float(row)), color: Color(1, 0.22, 0.25, 1))
                    }
                }
            }
        }
        for stroke in strokes {
            try Task.checkCancellation()
            guard let first = stroke.first else { continue }
            draw(first, into: &output)
            for (start, end) in zip(stroke, stroke.dropFirst()) {
                let dx = (end.x - start.x) * Float(image.width), dy = (end.y - start.y) * Float(image.height)
                let steps = max(1, Int(max(abs(dx), abs(dy))))
                for step in 1...steps {
                    let progress = Float(step) / Float(steps)
                    draw(Point(start.x + (end.x - start.x) * progress, start.y + (end.y - start.y) * progress), into: &output)
                }
            }
        }
        return try output.pngData()
        #endif
    }

    enum Failure: Error { case encodingFailed }
}
