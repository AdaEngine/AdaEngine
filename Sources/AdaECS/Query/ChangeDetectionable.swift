//
//  ChangeDetectionable.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 05.12.2025.
//

import AdaUtils

public protocol ChangeDetectionable: Sendable {
    var changeTick: ChangeDetectionTick { get set }

    var isChanged: Bool { get }

    func setChanged()
}

public extension ChangeDetectionable {

    @inline(__always)
    var isAdded: Bool {
        return self.changeTick
            .added?
            .wrappedValue
            .isNewerThan(
                lastTick: self.changeTick.lastTick,
                currentTick: self.changeTick.currentTick
            ) ?? false
    }

    @inline(__always)
    var isChanged: Bool {
        return self.changeTick.change?
            .wrappedValue
            .isNewerThan(
                lastTick: self.changeTick.lastTick,
                currentTick: self.changeTick.currentTick
            ) ?? false
    }

    func setChanged() {
        unsafe self.changeTick
            .change?
            .getPointer()
            .pointee = self.changeTick.currentTick
    }
}
