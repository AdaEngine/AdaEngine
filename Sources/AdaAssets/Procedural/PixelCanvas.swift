//
//  PixelCanvas.swift
//  AdaEngine
//

import Foundation

public struct PixelColor: Sendable, Equatable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// A palette-indexed pixel-art canvas. Index 0 is transparent; drawing outside the canvas is clipped.
public struct PixelCanvas: Sendable, Equatable {
    public static let maximumDimension = 512

    public let width: Int
    public let height: Int
    public private(set) var indices: [UInt8]
    public var palette: [PixelColor]

    public init?(width: Int, height: Int) {
        guard (1...Self.maximumDimension).contains(width), (1...Self.maximumDimension).contains(height) else { return nil }
        self.width = width
        self.height = height
        indices = [UInt8](repeating: 0, count: width * height)
        palette = [PixelColor](repeating: PixelColor(red: 255, green: 0, blue: 255), count: 256)
        palette[0] = PixelColor(red: 0, green: 0, blue: 0, alpha: 0)
    }

    public func color(x: Int, y: Int) -> UInt8 {
        contains(x, y) ? indices[y * width + x] : 0
    }

    public mutating func set(x: Int, y: Int, color: UInt8) {
        if contains(x, y) { indices[y * width + x] = color }
    }

    public mutating func fill(color: UInt8) {
        indices = [UInt8](repeating: color, count: indices.count)
    }

    /// Fills the rectangle with both corners inclusive.
    public mutating func fillRect(x0: Int, y0: Int, x1: Int, y1: Int, color: UInt8) {
        let (left, right) = (max(min(x0, x1), 0), min(max(x0, x1), width - 1))
        let (top, bottom) = (max(min(y0, y1), 0), min(max(y0, y1), height - 1))
        guard left <= right, top <= bottom else { return }
        for y in top...bottom {
            for x in left...right { indices[y * width + x] = color }
        }
    }

    public mutating func line(x0: Int, y0: Int, x1: Int, y1: Int, color: UInt8) {
        var (x, y) = (x0, y0)
        let (dx, dy) = (abs(x1 - x0), -abs(y1 - y0))
        let (sx, sy) = (x0 < x1 ? 1 : -1, y0 < y1 ? 1 : -1)
        var error = dx + dy
        while true {
            set(x: x, y: y, color: color)
            if x == x1 && y == y1 { break }
            let doubled = 2 * error
            if doubled >= dy {
                error += dy
                x += sx
            }
            if doubled <= dx {
                error += dx
                y += sy
            }
        }
    }

    /// Fills an ellipse centered on a pixel; radii are in pixels.
    public mutating func fillEllipse(cx: Int, cy: Int, rx: Int, ry: Int, color: UInt8) {
        guard rx >= 0, ry >= 0 else { return }
        let (a, b) = (Double(rx) + 0.5, Double(ry) + 0.5)
        let (left, right) = (max(cx - rx, 0), min(cx + rx, width - 1))
        let (top, bottom) = (max(cy - ry, 0), min(cy + ry, height - 1))
        guard left <= right, top <= bottom else { return }
        for y in top...bottom {
            for x in left...right {
                let (dx, dy) = (Double(x - cx) / a, Double(y - cy) / b)
                if dx * dx + dy * dy <= 1 { indices[y * width + x] = color }
            }
        }
    }

    /// Paints `color` on transparent pixels that touch an opaque pixel (4-neighborhood).
    public mutating func outline(color: UInt8) {
        let source = indices
        let neighbors: [(Int, Int)] = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        for y in 0..<height {
            for x in 0..<width where source[y * width + x] == 0 {
                var touches = false
                for (dx, dy) in neighbors {
                    let (nx, ny) = (x + dx, y + dy)
                    if nx >= 0, ny >= 0, nx < width, ny < height, source[ny * width + nx] != 0 { touches = true }
                }
                if touches { indices[y * width + x] = color }
            }
        }
    }

    /// Copies the left half onto the right half, mirrored, which keeps characters and props symmetric.
    public mutating func mirrorLeftToRight() {
        for y in 0..<height {
            for x in 0..<(width / 2) { indices[y * width + (width - 1 - x)] = indices[y * width + x] }
        }
    }

    public var opaquePixelCount: Int { indices.reduce(0) { $0 + ($1 == 0 ? 0 : 1) } }

    public var usedColors: [UInt8] { Array(Set(indices.filter { $0 != 0 })).sorted() }

    public func rgba() -> [UInt8] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(indices.count * 4)
        for index in indices {
            let color = palette[Int(index)]
            bytes.append(contentsOf: index == 0 ? [0, 0, 0, 0] : [color.red, color.green, color.blue, color.alpha])
        }
        return bytes
    }

    private func contains(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }
}
