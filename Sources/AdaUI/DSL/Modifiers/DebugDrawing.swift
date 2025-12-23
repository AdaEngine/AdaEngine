//
//  DebugDrawing.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.12.2025.
//

public struct _DebugViewDrawingOptions: OptionSet, Sendable {
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public extension _DebugViewDrawingOptions {
    static let drawViewOverlays = _DebugViewDrawingOptions(rawValue: 1 << 0)
}

public extension View {
    func _debugDrawing(_ options: _DebugViewDrawingOptions) -> some View {
        self.transformEnvironment(\.debugViewDrawingOptions) { value in
            value = options
        }
    }
}
