//
//  Angle.swift
//  
//
//  Created by v.prusakov on 10/20/21.
//

@frozen
public struct Angle {
    public let degrees: Float
    
    public var radians: Float {
        return self.degrees * .pi / 180
    }
    
    init(radians: Float) {
        self.degrees = radians / .pi * 180
    }
    
    init(degrees: Float) {
        self.degrees = degrees
    }
}

extension Angle: Hashable, Equatable {
    
}

public extension Angle {
    static func degrees(_ deg: Float) -> Angle {
        return Angle(degrees: deg)
    }
    
    static func radians(_ radians: Float) -> Angle {
        return Angle(radians: radians)
    }
    
    static let zero: Angle = Angle(degrees: 0)
}

extension Angle: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = Angle(degrees: Float(value))
    }
}
