//
//  UILayotu.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.07.2024.
//

import AdaUtils
import Atomics
import Math

@MainActor
open class UILayer {
    private static let idGenerator = ManagedAtomic<UInt64>(1)
    let id: UInt64 = idGenerator.loadThenWrappingIncrement(ordering: .relaxed)

    private var cachedCommands: [UIGraphicsContext.DrawCommand]?
    private var cachedCommandsVersion: UInt64 = 0
    private var cachedCommandsTransform: Transform3D?
    private var cachedCommandsOpacity: Float = 1
    private(set) var commandVersion: UInt64 = 0
    var allowsCaching: Bool = true
    var propagatesInvalidation: Bool = true
    private(set) var frame: Rect
    private let drawBlock: (inout UIGraphicsContext, Size) -> Void
    var debugLabel: String?

    public internal(set) weak var parent: UILayer?

    public init(frame: Rect, drawBlock: @escaping (inout UIGraphicsContext, Size) -> Void) {
        self.frame = frame
        self.drawBlock = drawBlock
    }

    func setFrame(_ frame: Rect) {
        if frame == .zero {
            return
        }

        self.frame = frame
        self.invalidate()
    }

    func invalidate() {
        commandVersion &+= 1
        self.cachedCommands = nil
        if propagatesInvalidation {
            self.parent?.invalidate()
        }
    }

    final func drawLayer(in context: UIGraphicsContext) {
        guard frame.height > 0 && frame.width > 0 else {
            return
        }

        let snapshot = commandSnapshot(
            environment: context.environment,
            transform: context.transform,
            opacity: context.opacity
        )
        context.commandQueue.push(.beginLayer(id: self.id, version: snapshot.version, cacheable: snapshot.cacheable))
        context.commandQueue.push(contentsOf: snapshot.commands)
        context.commandQueue.push(.endLayer(id: self.id))
    }

    private func commandSnapshot(
        environment: EnvironmentValues,
        transform: Transform3D,
        opacity: Float
    ) -> (commands: [UIGraphicsContext.DrawCommand], version: UInt64, cacheable: Bool) {
        if let cachedCommands,
           cachedCommandsVersion == commandVersion,
           cachedCommandsTransform == transform,
           cachedCommandsOpacity == opacity {
            return (cachedCommands, commandVersion, true)
        }

        var layerContext = UIGraphicsContext()
        layerContext.setTransform(transform)
        layerContext.opacity = opacity
        layerContext.environment = environment
        self.drawBlock(&layerContext, self.frame.size)
        layerContext.commitDraw()
        let recordedCommands = layerContext.getDrawCommands()
        let cacheable = allowsCaching && !containsNestedLayers(in: recordedCommands)
        if cacheable {
            self.cachedCommands = recordedCommands
            self.cachedCommandsVersion = commandVersion
            self.cachedCommandsTransform = transform
            self.cachedCommandsOpacity = opacity
        } else {
            self.cachedCommands = nil
            self.cachedCommandsTransform = nil
            self.cachedCommandsOpacity = 1
        }
        return (recordedCommands, commandVersion, cacheable)
    }

    private func containsNestedLayers(in commands: [UIGraphicsContext.DrawCommand]) -> Bool {
        commands.contains { command in
            if case .beginLayer = command {
                return true
            }
            return false
        }
    }
}
