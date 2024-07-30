//
//  BorderModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.07.2024.
//

import Math

public extension View {
    func border(_ color: Color, lineWidth: Float = 1) -> some View {
        return overlay {
            Canvas { context, size in
                context.drawLine(start: Vector2(0, 0), end: Vector2(size.width, 0), lineWidth: lineWidth, color: color)
                context.drawLine(start: Vector2(0, 0), end: Vector2(0, -size.height), lineWidth: lineWidth, color: color)
                context.drawLine(start: Vector2(size.width, 0), end: Vector2(size.width, -size.height), lineWidth: lineWidth, color: color)
                context.drawLine(start: Vector2(0, -size.height), end: Vector2(size.width, -size.height), lineWidth: lineWidth, color: color)
            }
        }
    }
}