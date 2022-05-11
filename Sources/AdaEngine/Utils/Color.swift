//
//  Color.swift
//  
//
//  Created by v.prusakov on 11/4/21.
//


public struct Color: Codable, Hashable {
    
    public private(set) var red: Float
    public private(set) var green: Float
    public private(set) var blue: Float
    
    public private(set) var alpha: Float
    
    public init(red: Float, green: Float, blue: Float, alpha: Float) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    // MARK: - Public Methods
    
    public func opacity(_ alpha: Float) -> Color {
        var newColor = self
        newColor.alpha = alpha
        return newColor
    }
}

public extension Color {
    @inlinable
    @inline(__always)
    init(_ vector: Vector4) {
        self.init(red: vector.x, green: vector.y, blue: vector.z, alpha: vector.w)
    }
    
    @inlinable
    @inline(__always)
    init(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

public extension Color {
    static let black = Color(red: 0, green: 0, blue: 0, alpha: 1)
    static let white = Color(red: 1, green: 1, blue: 1, alpha: 1)
    
    static let red = Color(red: 1, green: 0, blue: 0, alpha: 1)
    static let green = Color(red: 0, green: 1, blue: 0, alpha: 1)
    static let blue = Color(red: 0, green: 0, blue: 1, alpha: 1)
    
    static let gray = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255, alpha: 1)
    
    static let orange = Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255, alpha: 1)
    static let yellow = Color(red: 255 / 255, green: 204 / 255, blue: 0 / 255, alpha: 1)
    static let mint = Color(red: 0 / 255, green: 199 / 255, blue: 190 / 255, alpha: 1)
    
    static let pink = Color(red: 255 / 255, green: 45 / 255, blue: 85 / 255, alpha: 1)
    static let brown = Color(red: 162 / 255, green: 132 / 255, blue: 94 / 255, alpha: 1)
    
    static let purple = Color(red: 175 / 255, green: 82 / 255, blue: 222 / 255, alpha: 1)
    
    static let clear = Color(red: 1, green: 1, blue: 1, alpha: 0)
}

public extension Color {
    var asVector: Vector4 { return Vector4(red, green, blue, alpha) }
}
